# FGC-REQ-NOT-004 — Discord Alerts
Version: 1.0

## Description
The notifications system SHALL send alerts to Discord channels via webhooks using `notifications.discord_notifier`.

## Rationale
Discord notifications broaden communication coverage across community channels.

## Verification
- Invoke `DiscordNotifier` with `NOTIFICATIONS_DRY_RUN=1` and ensure `tests/test_discord_notifier.py` verifies the payload.

