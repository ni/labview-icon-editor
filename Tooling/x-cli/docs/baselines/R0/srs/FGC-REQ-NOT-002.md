# FGC-REQ-NOT-002 — Slack Alerts
Version: 1.0

## Description
The notifications system SHALL send alerts to Slack channels via incoming webhooks using `notifications.slack_notifier`.

## Rationale
Slack notifications provide real-time visibility into automation results for the team.

## Verification
- Invoke `SlackNotifier` with `NOTIFICATIONS_DRY_RUN=1` and ensure `tests/test_slack_notifier.py` validates the payload.

