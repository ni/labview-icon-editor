#!/usr/bin/env python3
"""Generate ISO 29119-3 aligned test status/completion reports."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Tuple

from rtm_utils import (
    Coverage,
    MIN_HIGH,
    MIN_TOTAL,
    ROOT,
    compute_coverage,
    detect_suites,
    load_rtm,
    resolve_test_path,
)

REPORTS_DIR = ROOT / "reports"
PERFORMANCE_BASELINES_PATH = ROOT / "docs" / "testing" / "performance-baselines.json"
DEFAULT_PERFORMANCE_RESULTS_PATH = REPORTS_DIR / "performance-measurements.json"
DEFAULT_PORTABILITY_RESULTS_PATH = REPORTS_DIR / "portability-status.json"
DETAIL_LIMIT = 5
RESULTS_SCHEMA = "test-results/v1"
INCIDENT_ENV_VAR = "TEST_INCIDENT_URLS"


def safe_load_json(path: Path) -> Tuple[object, List[str]]:
    """Load JSON from path, returning data and any parsing issues as messages."""
    notes: List[str] = []
    rel = path
    try:
        rel = path.relative_to(ROOT)
    except Exception:
        pass
    if not path.exists():
        notes.append(f"{rel} not found")
        return [], notes
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle), notes
    except Exception as exc:  # pragma: no cover - defensive logging
        notes.append(f"Failed to parse {rel}: {exc}")
        return [], notes


def load_performance_baselines() -> Tuple[dict, List[str]]:
    """Return indexed baselines keyed by (scenario, architecture, metric)."""
    data, notes = safe_load_json(PERFORMANCE_BASELINES_PATH)
    baselines = {}
    if not isinstance(data, list):
        if data:
            notes.append("Baseline file is not a list; skipping performance baselines.")
        return baselines, notes

    for entry in data:
        scenario = str(entry.get("scenario", "")).strip()
        architecture = str(entry.get("architecture", "")).strip()
        metric = str(entry.get("metric", "")).strip()
        tolerance = entry.get("tolerance_pct", 0.10)
        baseline_value = entry.get("baseline_value")
        key = (scenario, architecture, metric)

        try:
            tolerance_f = float(tolerance)
        except Exception:
            notes.append(f"Invalid tolerance_pct for {key}; using 0.10.")
            tolerance_f = 0.10

        try:
            baseline_f = float(baseline_value)
        except Exception:
            notes.append(f"Invalid baseline_value for {key}; entry skipped.")
            continue

        if not scenario or not architecture or not metric:
            notes.append(f"Incomplete baseline entry {entry}; entry skipped.")
            continue

        baselines[key] = {
            "baseline": baseline_f,
            "tolerance": tolerance_f,
            "unit": str(entry.get("unit", "")).strip(),
        }
    return baselines, notes


def load_performance_measurements(path: Path) -> Tuple[List[dict], List[str]]:
    """Return measurement entries as list of dicts."""
    data, notes = safe_load_json(path)
    if not isinstance(data, list):
        if data:
            notes.append("Performance measurements file is not a list; skipping.")
        return [], notes
    cleaned = []
    for entry in data:
        scenario = str(entry.get("scenario", "")).strip()
        architecture = str(entry.get("architecture", "")).strip()
        metric = str(entry.get("metric", "")).strip()
        value = entry.get("value")
        try:
            value_f = float(value)
        except Exception:
            notes.append(f"Invalid measurement value for {scenario}/{architecture}/{metric}; entry skipped.")
            continue
        if not scenario or not architecture or not metric:
            notes.append(f"Incomplete measurement entry {entry}; entry skipped.")
            continue
        cleaned.append(
            {
                "scenario": scenario,
                "architecture": architecture,
                "metric": metric,
                "value": value_f,
                "unit": str(entry.get("unit", "")).strip(),
                "source": entry.get("source", ""),
            }
        )
    return cleaned, notes


def summarize_performance(measurement_path: Path) -> Tuple[List[str], bool]:
    baselines, baseline_notes = load_performance_baselines()
    measurements, measurement_notes = load_performance_measurements(measurement_path)
    lines: List[str] = []
    blocker = False

    if measurement_notes and not measurements:
        rel = measurement_path.relative_to(ROOT) if measurement_path.is_absolute() else measurement_path
        lines.append(f"- Performance: no measurements provided (expected at {rel}).")
        if baseline_notes:
            lines.extend([f"  - {note}" for note in baseline_notes])
        lines.extend([f"  - {note}" for note in measurement_notes])
        return lines, blocker

    if not baselines:
        lines.append("- Performance: no baselines found; comparison skipped.")
        if baseline_notes:
            lines.extend([f"  - {note}" for note in baseline_notes])
        return lines, blocker

    failures: List[str] = []
    warnings: List[str] = []
    passes: List[str] = []
    measured_keys = set()
    max_delta = 0.0

    for measurement in measurements:
        key = (measurement["scenario"], measurement["architecture"], measurement["metric"])
        measured_keys.add(key)
        baseline = baselines.get(key)
        if not baseline:
            warnings.append(f"No baseline for {measurement['scenario']} [{measurement['architecture']}, {measurement['metric']}]")
            continue

        baseline_value = baseline["baseline"]
        tolerance = baseline["tolerance"]
        if baseline_value == 0:
            warnings.append(f"Baseline value is 0 for {key}; cannot compute delta.")
            continue

        delta_pct = (measurement["value"] - baseline_value) / baseline_value
        max_delta = max(max_delta, delta_pct)
        if delta_pct > tolerance:
            failures.append(
                f"{measurement['scenario']} [{measurement['architecture']}, {measurement['metric']}] "
                f"{measurement['value']}{measurement['unit'] or ''} vs {baseline_value}{baseline['unit'] or ''} "
                f"(+{delta_pct:.0%} > {tolerance:.0%})"
            )
        else:
            passes.append(
                f"{measurement['scenario']} [{measurement['architecture']}, {measurement['metric']}] "
                f"{measurement['value']}{measurement['unit'] or ''} vs {baseline_value}{baseline['unit'] or ''} "
                f"(+{delta_pct:.0%}, tol {tolerance:.0%})"
            )

    missing_measurements = set(baselines.keys()) - measured_keys
    if missing_measurements:
        names = [f"{s}[{a},{m}]" for s, a, m in sorted(missing_measurements)]
        warnings.append(f"Unmeasured baselines: {', '.join(names)}")

    status = "FAIL" if failures else "WARN" if warnings else "PASS"
    if measurements:
        lines.append(
            f"- Performance: {status} ({len(measurements)} measurements; "
            f"{len(failures)} over tolerance; max delta +{max_delta:.0%})"
        )
    else:
        lines.append("- Performance: no measurements provided; comparison skipped.")

    detail_items = failures if failures else warnings if warnings else passes
    if detail_items:
        for item in detail_items[:DETAIL_LIMIT]:
            lines.append(f"  - {item}")
        if len(detail_items) > DETAIL_LIMIT:
            lines.append(f"  - ... plus {len(detail_items) - DETAIL_LIMIT} more")

    if baseline_notes:
        lines.extend([f"  - {note}" for note in baseline_notes])
    if measurement_notes and measurements:
        lines.extend([f"  - {note}" for note in measurement_notes])

    blocker = bool(failures)
    return lines, blocker


def load_portability_results(path: Path) -> Tuple[List[dict], List[str]]:
    data, notes = safe_load_json(path)
    if not isinstance(data, list):
        if data:
            notes.append("Portability results file is not a list; skipping.")
        return [], notes
    cleaned = []
    for entry in data:
        architecture = str(entry.get("architecture", "")).strip()
        status = str(entry.get("status", "")).strip().lower()
        notes_entry = str(entry.get("notes", "")).strip()
        if not architecture or not status:
            notes.append(f"Incomplete portability entry {entry}; entry skipped.")
            continue
        cleaned.append({"architecture": architecture, "status": status, "notes": notes_entry})
    return cleaned, notes


def summarize_portability(results_path: Path) -> Tuple[List[str], bool]:
    results, notes = load_portability_results(results_path)
    lines: List[str] = []
    blocker = False

    if not results:
        rel = results_path.relative_to(ROOT) if results_path.is_absolute() else results_path
        lines.append(f"- Portability: no results provided (expected at {rel}); ensure x64/x86 runs or record waiver.")
        if notes:
            lines.extend([f"  - {note}" for note in notes])
        return lines, blocker

    failures = [r for r in results if r["status"] == "fail"]
    skipped = [r for r in results if r["status"] == "skipped"]
    arches = ", ".join(sorted({r["architecture"] for r in results}))
    status = "FAIL" if failures else "WARN" if skipped else "PASS"
    lines.append(f"- Portability: {status} (architectures: {arches})")

    detail_items: List[str] = []
    for entry in failures[:DETAIL_LIMIT]:
        note = f" - {entry['notes']}" if entry["notes"] else ""
        detail_items.append(f"{entry['architecture']} failed{note}")
    for entry in skipped[: max(0, DETAIL_LIMIT - len(detail_items))]:
        note = f" - {entry['notes']}" if entry["notes"] else ""
        detail_items.append(f"{entry['architecture']} skipped{note}")

    if detail_items:
        lines.extend([f"  - {item}" for item in detail_items])
    if notes:
        lines.extend([f"  - {note}" for note in notes])

    blocker = bool(failures)
    return lines, blocker


def format_pct(cov: Coverage) -> str:
    return f"{cov.covered}/{cov.total} = {cov.pct():.0%}"


def relpath(path: Path) -> Path:
    try:
        return path.relative_to(ROOT)
    except Exception:
        return path


def incident_urls_from_env() -> List[str]:
    raw = os.getenv(INCIDENT_ENV_VAR, "").strip()
    if not raw:
        return []
    parts = [p.strip() for p in raw.replace("\n", ",").split(",")]
    return [p for p in parts if p]


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ref_desc() -> str:
    head = os.getenv("GITHUB_HEAD_REF", "").strip()
    base = os.getenv("GITHUB_BASE_REF", "").strip()
    ref = os.getenv("GITHUB_REF", "").replace("refs/heads/", "")
    if head and base:
        return f"{head} -> {base}"
    if head:
        return head
    return ref or "LOCAL"


def build_run_url(repo: str, run_id: str) -> str:
    base = os.getenv("GITHUB_SERVER_URL", "https://github.com")
    if repo and run_id:
        return f"{base}/{repo}/actions/runs/{run_id}"
    return ""


def build_meta(args: argparse.Namespace) -> dict:
    run_id = args.run_id or os.getenv("GITHUB_RUN_ID", "local")
    repo = os.getenv("GITHUB_REPOSITORY", "")
    sha = os.getenv("GITHUB_SHA", "")[:7]
    event = os.getenv("GITHUB_EVENT_NAME", "local")
    tag = args.tag or os.getenv("TAG_NAME", "")
    upstream_run_id = os.getenv("UPSTREAM_RUN_ID", "").strip()
    upstream_run_url = os.getenv("UPSTREAM_RUN_URL", "").strip()

    return {
        "run_id": run_id,
        "repo": repo,
        "sha": sha,
        "event": event,
        "tag": tag,
        "ref": ref_desc(),
        "run_url": build_run_url(repo, run_id),
        "upstream_run_id": upstream_run_id,
        "upstream_run_url": upstream_run_url,
    }


def build_structured_results(
    meta: dict, rows: List[dict], high: Coverage, total: Coverage, missing: List[str], mode: str, run_label: str
) -> Path:
    """Emit structured results JSON (expected vs actual)."""
    results_path = REPORTS_DIR / f"test-results-{run_label}.json"
    results_path.parent.mkdir(parents=True, exist_ok=True)
    results: List[dict] = []
    blocked = 0
    for row in rows:
        has_test, resolved_path = resolve_test_path(row["test_path"])
        status = "unknown"
        note = "Execution data not supplied; structural mapping only."
        if not row["test_path"].strip():
            status = "blocked"
            note = "Test path missing."
        elif not has_test:
            status = "blocked"
            rel = relpath(resolved_path) if resolved_path else row["test_path"]
            note = f"Test path not found: {rel}"
        if status == "blocked":
            blocked += 1
        results.append(
            {
                "requirement_id": row["id"],
                "title": row["title"],
                "priority": row["priority"],
                "test_path": row["test_path"],
                "procedure_path": row.get("procedure_path", ""),
                "model_id": row.get("model_id", ""),
                "expected": "execute mapped test",
                "actual": status,
                "note": note,
            }
        )

    payload = {
        "schema": RESULTS_SCHEMA,
        "generated_at": utc_now(),
        "mode": mode,
        "run_id": run_label,
        "meta": meta,
        "summary": {
            "completion": "PASS" if high.pct() >= MIN_HIGH and total.pct() >= MIN_TOTAL else "FAIL",
            "coverage": {
                "high_critical": {"covered": high.covered, "total": high.total, "pct": high.pct()},
                "overall": {"covered": total.covered, "total": total.total, "pct": total.pct()},
            },
            "blocked_cases": blocked,
            "total_cases": len(results),
            "rtm_missing": missing,
        },
        "results": results,
    }
    results_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return results_path


def summarize_missing(missing: List[str]) -> Tuple[List[str], int]:
    if len(missing) <= 15:
        return missing, 0
    return missing[:15], len(missing) - 15


def build_status_report(
    meta: dict,
    high: Coverage,
    total: Coverage,
    suites: List[str],
    missing: List[str],
    results_path: Path,
    incidents: List[str],
) -> Tuple[Path, List[str]]:
    path = REPORTS_DIR / f"test-status-{meta['run_id']}.md"
    completion = "PASS" if high.pct() >= MIN_HIGH and total.pct() >= MIN_TOTAL else "FAIL"
    missing_sample, extra_missing = summarize_missing(missing)

    lines: List[str] = []
    lines.append("# Test Status Report (ISO/IEC/IEEE 29119-3 §8)")
    lines.append("")
    lines.append("## §8.1 Context and Scope")
    run_label = f"{meta['repo']}#{meta['run_id']}" if meta["repo"] else f"run {meta['run_id']}"
    if meta["run_url"]:
        lines.append(f"- Run: [{run_label}]({meta['run_url']})")
    else:
        lines.append(f"- Run: {run_label}")
    lines.append(f"- Event/Ref: {meta['event']} ({meta['ref']})")
    lines.append(f"- Commit: {meta['sha'] or 'n/a'}")
    lines.append(f"- Timestamp (UTC): {utc_now()}")
    lines.append(f"- Template: docs/testing/templates/test-report-template.md")
    lines.append("")

    lines.append("## §8.2 Progress vs Plan")
    lines.append(
        f"- Completion: **{completion}** "
        f"(High/Critical {format_pct(high)}; Overall {format_pct(total)}; "
        f"thresholds >= {MIN_HIGH:.0%} / {MIN_TOTAL:.0%})"
    )
    if suites:
        lines.append(f"- Suites referenced: {', '.join(suites)}")
    lines.append("- Plan reference: docs/testing/test-plan.md (§7.2 context/risk/schedule)")
    lines.append("- Coverage source: docs/requirements/rtm.csv (priorities drive thresholds)")
    lines.append("")

    lines.append("## §8.3 Measures")
    lines.append("- Performance: not measured in status runs; see completion reports for comparisons.")
    lines.append("- Portability: status run references RTM suites; execution outcomes recorded in structured results.")
    lines.append("")

    lines.append("## §8.4 Issues and Risks")
    if missing_sample:
        lines.append("- RTM gaps:")
        lines.extend([f"  - {item}" for item in missing_sample])
        if extra_missing:
            lines.append(f"  - ... plus {extra_missing} more")
    else:
        lines.append("- RTM gaps: none detected")
    if incidents:
        lines.append("- Test incidents:")
        for url in incidents:
            lines.append(f"  - {url}")
    else:
        lines.append("- Test incidents: none recorded for this run.")
    lines.append("")

    lines.append("## §8.5 Residual Risks and Mitigations")
    lines.append("- Risk signal: RTM `priority` plus any open TRW checklist actions.")
    lines.append("- Mitigation: close RTM gaps or record ADR-backed waiver before merge.")
    lines.append("")

    lines.append("## §8.6 Deliverables and Reuse")
    lines.append("- Evidence: test-plan, RTM, TRW checklist, structured results, execution log, readiness reports.")
    lines.append("- Structured results: " + str(relpath(results_path)))
    lines.append("- Reuse: existing LabVIEW unit suites per RTM; incidents feed follow-up regression tests.")
    lines.append("- Next action: fix blockers or proceed to merge if all gates are green.")

    return path, lines


def build_completion_report(
    meta: dict,
    high: Coverage,
    total: Coverage,
    suites: List[str],
    missing: List[str],
    performance: List[str] | None = None,
    portability: List[str] | None = None,
    results_path: Path | None = None,
    incidents: List[str] | None = None,
) -> Tuple[Path, List[str]]:
    path = REPORTS_DIR / f"test-completion-{meta['tag']}.md"
    completion = "PASS" if high.pct() >= MIN_HIGH and total.pct() >= MIN_TOTAL else "FAIL"
    missing_sample, extra_missing = summarize_missing(missing)
    performance = performance or []
    portability = portability or []

    lines: List[str] = []
    lines.append("# Test Completion Report (ISO/IEC/IEEE 29119-3 §8)")
    lines.append("")
    lines.append("## §8.1 Context and Scope")
    lines.append(f"- Tag: {meta['tag']}")
    lines.append(f"- Event/Ref: {meta['event']} ({meta['ref']})")
    lines.append(f"- Commit: {meta['sha'] or 'n/a'}")
    lines.append(f"- Timestamp (UTC): {utc_now()}")
    if meta["upstream_run_id"]:
        upstream_label = f"{meta['repo']}#{meta['upstream_run_id']}"
        if meta["upstream_run_url"]:
            lines.append(f"- Upstream CI run: [{upstream_label}]({meta['upstream_run_url']})")
        else:
            lines.append(f"- Upstream CI run: {upstream_label}")
    lines.append(f"- Template: docs/testing/templates/test-report-template.md")
    lines.append("")

    lines.append("## §8.2 Progress vs Plan")
    lines.append(
        f"- Completion: **{completion}** "
        f"(High/Critical {format_pct(high)}; Overall {format_pct(total)}; "
        f"thresholds >= {MIN_HIGH:.0%} / {MIN_TOTAL:.0%})"
    )
    if suites:
        lines.append(f"- Suites referenced: {', '.join(suites)}")
    lines.append("- Plan reference: docs/testing/test-plan.md (§7.2 context/risk/schedule)")
    lines.append("- Release will be blocked if thresholds are not met or if RTM gaps remain.")
    lines.append("")

    lines.append("## §8.3 Measures")
    if performance:
        lines.extend(performance)
    else:
        lines.append("- Performance: no measurements provided.")
    if portability:
        lines.extend(portability)
    else:
        lines.append("- Portability: no portability results provided.")
    lines.append("")

    lines.append("## §8.4 Issues and Variances")
    if missing_sample:
        lines.append("- RTM gaps at tag cut:")
        lines.extend([f"  - {item}" for item in missing_sample])
        if extra_missing:
            lines.append(f"  - ... plus {extra_missing} more")
    else:
        lines.append("- RTM gaps: none detected at tag time")
    if incidents:
        lines.append("- Test incidents at tag time:")
        for url in incidents:
            lines.append(f"  - {url}")
    else:
        lines.append("- Test incidents: none recorded for this tag.")
    lines.append("")

    lines.append("## §8.5 Residual Risks and Contingencies")
    lines.append("- Risk signal: RTM `priority` and TRW checklist items carrying residual actions.")
    lines.append("- Contingency: postpone publish or cut hotfix branch if new High/Critical gaps appear.")
    lines.append("")

    lines.append("## §8.6 Evidence, Attachments, and Reuse")
    lines.append("- Test Plan: docs/testing/test-plan.md (§7.2 context/risk/schedule; §8 exit expectations)")
    lines.append("- RTM: docs/requirements/rtm.csv; TRW: docs/requirements/TRW_Verification_Checklist.md")
    lines.append("- CI gates: dod-aggregator, rtm-validate, rtm-coverage, adr-lint, docs-link-check, unit tests.")
    if results_path:
        lines.append(f"- Structured results: {relpath(results_path)}")
    lines.append("- Reuse: regression suites reused; incidents feed follow-up fixes before publish.")
    lines.append("- This report should be attached to the GitHub Release assets for traceability.")

    return path, lines


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate ISO 29119-3 aligned test status/completion reports."
    )
    parser.add_argument(
        "--mode",
        choices=["status", "completion"],
        default="status",
        help="Report mode: status for PR runs; completion for tagged releases.",
    )
    parser.add_argument(
        "--run-id",
        help="Override run id used in the filename for status reports.",
    )
    parser.add_argument(
        "--tag",
        help="Release tag (required for completion mode).",
    )
    parser.add_argument(
        "--performance-results",
        help=f"Path to performance measurements JSON (default: {DEFAULT_PERFORMANCE_RESULTS_PATH.relative_to(ROOT)})",
    )
    parser.add_argument(
        "--portability-results",
        help=f"Path to portability status JSON (default: {DEFAULT_PORTABILITY_RESULTS_PATH.relative_to(ROOT)})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.mode == "completion" and not (args.tag or os.getenv("TAG_NAME")):
        print("completion mode requires --tag or TAG_NAME", file=sys.stderr)
        return 2

    try:
        rows = load_rtm()
    except Exception as exc:  # pragma: no cover - defensive for CI logs
        print(f"Failed to load RTM: {exc}", file=sys.stderr)
        return 2

    high, total, missing = compute_coverage(rows)
    suites = detect_suites(rows)
    meta = build_meta(args)
    run_label = meta["tag"] if args.mode == "completion" else meta["run_id"]

    performance_results_path = Path(
        args.performance_results
        or os.getenv("PERFORMANCE_RESULTS_PATH", "")
        or DEFAULT_PERFORMANCE_RESULTS_PATH
    )
    portability_results_path = Path(
        args.portability_results
        or os.getenv("PORTABILITY_RESULTS_PATH", "")
        or DEFAULT_PORTABILITY_RESULTS_PATH
    )

    performance_summary: List[str] = []
    portability_summary: List[str] = []
    perf_blocker = False
    port_blocker = False

    incidents = incident_urls_from_env()

    if args.mode == "completion":
        performance_summary, perf_blocker = summarize_performance(performance_results_path)
        portability_summary, port_blocker = summarize_portability(portability_results_path)

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    results_path = build_structured_results(
        meta=meta,
        rows=rows,
        high=high,
        total=total,
        missing=missing,
        mode=args.mode,
        run_label=str(run_label),
    )

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    if args.mode == "completion":
        path, lines = build_completion_report(
            meta,
            high,
            total,
            suites,
            missing,
            performance=performance_summary,
            portability=portability_summary,
            results_path=results_path,
            incidents=incidents,
        )
    else:
        path, lines = build_status_report(meta, high, total, suites, missing, results_path, incidents)

    path.write_text("\n".join(lines))
    print(f"Wrote {path.relative_to(ROOT)}")

    exit_code = 0
    if missing:
        print("RTM gaps detected; refer to report for details.", file=sys.stderr)
        exit_code = 1
    if high.pct() < MIN_HIGH or total.pct() < MIN_TOTAL:
        print("Coverage thresholds not met; report generated but failing pipeline.", file=sys.stderr)
        exit_code = 1
    if perf_blocker:
        print("Performance regression detected beyond tolerance.", file=sys.stderr)
        exit_code = 1
    if port_blocker:
        print("Portability failures detected.", file=sys.stderr)
        exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
