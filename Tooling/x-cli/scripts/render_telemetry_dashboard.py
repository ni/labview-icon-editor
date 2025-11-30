"""Render telemetry dashboard and send alerts (FGC-REQ-TEL-001)."""

import argparse
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from notifications.manager import NotificationManager


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Render telemetry dashboard and flag regressions"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default="artifacts/telemetry-summary-history.jsonl",
        help="Path to telemetry summary history",
    )
    parser.add_argument(
        "--srs-summary",
        default="artifacts/srs-telemetry-summary.json",
        help="Path to SRS omission summary JSON",
    )
    parser.add_argument("--slack-webhook", help="Slack webhook URL for alerts")
    parser.add_argument("--discord-webhook", help="Discord webhook URL for alerts")
    parser.add_argument("--alert-email", help="Email address for alerts")
    args = parser.parse_args(argv)

    history_path = Path(args.path)
    if not history_path.is_file():
        print(f"No history file found at {history_path}", file=sys.stderr)
        return 0

    entries = [
        json.loads(line)
        for line in history_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not entries:
        print("Empty telemetry history", file=sys.stderr)
        return 0

    timestamps = [e.get("timestamp", "") for e in entries]
    slow_counts = [int(e.get("slow_test_count", 0)) for e in entries]
    dep_counts = [
        sum(int(v) for v in e.get("dependency_failures", {}).values()) for e in entries
    ]

    srs_summary_path = Path(args.srs_summary)
    srs_current: int | None = None
    srs_timestamps: list[str] = []
    srs_counts: list[int] = []
    if srs_summary_path.is_file():
        try:
            summary = json.loads(srs_summary_path.read_text(encoding="utf-8"))
            srs_current = int(summary.get("srs_omitted_count", 0))
            srs_history_path = srs_summary_path.with_name(
                srs_summary_path.stem + "-history.jsonl"
            )
            if srs_history_path.is_file():
                srs_entries = [
                    json.loads(line)
                    for line in srs_history_path.read_text(encoding="utf-8").splitlines()
                    if line.strip()
                ]
                srs_timestamps = [e.get("timestamp", "") for e in srs_entries]
                srs_counts = [int(e.get("srs_omitted_count", 0)) for e in srs_entries]
        except Exception as exc:
            print(
                f"::warning::Failed to load SRS summary from {srs_summary_path}: {exc}",
                file=sys.stderr,
            )

    srs_ids = [s.strip() for s in os.getenv("SRS_IDS", "").split(",") if s.strip()]

    dashboard_path = history_path.with_name("telemetry-dashboard.html")
    parts = [
        "<!DOCTYPE html>",
        "<html>",
        "<head>",
        "<meta charset='utf-8'/>",
        "<title>Telemetry Dashboard</title>",
        "<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>",
        "</head>",
        "<body>",
        "<h1>Telemetry Summary History</h1>",
        f"<p>SRS IDs: {', '.join(srs_ids) if srs_ids else 'none'}</p>",
    ]
    if srs_current is not None:
        parts.append(f"<p>Current SRS omissions: {srs_current}</p>")
    parts.append("<canvas id='slowTests'></canvas>")
    parts.append("<canvas id='depFailures'></canvas>")
    if srs_timestamps:
        parts.append("<canvas id='srsOmissions'></canvas>")
    parts.append("<script>")
    parts.append(f"const labels = {json.dumps(timestamps)};")
    parts.append(
        "new Chart(document.getElementById('slowTests'), {"
        "  type: 'line',"
        f"  data: {{ labels: labels, datasets: [{{ label: 'Slow Tests', data: {json.dumps(slow_counts)} }}] }},"
        "});"
    )
    parts.append(
        "new Chart(document.getElementById('depFailures'), {"
        "  type: 'line',"
        f"  data: {{ labels: labels, datasets: [{{ label: 'Dependency Failures', data: {json.dumps(dep_counts)} }}] }},"
        "});"
    )
    if srs_timestamps:
        parts.append(f"const srsLabels = {json.dumps(srs_timestamps)};")
        parts.append(
            "new Chart(document.getElementById('srsOmissions'), {"
            "  type: 'line',"
            f"  data: {{ labels: srsLabels, datasets: [{{ label: 'SRS Omissions', data: {json.dumps(srs_counts)} }}] }},"
            "});"
        )
    parts.append("</script>")
    parts.append("</body>")
    parts.append("</html>")
    dashboard_path.write_text("\n".join(parts), encoding="utf-8")

    exit_code = 0
    regressions: list[str] = []
    if len(entries) > 1:
        if slow_counts[-1] > slow_counts[-2]:
            msg = (
                f"Slow test count increased from {slow_counts[-2]} to {slow_counts[-1]}"
            )
            print(f"::warning::{msg}", file=sys.stderr)
            regressions.append(msg)
            exit_code = 1
        if dep_counts[-1] > dep_counts[-2]:
            msg = (
                "Dependency failure count increased "
                f"from {dep_counts[-2]} to {dep_counts[-1]}"
            )
            print(f"::warning::{msg}", file=sys.stderr)
            regressions.append(msg)
            exit_code = 1
    if len(srs_counts) > 1 and srs_counts[-1] > srs_counts[-2]:
        msg = (
            f"SRS omission count increased from {srs_counts[-2]} to {srs_counts[-1]}"
        )
        print(f"::warning::{msg}", file=sys.stderr)
        regressions.append(msg)
        exit_code = 1

    if exit_code == 1:
        webhook = args.slack_webhook or os.getenv("SLACK_WEBHOOK_URL")
        discord = args.discord_webhook or os.getenv("DISCORD_WEBHOOK_URL")
        email = args.alert_email or os.getenv("ALERT_EMAIL")
        if webhook:
            os.environ["SLACK_WEBHOOK_URL"] = webhook
        if discord:
            os.environ["DISCORD_WEBHOOK_URL"] = discord
        if email:
            os.environ["ALERT_EMAIL"] = email
        dashboard_url = os.getenv(
            "TELEMETRY_DASHBOARD_URL", dashboard_path.name
        )
        srs_csv = ", ".join(srs_ids) if srs_ids else "none"
        summary = (
            f"SRS IDs: {srs_csv} - Telemetry regression detected: {'; '.join(regressions)}."
        )
        metadata = {"dashboard_url": dashboard_url}
        try:
            mgr = NotificationManager.from_env()
            _ = mgr.notify_all(summary, metadata)
        except Exception as exc:  # pragma: no cover - logged but non-fatal
            print(f"Failed to send alert: {exc}", file=sys.stderr)

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

