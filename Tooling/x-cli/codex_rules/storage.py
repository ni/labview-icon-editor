"""SQLite persistence layer for the codex rules engine.

This module manages the underlying SQLite database used by the engine.  It
stores PR metadata, touched files, test events, and guidance rules.  It
provides methods to record events, query statistics, and perform basic
aggregation for association analysis.
"""
from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Tuple, Protocol


class StorageProtocol(Protocol):
    """Minimal protocol describing required storage operations."""

    def record_pr(
        self,
        *,
        pr_id: int,
        branch: str,
        base: str,
        labels: List[str],
        files: List[Dict],
    ) -> None: ...

    def record_test_event(
        self,
        *,
        run_id: str,
        pr_id: int,
        commit_sha: str,
        test_id: str,
        suite: str,
        status: str,
        duration_ms: int,
        component: str,
        file_hint: str,
        ts: str,
    ) -> None: ...

    def distinct_pairs(self, window_days: int) -> Iterable[Tuple[str, str]]: ...

    def contingency(
        self, component: str, test_id: str, window_days: int
    ) -> Tuple[int, int, int, int]: ...

    def upsert_guidance(self, rule: Dict) -> None: ...

    def get_components_for_pr(self, pr_id: int) -> List[str]: ...

    def get_active_guidance_by_component(
        self, components: Iterable[str]
    ) -> List[Dict]: ...

    def get_active_guidance(self) -> List[Dict]: ...

    def prune_guidance(self, window_days: int, last_n: int | None) -> None: ...

    def export_stats(self) -> Dict: ...


