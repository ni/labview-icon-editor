"""Command‑line interface for the codex rules engine.

The CLI exposes subcommands that mirror the high‑level workflow:

  - ``record-pr``: record PR metadata and touched files.
  - ``ingest-tests``: parse test results (e.g. JUnit) and store failing events.
  - ``analyze``: compute component/test correlations and update guidance.
  - ``update-docs``: rewrite the guidance section in AGENTS.md.
  - ``emit-warnings``: print warnings when a PR touches components with active
    guidance.
  - ``prune``: mark stale guidance rules inactive.
  - ``export``: export guidance or stats as JSON for debugging.

The engine is fully self‑contained and does not require GitHub Actions.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from glob import glob
from pathlib import Path
from typing import Dict, List, Type

from .config import load_config
from .mapping import ComponentMapping
from .storage import Storage, StorageProtocol
from .ingest.junit import parse_junit
from .ingest.pytest_json import parse_pytest_json
from .ingest.jest_json import parse_jest_json
from .correlate import compute_candidates
from .guidance import (
    create_guidance_entries,
    update_agents_md,
)
from .warnings import build_warnings
from .compliance import load_manifest as load_exec_manifest, check as check_compliance
from .memory import (
    REPO_ROOT,
    MEMORY_PATH,  # absolute path to memory file
    append_entry as memory_append_entry,  # for writing to persistent memory
)
from .telemetry import record_telemetry_entry


def _git_env() -> Dict[str, str]:
    env = dict(os.environ)
    env.pop("GIT_DIR", None)
    env.pop("GIT_WORK_TREE", None)
    return env


def _stage_memory_file() -> None:
    try:
        subprocess.run(
            ["git", "-C", str(REPO_ROOT), "add", "--", ".codex/memory.json"],
            check=True,
            env=_git_env(),
        )
    except (subprocess.CalledProcessError, OSError) as exc:
        print(
            f"[codex-rules] Error: failed to stage .codex/memory.json: {exc}",
            file=sys.stderr,
        )
        code = exc.returncode if isinstance(exc, subprocess.CalledProcessError) else 1
        raise SystemExit(code) from exc


def main(
    argv: List[str] | None = None,
    *,
    storage_cls: Type[StorageProtocol] = Storage,
    storage: StorageProtocol | None = None,
) -> None:
    """Entry point for the CLI."""
    argv = argv or sys.argv[1:]
    parser = argparse.ArgumentParser(
        description="codex rules engine", allow_abbrev=False
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # record-pr
    rec = sub.add_parser(
        "record-pr", help="Record pull request metadata and touched files"
    )
    rec.add_argument("--pr", required=True, type=int, dest="pr_id")
    rec.add_argument("--files-json", required=True, help="Path to PR files JSON")
    rec.add_argument("--labels", default="", help="Comma‑separated labels")
    rec.add_argument("--branch", default="")
    rec.add_argument("--base", default="")

    # ingest-tests
    inj = sub.add_parser(
        "ingest-tests", help="Ingest test results from JUnit XML or custom JSON"
    )
    inj.add_argument(
        "--pr", required=True, type=int, dest="pr_id", help="PR identifier"
    )
    inj.add_argument(
        "--format",
        choices=["junit", "pytest-json", "jest-json", "custom"],
        default="junit",
        help="Input format",
    )
    inj.add_argument(
        "--path",
        required=True,
        help="Glob pattern for test result files (e.g. 'results/*.xml')",
    )
    inj.add_argument(
        "--commit",
        default="",
        help="Commit SHA for the test run (optional)",
    )
    inj.add_argument(
        "--run-id",
        default="",
        help="Unique run identifier (optional)",
    )

    # analyze
    ana = sub.add_parser(
        "analyze",
        help="Compute correlations between components and test failures",
    )
    ana.add_argument(
        "--window-days",
        type=int,
        default=None,
        help="Lookback window in days (overrides config)",
    )

    # update-docs
    upd = sub.add_parser(
        "update-docs",
        help="Rewrite the Preventative Measures block in AGENTS.md",
    )
    upd.add_argument(
        "--file",
        default=None,
        help="Target file (defaults to config.docs.file)",
    )

    # emit-warnings
    warn = sub.add_parser(
        "emit-warnings",
        help="Emit preventative guidance warnings for a PR",
    )
    warn.add_argument("--pr", required=True, type=int, dest="pr_id")
    warn.add_argument(
        "--stdout",
        action="store_true",
        help="Print warnings to stdout",
    )
    warn.add_argument(
        "--manifest",
        default=None,
        help="Path to manifest of commands actually run (JSON/NDJSON/text)",
    )
    warn.add_argument(
        "--fail-on-violation",
        action="store_true",
        help="Exit non-zero if required commands were not run",
    )
    warn.add_argument(
        "--require-any",
        action="store_true",
        help="Require any one of the required commands instead of all",
    )
    warn.add_argument(
        "--ci-log-path",
        dest="ci_log_paths",
        action="append",
        default=[],
        help="Path to CI log file to record in telemetry (repeatable)",
    )
    warn.add_argument(
        "--failing-test",
        dest="failing_tests",
        action="append",
        default=[],
        help="Identifier of a failing test to record in telemetry",
    )
    warn.add_argument(
        "--srs-id",
        dest="srs_ids",
        action="append",
        default=[],
        help="SRS requirement ID to record in telemetry (repeatable)",
    )
    warn.add_argument(
        "--record-telemetry",
        action="store_true",
        help="Record inspected modules and skipped checks to .codex/telemetry.json",
    )
    warn.add_argument(
        "--agent-feedback",
        dest="agent_feedback",
        default=None,
        help="Freeform agent feedback to include in telemetry (requires --record-telemetry)",
    )

    # prune
    prn = sub.add_parser(
        "prune", help="Mark stale guidance inactive based on recent data"
    )
    prn.add_argument(
        "--window-days",
        type=int,
        default=None,
        help="Lookback window for pruning (overrides config)",
    )
    prn.add_argument(
        "--last-n",
        type=int,
        default=50,
        help="Deactivate rules with fewer than this many recent PRs",
    )

    # export
    exp = sub.add_parser(
        "export", help="Export guidance or stats to JSON for debugging"
    )
    exp.add_argument(
        "--what",
        choices=["guidance", "stats"],
        required=True,
        help="Which data to export",
    )
    exp.add_argument("--out", required=True, help="Output JSON file")

    # check-compliance (explicit gate)
    gate = sub.add_parser(
        "check-compliance",
        help="Validate that required pre‑emptive commands were actually run for this PR",
    )
    gate.add_argument("--pr", required=True, type=int, dest="pr_id")
    gate.add_argument(
        "--manifest",
        required=False,
        help="Path to manifest (defaults to config.compliance.manifest_path)",
    )
    gate.add_argument(
        "--require-any",
        action="store_true",
        help="Require any one of the required commands instead of all",
    )

    # memory (persistent in-repo memory)
    mem = sub.add_parser(
        "memory",
        help="Read from or append to the persistent memory file",
    )
    mem_sub = mem.add_subparsers(dest="memory_cmd", required=True)
    mem_read = mem_sub.add_parser(
        "read",
        help="Print the contents of the memory file",
    )
    mem_append = mem_sub.add_parser(
        "append",
        help="Append an entry to the memory file",
    )
    mem_append.add_argument(
        "--summary",
        required=True,
        help="Summary text to store in the memory entry",
    )
    mem_append.add_argument(
        "--author",
        default=None,
        help="Optional author name for the entry",
    )

    # run-workflow
    run = sub.add_parser(
        "run-workflow",
        help="Record PR, ingest tests, analyze, and emit warnings",
    )
    run.add_argument(
        "--pr", type=int, dest="pr_id", required=False, help="Pull request ID"
    )
    run.add_argument("--files-json", help="Path to JSON list of PR files")
    run.add_argument(
        "--diff-base",
        default="origin/main",
        help="Base ref for diff when computing files",
    )
    run.add_argument(
        "--format",
        choices=["junit", "pytest-json", "jest-json", "custom"],
        default="junit",
        help="Test results format",
    )
    run.add_argument(
        "--results-path",
        required=True,
        help="Glob pattern for test result files",
    )
    run.add_argument(
        "--commit", default="", help="Commit SHA for the test run (optional)"
    )
    run.add_argument("--run-id", default="", help="Unique run identifier (optional)")
    run.add_argument(
        "--manifest",
        default=None,
        help="Path to manifest of commands actually run",
    )
    run.add_argument(
        "--require-any",
        action="store_true",
        help="Require any one of the required commands instead of all",
    )
    run.add_argument(
        "--fail-on-violation",
        action="store_true",
        help="Exit non-zero if required commands were not run",
    )
    run.add_argument(
        "--ci-log-path",
        dest="ci_log_paths",
        action="append",
        default=[],
        help="Path to CI log file to record in telemetry (repeatable)",
    )
    run.add_argument(
        "--failing-test",
        dest="failing_tests",
        action="append",
        default=[],
        help="Identifier of a failing test to record in telemetry",
    )
    run.add_argument(
        "--srs-id",
        dest="srs_ids",
        action="append",
        default=[],
        help="SRS requirement ID to record in telemetry (repeatable)",
    )
    run.add_argument(
        "--record-telemetry",
        action="store_true",
        help="Record inspected modules and skipped checks to .codex/telemetry.json",
    )
    run.add_argument(
        "--agent-feedback",
        dest="agent_feedback",
        default=None,
        help="Freeform agent feedback to include in telemetry (requires --record-telemetry)",
    )
    run.add_argument(
        "--update-docs", action="store_true", help="Rewrite AGENTS.md after analysis"
    )
    run.add_argument("--prune", action="store_true", help="Prune stale guidance rules")
    run.add_argument(
        "--window-days",
        type=int,
        default=None,
        help="Lookback window in days (overrides config)",
    )
    # Memory summary options
    run.add_argument(
        "--memory-summary",
        help="Summary text to store in the persistent memory (if provided)",
    )
    run.add_argument(
        "--memory-author",
        default=None,
        help="Optional author name for the memory entry",
    )

    args = parser.parse_args(argv)
    config = load_config()
    # Optionally override window_days on CLI
    if getattr(args, "window_days", None):
        config["window_days"] = args.window_days
    db_path = config["storage"]["sqlite_path"]
    storage_obj = storage or storage_cls(db_path)
    mapping = ComponentMapping(config.get("components_file", ".codex/components.yml"))

    if args.command == "record-pr":
        record_pr(args, storage_obj, mapping)
    elif args.command == "ingest-tests":
        ingest_tests(args, storage_obj, mapping)
    elif args.command == "analyze":
        analyze(args, storage_obj, config)
    elif args.command == "update-docs":
        update_docs(args, storage_obj, config)
    elif args.command == "emit-warnings":
        if args.agent_feedback and not args.record_telemetry:
            print(
                "[codex-rules] --agent-feedback requires --record-telemetry",
                file=sys.stderr,
            )
            sys.exit(2)
        emit_warnings(args, storage_obj, config)
        if args.record_telemetry:
            components = storage_obj.get_components_for_pr(args.pr_id)
            guidance = storage_obj.get_active_guidance_by_component(components)
            required = sorted({g["command"] for g in guidance})
            checks_skipped: List[str] = []
            if args.manifest:
                executed = load_exec_manifest(args.manifest)
                ok, missing = check_compliance(
                    required, executed, mode="any" if args.require_any else "all"
                )
                if not ok:
                    checks_skipped = missing
            entry = {
                "pr_id": args.pr_id,
                "modules_inspected": components,
                "checks_skipped": checks_skipped,
            }
            if args.ci_log_paths:
                entry["ci_log_paths"] = args.ci_log_paths
            if args.failing_tests:
                entry["failing_tests"] = args.failing_tests
            try:
                record_telemetry_entry(
                    entry,
                    agent_feedback=args.agent_feedback,
                    srs_ids=args.srs_ids,
                )
                subprocess.run(
                    ["git", "add", ".codex/telemetry.json", "telemetry/summary.json"],
                    check=False,
                )
            except Exception as exc:
                print(
                    f"[codex-rules] Error recording telemetry for PR {args.pr_id}: {exc}",
                    file=sys.stderr,
                )
    elif args.command == "prune":
        prune(args, storage_obj, config)
    elif args.command == "export":
        export_data(args, storage_obj)
    elif args.command == "check-compliance":
        gate_compliance(args, storage_obj, config)
    elif args.command == "run-workflow":
        run_workflow(args, storage_obj, mapping, config)
    elif args.command == "memory":
        if args.memory_cmd == "read":
            memory_read(args, config)
        elif args.memory_cmd == "append":
            memory_append(args, config)
        else:
            parser.error("Unknown memory subcommand")
    else:
        parser.error(f"Unknown command {args.command!r}")


def run_workflow(
    args: argparse.Namespace,
    storage: StorageProtocol | Type[StorageProtocol],
    mapping: ComponentMapping,
    config: Dict,
) -> None:
    """Run the full analysis workflow for a PR."""
    if args.agent_feedback and not args.record_telemetry:
        print(
            "[codex-rules] --agent-feedback requires --record-telemetry",
            file=sys.stderr,
        )
        sys.exit(2)
    if isinstance(storage, type):
        storage = storage(config["storage"]["sqlite_path"])
    pr_id = args.pr_id
    if pr_id is None:
        for env in ("PR_NUMBER", "CI_PR_NUMBER", "GITHUB_PR_NUMBER"):
            val = os.environ.get(env)
            if val:
                try:
                    pr_id = int(val)
                    break
                except ValueError:
                    continue
    if pr_id is None:
        print("[codex-rules] PR number is required", file=sys.stderr)
        sys.exit(1)

    # Determine files
    if args.files_json:
        with open(args.files_json, "r", encoding="utf-8") as f:
            files = json.load(f)
    else:
        diff_base = args.diff_base
        out = subprocess.check_output(
            ["git", "diff", "--name-status", diff_base], text=True
        )
        files = []
        status_map = {"A": "added", "M": "modified", "D": "deleted"}
        for line in out.strip().splitlines():
            if not line.strip():
                continue
            status, path = line.split("\t", 1)
            kind = status_map.get(status)
            if kind:
                files.append({"path": path, "status": kind})

    file_records = []
    for fobj in files:
        path = fobj.get("path")
        status = fobj.get("status", "")
        comp = mapping.component_for_path(path)
        file_records.append({"path": path, "status": status, "component": comp})
    storage.record_pr(pr_id=pr_id, branch="", base="", labels=[], files=file_records)

    inj_args = argparse.Namespace(
        pr_id=pr_id,
        format=args.format,
        path=args.results_path,
        commit=args.commit or "",
        run_id=args.run_id or "",
    )
    ingest_tests(inj_args, storage, mapping)

    ana_args = argparse.Namespace(window_days=args.window_days)
    analyze(ana_args, storage, config)

    upd_args = argparse.Namespace(file=None)
    if args.update_docs:
        update_docs(upd_args, storage, config)

    if args.prune:
        prune_args = argparse.Namespace(window_days=args.window_days, last_n=None)
        prune(prune_args, storage, config)
        if args.update_docs:
            update_docs(upd_args, storage, config)

    warn_args = argparse.Namespace(
        pr_id=pr_id,
        stdout=True,
        manifest=args.manifest,
        require_any=args.require_any,
        fail_on_violation=args.fail_on_violation,
    )
    emit_warnings(warn_args, storage, config)

    components = storage.get_components_for_pr(pr_id)
    if args.record_telemetry:
        guidance = storage.get_active_guidance_by_component(components)
        required = sorted({g["command"] for g in guidance})
        checks_skipped: List[str] = []
        if args.manifest:
            executed = load_exec_manifest(args.manifest)
            ok, missing = check_compliance(
                required, executed, mode="any" if args.require_any else "all"
            )
            if not ok:
                checks_skipped = missing
        entry = {
            "pr_id": pr_id,
            "modules_inspected": components,
            "checks_skipped": checks_skipped,
        }
        if args.ci_log_paths:
            entry["ci_log_paths"] = args.ci_log_paths
        if args.failing_tests:
            entry["failing_tests"] = args.failing_tests
        try:
            record_telemetry_entry(
                entry,
                agent_feedback=args.agent_feedback,
                srs_ids=args.srs_ids,
            )
            subprocess.run(
                ["git", "add", ".codex/telemetry.json", "telemetry/summary.json"],
                check=False,
            )
        except Exception as exc:
            print(
                f"[codex-rules] Error recording telemetry for PR {pr_id} (run-workflow): {exc}",
                file=sys.stderr,
            )

    # If a memory summary is provided, append it to memory and stage the file for commit
    if getattr(args, "memory_summary", None):
        entry = {"summary": args.memory_summary}
        if getattr(args, "memory_author", None):
            entry["author"] = args.memory_author
        try:
            memory_append_entry(entry)
        except Exception as exc:
            print(
                f"[codex-rules] Error: failed to write .codex/memory.json: {exc}",
                file=sys.stderr,
            )
            raise SystemExit(1) from exc
        _stage_memory_file()


def record_pr(
    args: argparse.Namespace, storage: StorageProtocol, mapping: ComponentMapping
) -> None:
    """Record metadata for a pull request, including its files."""
    pr_id = args.pr_id
    labels = [l.strip() for l in args.labels.split(",") if l.strip()]
    # Load files JSON: expected [{"path": "...", "status": "..."}]
    with open(args.files_json, "r", encoding="utf-8") as f:
        files = json.load(f)
    # Derive components for each file based on globs
    file_records = []
    for fobj in files:
        path = fobj.get("path")
        status = fobj.get("status", "")
        comp = mapping.component_for_path(path)
        file_records.append({"path": path, "status": status, "component": comp})
    storage.record_pr(
        pr_id=pr_id,
        branch=args.branch or "",
        base=args.base or "",
        labels=labels,
        files=file_records,
    )


def ingest_tests(
    args: argparse.Namespace, storage: StorageProtocol, mapping: ComponentMapping
) -> None:
    """Ingest test results for a PR and record failing events."""
    pr_id = args.pr_id
    run_id = args.run_id or f"run-{datetime.utcnow().isoformat()}"
    commit_sha = args.commit or ""
    # Expand glob for result files
    files = glob(args.path)
    if not files:
        print(f"No files match {args.path!r}", file=sys.stderr)
        return
    for fpath in files:
        if args.format == "junit":
            events = parse_junit(fpath)
        elif args.format == "pytest-json":
            events = parse_pytest_json(fpath)
        elif args.format == "jest-json":
            events = parse_jest_json(fpath)
        elif args.format == "custom":
            with open(fpath, "r", encoding="utf-8") as f:
                events = json.load(f)
        else:
            raise ValueError(f"Unsupported format {args.format}")
        for evt in events:
            # Determine component based on file hint or fallback to 'unknown'
            hint = evt.get("file")
            comp = "unknown"
            if hint:
                comp = mapping.component_for_path(hint)
            storage.record_test_event(
                run_id=run_id,
                pr_id=pr_id,
                commit_sha=commit_sha,
                test_id=evt.get("test_id"),
                suite=evt.get("suite"),
                status=evt.get("status"),
                duration_ms=evt.get("duration_ms", 0),
                component=comp,
                file_hint=hint or "",
                ts=datetime.utcnow().isoformat(),
            )


def analyze(args: argparse.Namespace, storage: StorageProtocol, config: Dict) -> None:
    """Compute component/test correlations and update guidance table."""
    # Retrieve thresholds from config
    thresh = {
        "min_occurrences": config.get("min_occurrences", 3),
        "min_confidence": config.get("min_confidence", 0.25),
        "min_lift": config.get("min_lift", 3.0),
        "alpha": config.get("alpha", 0.01),
        "flaky_threshold": config.get("flaky_threshold", 0.04),
        "min_lift_for_flaky": config.get("min_lift_for_flaky", 3.0),
        "window_days": config.get("window_days", 30),
    }
    candidates = compute_candidates(storage, thresh)
    # Load templates and commands from configuration
    tpl_path = config.get("templates_file", ".codex/guidance_templates.yml")
    if Path(tpl_path).suffix.lower() == ".json":
        templates = json.loads(Path(tpl_path).read_text(encoding="utf-8"))
    else:
        try:
            import yaml  # type: ignore

            templates = yaml.safe_load(Path(tpl_path).read_text(encoding="utf-8"))
        except Exception:
            templates = {}
    guidance = create_guidance_entries(candidates, templates)
    # Upsert guidance into storage
    for rule in guidance:
        storage.upsert_guidance(rule)


def update_docs(
    args: argparse.Namespace, storage: StorageProtocol, config: Dict
) -> None:
    """Rewrite the AGENTS.md file with the current guidance rules."""
    doc_file = args.file or config["docs"]["file"]
    # Read active guidance from storage
    guidance = storage.get_active_guidance()
    section_title = config["docs"].get("section_title", "Preventative Measures")
    update_agents_md(doc_file, guidance, section_title)


def emit_warnings(
    args: argparse.Namespace, storage: StorageProtocol, config: Dict
) -> None:
    """Emit preventative guidance warnings for a given PR."""
    pr_id = args.pr_id
    # Lookup components touched by this PR
    components = storage.get_components_for_pr(pr_id)
    guidance = storage.get_active_guidance_by_component(components)
    if not guidance:
        return
    messages = build_warnings(components, guidance)
    if args.stdout:
        for line in messages:
            sys.stdout.write(line + "\n")
    # Optional compliance gate using manifest
    manifest_path = args.manifest or (config.get("compliance", {}) or {}).get(
        "manifest_path"
    )
    if manifest_path:
        executed = load_exec_manifest(manifest_path)
        required = sorted({g["command"] for g in guidance})
        mode = "any" if args.require_any else "all"
        ok, missing = check_compliance(required, executed, mode=mode)
        if not ok:
            sys.stdout.write(
                "[codex-rules] Compliance violation: missing required pre‑emptive commands:\n"
            )
            for m in missing:
                sys.stdout.write(f"  - {m}\n")
            if args.fail_on_violation:
                sys.exit(2)
        else:
            sys.stdout.write(
                "[codex-rules] Compliance OK (pre‑emptive commands satisfied).\n"
            )
    # If provider posting is desired, wire it here in a future revision.


def prune(args: argparse.Namespace, storage: StorageProtocol, config: Dict) -> None:
    """Mark stale guidance rules as inactive."""
    window_days = args.window_days or config.get("window_days", 30)
    last_n = args.last_n
    storage.prune_guidance(window_days, last_n)


def memory_read(args: argparse.Namespace, config: Dict) -> None:
    """Print the contents of the memory file."""
    from .memory import load_memory

    entries = load_memory()
    if not entries:
        print("(memory is empty)")
        return
    for idx, entry in enumerate(entries, 1):
        ts = entry.get("timestamp", "")
        author = entry.get("author") or ""
        summary = entry.get("summary") or ""
        print(f"{idx}. [{ts}] {author} - {summary}")


def memory_append(args: argparse.Namespace, config: Dict) -> None:
    """Append a new entry to the memory file."""
    from .memory import append_entry

    entry = {"summary": args.summary}
    if args.author:
        entry["author"] = args.author
    try:
        append_entry(entry)
    except BaseException as exc:
        print(
            f"[codex-rules] Error: failed to write .codex/memory.json: {exc}",
            file=sys.stderr,
        )
        code = (
            exc.code
            if isinstance(exc, SystemExit)
            else getattr(exc, "errno", getattr(exc, "returncode", 1))
        )
        raise SystemExit(code) from exc
    _stage_memory_file()
    print("[codex-rules] Memory entry appended.")


def export_data(args: argparse.Namespace, storage: StorageProtocol) -> None:
    """Export guidance or stats to a JSON file."""
    if args.what == "guidance":
        data = storage.get_active_guidance()
    elif args.what == "stats":
        data = storage.export_stats()
    else:
        raise ValueError(f"Unknown export type {args.what}")
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def gate_compliance(
    args: argparse.Namespace, storage: StorageProtocol, config: Dict
) -> None:
    """Explicit compliance gate: fails if required commands missing."""
    pr_id = args.pr_id
    components = storage.get_components_for_pr(pr_id)
    guidance = storage.get_active_guidance_by_component(components)
    if not guidance:
        print("[codex-rules] No active guidance for this PR; nothing to check.")
        return
    manifest_path = args.manifest or (config.get("compliance", {}) or {}).get(
        "manifest_path"
    )
    if not manifest_path:
        print(
            "[codex-rules] No manifest path provided or configured; cannot check compliance.",
            file=sys.stderr,
        )
        sys.exit(2)
    executed = load_exec_manifest(manifest_path)
    required = sorted({g["command"] for g in guidance})
    mode = "any" if args.require_any else "all"
    ok, missing = check_compliance(required, executed, mode=mode)
    if not ok:
        print(
            "[codex-rules] Compliance violation: missing required pre‑emptive commands:"
        )
        for m in missing:
            print(f"  - {m}")
        sys.exit(2)
    print("[codex-rules] Compliance OK (pre‑emptive commands satisfied).")
