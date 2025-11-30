# FGC-REQ-NOT-003 — Email Alerts
Version: 1.0

## Description
The notifications system SHALL prepare email alerts for configured recipients using `notifications.email_notifier` and SMTP settings.

## Rationale
Email notifications enable asynchronous updates when real-time channels are unavailable.

## Verification
- Run `tests/test_email_notifier_send.py` to verify message construction and sending logic in dry-run mode.

