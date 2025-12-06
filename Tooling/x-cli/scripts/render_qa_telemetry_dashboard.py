"""Render QA telemetry dashboard and send alerts (FGC-REQ-TEL-001)."""

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
        description="Render QA telemetry dashboard and flag recurring failures"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default="artifacts/qa-telemetry-summary-history.jsonl",
        help="Path to QA telemetry summary history",
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
    avg_durations = [
        (
            sum(step.get("avg_duration_ms", 0) for step in e.get("step_averages", []))
            / max(len(e.get("step_averages", [])), 1)
        )
        for e in entries
    ]
    fail_counts = [sum(e.get("failure_counts", {}).values()) for e in entries]

    dashboard_path = history_path.with_name("qa-telemetry-dashboard.html")
    html = f"""
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'/>
<title>QA Telemetry Dashboard</title>
<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
</head>
<body>
<h1>QA Telemetry Summary History</h1>
<canvas id='durations'></canvas>
<canvas id='failures'></canvas>
<script>
const labels = {json.dumps(timestamps)};
new Chart(document.getElementById('durations'), {{
  type: 'line',
  data: {{ labels: labels, datasets: [{{ label: 'Avg Step Duration (ms)', data: {json.dumps(avg_durations)} }}] }},
}});
new Chart(document.getElementById('failures'), {{
  type: 'line',
  data: {{ labels: labels, datasets: [{{ label: 'Total Step Failures', data: {json.dumps(fail_counts)} }}] }},
}});
</script>
</body>
</html>
"""
    dashboard_path.write_text(html, encoding="utf-8")

    exit_code = 0
    warnings = []
    if len(entries) > 1:
        last = entries[-1].get("failure_counts", {})
        prev = entries[-2].get("failure_counts", {})
        recurring = [s for s, c in last.items() if c > 0 and prev.get(s, 0) > 0]
        if recurring:
            msg = "Recurring failures: " + ", ".join(
                f"{s} ({prev.get(s,0)}→{last[s]})" for s in recurring
            )
            print(f"::warning::{msg}", file=sys.stderr)
            warnings.append(msg)
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
            "QA_TELEMETRY_DASHBOARD_URL", dashboard_path.name
        )
        summary = (
            f"QA telemetry regression detected: {'; '.join(warnings)}."
        )
        srs_ids = [s.strip() for s in os.getenv("SRS_IDS", "").split(",") if s.strip()]
        metadata = {"dashboard_url": dashboard_url, "srs_ids": srs_ids}
        try:
            mgr = NotificationManager.from_env()
            _ = mgr.notify_all(summary, metadata)
        except Exception as exc:  # pragma: no cover
            print(f"Failed to send alert: {exc}", file=sys.stderr)

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
