import sqlite3
from pathlib import Path

from codex_rules.storage import Storage


def test_migrates_commit_column_and_inserts(temp_dir: Path) -> None:
    db_path = temp_dir / "db.sqlite"
    conn = sqlite3.connect(db_path.as_posix())
    conn.executescript(
        """
        CREATE TABLE test_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT,
            pr_id INTEGER,
            "commit" TEXT,
            test_id TEXT,
            suite TEXT,
            status TEXT,
            duration_ms INTEGER,
            component TEXT,
            file_hint TEXT,
            ts TEXT
        );
        """
    )
    conn.close()

    storage = Storage(db_path.as_posix())
    cur = storage.conn.cursor()
    cur.execute("PRAGMA table_info(test_events)")
    cols = [row[1] for row in cur.fetchall()]
    assert "commit_sha" in cols and "commit" not in cols

    storage.record_test_event(
        run_id="r",
        pr_id=1,
        commit_sha="abc",
        test_id="t",
        suite="s",
        status="passed",
        duration_ms=0,
        component="c",
        file_hint="",
        ts="now",
    )
    cur.execute("SELECT commit_sha FROM test_events")
    assert cur.fetchone()[0] == "abc"
    storage.conn.close()

