# FGC-REQ-NOT-004 - Discord Alerts
Version: 1.1

## Description
The system SHALL support sending alerts to Discord channels via webhooks using `notifications.discord_notifier`. Stage 3 of this repository defaults to dry‑run and SHALL NOT require a webhook to pass; it SHALL produce history and diagnostics enabling downstream orchestration to post alerts. When explicitly enabled via CI variables and secrets, posting MAY be performed within Stage 3.

## Rationale
Discord notifications broaden communication coverage across community channels.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. A Discord notifier SHALL be available for use by CI/orchestrators via `notifications.discord_notifier`.
- RQ2. Stage 3 in this repository SHALL default to dry‑run (no Discord post).
- RQ3. Stage 3 SHALL succeed without a webhook, emitting artifacts and diagnostics for downstream posting.
- RQ4. When explicitly enabled (e.g., `DISCORD_PUBLISH == '1'` and `DISCORD_WEBHOOK_URL` is present), the pipeline MAY post a summary to Discord.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-NOT-004.md