class Storage:
    """Encapsulates an SQLite database used by the rules engine."""

    def __init__(self, path: str) -> None:
        self.path = Path(path)
        # Ensure parent directory exists
        self.path.parent.mkdir(parents=True, exist_ok=True)
        # Enable WAL to avoid locking issues under concurrent writes
        self.conn = sqlite3.connect(self.path.as_posix(), isolation_level=None)
        self.conn.execute("PRAGMA journal_mode=WAL;")
        self._init_schema()

    def _init_schema(self) -> None:
        """Create tables if they do not exist."""
        cur = self.conn.cursor()
        cur.executescript(
            """
            CREATE TABLE IF NOT EXISTS prs (
                pr_id INTEGER PRIMARY KEY,
                branch TEXT,
                base TEXT,
                labels TEXT,
                created_at TEXT
            );

            CREATE TABLE IF NOT EXISTS pr_files (
                pr_id INTEGER,
                path TEXT,
                status TEXT,
                component TEXT,
                PRIMARY KEY (pr_id, path)
            );

            CREATE TABLE IF NOT EXISTS test_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id TEXT,
                pr_id INTEGER,
                commit_sha TEXT,
                test_id TEXT,
                suite TEXT,
                status TEXT,
                duration_ms INTEGER,
                component TEXT,
                file_hint TEXT,
                ts TEXT
            );

            CREATE TABLE IF NOT EXISTS guidance (
                rule_id TEXT PRIMARY KEY,
                component TEXT,
                test_id TEXT,
                support_prs INTEGER,
                confidence REAL,
                baseline REAL,
                lift REAL,
                p_value REAL,
                active INTEGER,
                last_seen TEXT,
                created_at TEXT,
                template TEXT,
                command TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_test_events_pr ON test_events (pr_id);
            CREATE INDEX IF NOT EXISTS idx_test_events_component ON test_events (component);
            CREATE INDEX IF NOT EXISTS idx_test_events_test ON test_events (test_id, status);
            CREATE INDEX IF NOT EXISTS idx_pr_files_component ON pr_files (component);
            """
        )

        # --- Migration: rename reserved 'commit' column to 'commit_sha' ---
        cur.execute("PRAGMA table_info(test_events)")
        cols = [row[1] for row in cur.fetchall()]
        if "commit" in cols and "commit_sha" not in cols:
            try:
                cur.execute("ALTER TABLE test_events RENAME COLUMN commit TO commit_sha")
            except sqlite3.OperationalError:
                # Fallback for old SQLite versions without RENAME COLUMN
                cur.executescript(
                    """
                    CREATE TABLE IF NOT EXISTS test_events_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        run_id TEXT,
                        pr_id INTEGER,
                        commit_sha TEXT,
                        test_id TEXT,
                        suite TEXT,
                        status TEXT,
                        duration_ms INTEGER,
                        component TEXT,
                        file_hint TEXT,
                        ts TEXT
                    );
                    INSERT INTO test_events_new
                        (id, run_id, pr_id, commit_sha, test_id, suite, status, duration_ms, component, file_hint, ts)
                    SELECT id, run_id, pr_id, "commit", test_id, suite, status, duration_ms, component, file_hint, ts
                    FROM test_events;
                    DROP TABLE test_events;
                    ALTER TABLE test_events_new RENAME TO test_events;
                    CREATE INDEX IF NOT EXISTS idx_test_events_pr ON test_events (pr_id);
                    CREATE INDEX IF NOT EXISTS idx_test_events_component ON test_events (component);
                    CREATE INDEX IF NOT EXISTS idx_test_events_test ON test_events (test_id, status);
                    """
                )

    # -------------------------- PR Metadata --------------------------- #
    def record_pr(
        self,
        pr_id: int,
        branch: str,
        base: str,
        labels: Iterable[str],
        files: Iterable[Dict],
    ) -> None:
        """Record metadata and touched files for a pull request."""
        ts = datetime.now(timezone.utc).isoformat()
        cur = self.conn.cursor()
        cur.execute(
            """
            INSERT OR REPLACE INTO prs (pr_id, branch, base, labels, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (pr_id, branch, base, json.dumps(list(labels)), ts),
        )
        for f in files:
            cur.execute(
                """
                INSERT OR REPLACE INTO pr_files (pr_id, path, status, component)
                VALUES (?, ?, ?, ?)
                """,
                (pr_id, f["path"], f.get("status", ""), f.get("component", "unknown")),
            )

    # ------------------------- Test Events ---------------------------- #
    def record_test_event(
        self,
        run_id: str,
        pr_id: int,
        commit_sha: str,
        test_id: str,
        suite: str,
        status: str,
        duration_ms: int,
        component: str,
        file_hint: str,
        ts: str,
    ) -> None:
        """Record a single test event for a given PR."""
        self.conn.execute(
            """
            INSERT INTO test_events
              (run_id, pr_id, commit_sha, test_id, suite, status, duration_ms, component, file_hint, ts)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                pr_id,
                commit_sha,
                test_id,
                suite,
                status,
                duration_ms,
                component,
                file_hint,
                ts,
            ),
        )

    # ------------------------- Association Stats ---------------------- #
    def distinct_pairs(self, window_days: int) -> List[Tuple[str, str]]:
        """Return distinct (component, test_id) pairs in the window."""
        cutoff = (datetime.now(timezone.utc) - timedelta(days=window_days)).isoformat()
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT DISTINCT component, test_id
            FROM test_events
            WHERE ts >= ? AND status = 'failed'
            """,
            (cutoff,),
        )
        return [(c, t) for c, t in cur.fetchall() if c != "unknown"]

    def contingency(
        self, component: str, test_id: str, window_days: int
    ) -> Tuple[int, int, int, int]:
        """Compute (A,B,C,D) contingency counts for a component/test pair.

        A: PRs that touched component AND failed the test at least once.
        B: PRs that touched component AND did NOT fail the test.
        C: PRs that did NOT touch component BUT failed the test.
        D: PRs that neither touched component nor failed the test.
        """
        cutoff = (datetime.now(timezone.utc) - timedelta(days=window_days)).isoformat()
        cur = self.conn.cursor()
        # PRs that touched the component
        cur.execute(
            """
            SELECT DISTINCT pr_id
            FROM pr_files
            WHERE component = ?
            """,
            (component,),
        )
        touched = {row[0] for row in cur.fetchall()}
        # PRs that failed this test
        cur.execute(
            """
            SELECT DISTINCT pr_id
            FROM test_events
            WHERE ts >= ? AND test_id = ? AND status = 'failed'
            """,
            (cutoff, test_id),
        )
        failed = {row[0] for row in cur.fetchall()}
        # Universe: PRs seen in the window (i.e. with test events)
        cur.execute(
            """
            SELECT DISTINCT pr_id
            FROM test_events
            WHERE ts >= ?
            """,
            (cutoff,),
        )
        universe = {row[0] for row in cur.fetchall()}
        # Compute counts
        A = len(touched & failed)
        B = len(touched - failed)
        C = len(failed - touched)
        D = len(universe - touched - failed)
        return A, B, C, D

    # -------------------------- Guidance ------------------------------ #
    def upsert_guidance(self, rule: Dict) -> None:
        """Insert or update a guidance record."""
        now = datetime.now(timezone.utc).isoformat()
        self.conn.execute(
            """
            INSERT INTO guidance
              (rule_id, component, test_id, support_prs, confidence, baseline, lift,
               p_value, active, last_seen, created_at, template, command)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(rule_id) DO UPDATE SET
              support_prs=excluded.support_prs,
              confidence=excluded.confidence,
              baseline=excluded.baseline,
              lift=excluded.lift,
              p_value=excluded.p_value,
              active=1,
              last_seen=excluded.last_seen,
              template=excluded.template,
              command=excluded.command
            """,
            (
                rule["rule_id"],
                rule["component"],
                rule["test_id"],
                rule["support_prs"],
                rule["confidence"],
                rule["baseline"],
                rule["lift"],
                rule["p_value"],
                1,
                now,
                now,
                rule["template"],
                rule["command"],
            ),
        )

    def get_active_guidance(self) -> List[Dict]:
        """Return all active guidance rules ordered by component."""
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT rule_id, component, test_id, support_prs, confidence, baseline, lift,
                   p_value, template, command
            FROM guidance
            WHERE active = 1
            ORDER BY component, lift DESC
            """
        )
        rows = cur.fetchall()
        return [
            {
                "rule_id": r[0],
                "component": r[1],
                "test_id": r[2],
                "support_prs": r[3],
                "confidence": r[4],
                "baseline": r[5],
                "lift": r[6],
                "p_value": r[7],
                "template": r[8],
                "command": r[9],
            }
            for r in rows
        ]

    def get_active_guidance_by_component(self, components: Iterable[str]) -> List[Dict]:
        """Return active guidance filtered by a list of components."""
        if not components:
            return []
        cur = self.conn.cursor()
        q = ",".join("?" for _ in components)
        cur.execute(
            f"""
            SELECT component, test_id, command
            FROM guidance
            WHERE active = 1 AND component IN ({q})
            """,
            tuple(components),
        )
        return [{"component": c, "test_id": t, "command": cmd} for c, t, cmd in cur.fetchall()]

    def get_components_for_pr(self, pr_id: int) -> List[str]:
        """Return a list of distinct components touched by the PR."""
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT DISTINCT component
            FROM pr_files
            WHERE pr_id = ?
            """,
            (pr_id,),
        )
        return [row[0] for row in cur.fetchall() if row[0] != "unknown"]

    def prune_guidance(self, window_days: int, last_n: int) -> None:
        """Deactivate guidance rules with insufficient recent evidence.

        A rule becomes inactive if:
          - It has no failures in the last ``last_n`` PRs, OR
          - Its lift drops below 1.5 when recomputed with current data.
        """
        cutoff_ts = (datetime.now(timezone.utc) - timedelta(days=window_days)).isoformat()
        cur = self.conn.cursor()
        # Gather rule IDs
        cur.execute("SELECT rule_id, component, test_id FROM guidance WHERE active = 1")
        rows = cur.fetchall()
        for rule_id, component, test_id in rows:
            # Count failures in window
            cur.execute(
                """
                SELECT COUNT(DISTINCT pr_id)
                FROM test_events
                WHERE ts >= ? AND component = ? AND test_id = ? AND status = 'failed'
                """,
                (cutoff_ts, component, test_id),
            )
            cnt = cur.fetchone()[0]
            if cnt < 1:
                self.conn.execute(
                    "UPDATE guidance SET active = 0 WHERE rule_id = ?", (rule_id,)
                )
                continue
            # Recompute lift with current data
            A, B, C, D = self.contingency(component, test_id, window_days)
            conf = A / max(A + B, 1)
            base = C / max(C + D, 1)
            lift = conf / max(base, 1e-6)
            if lift < 1.5:
                self.conn.execute(
                    "UPDATE guidance SET active = 0 WHERE rule_id = ?", (rule_id,)
                )

    # -------------------------- Export ------------------------------- #
    def export_stats(self) -> Dict:
        """Return basic statistics about test events and guidance."""
        cur = self.conn.cursor()
        cur.execute("SELECT COUNT(*) FROM test_events WHERE status='failed'")
        failed = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM test_events")
        total = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM guidance WHERE active=1")
        active = cur.fetchone()[0]
        return {"events_total": total, "events_failed": failed, "guidance_active": active}


class InMemoryStorage(StorageProtocol):
    """Simple in-memory storage used for tests."""

    def __init__(self, path: str | None = None) -> None:
        self.pr_files: Dict[int, List[Dict]] = {}
        self.test_events: List[Dict] = []
        self.guidance: List[Dict] = []

    def record_pr(
        self,
        *,
        pr_id: int,
        branch: str,
        base: str,
        labels: List[str],
        files: List[Dict],
    ) -> None:
        self.pr_files[pr_id] = files

    def record_test_event(
        self,
        *,
        run_id: str,
        pr_id: int,
        commit_sha: str,
        test_id: str,
        suite: str,
        status: str,
        duration_ms: int,
        component: str,
        file_hint: str,
        ts: str,
    ) -> None:
        self.test_events.append(
            {
                "run_id": run_id,
                "pr_id": pr_id,
                "commit_sha": commit_sha,
                "test_id": test_id,
                "suite": suite,
                "status": status,
                "duration_ms": duration_ms,
                "component": component,
                "file_hint": file_hint,
                "ts": ts,
            }
        )

    def distinct_pairs(self, window_days: int) -> Iterable[Tuple[str, str]]:
        return []

    def contingency(
        self, component: str, test_id: str, window_days: int
    ) -> Tuple[int, int, int, int]:
        return (0, 0, 0, 0)

    def upsert_guidance(self, rule: Dict) -> None:
        self.guidance.append(rule)

    def get_components_for_pr(self, pr_id: int) -> List[str]:
        return [f["component"] for f in self.pr_files.get(pr_id, [])]

    def get_active_guidance_by_component(
        self, components: Iterable[str]
    ) -> List[Dict]:
        return [g for g in self.guidance if g.get("component") in set(components)]

    def get_active_guidance(self) -> List[Dict]:
        return list(self.guidance)

    def prune_guidance(self, window_days: int, last_n: int | None) -> None:
        return None

    def export_stats(self) -> Dict:
        return {
            "events_total": len(self.test_events),
            "events_failed": len([e for e in self.test_events if e["status"] == "failed"]),
            "guidance_active": len(self.guidance),
        }
