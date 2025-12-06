# CI Notification Hooks

This index lists endpoints used by CI scripts for alerts.

- `SLACK_WEBHOOK_URL` / `--slack-webhook` — Slack webhook for telemetry regressions.
- `DISCORD_WEBHOOK_URL` / `--discord-webhook` — Discord webhook for telemetry regressions (Stage 3 requires this secret).
- `ALERT_EMAIL` / `--alert-email` — email recipient for telemetry regressions.
- `GITHUB_REPO`, `GITHUB_ISSUE`, `ADMIN_TOKEN` — GitHub notifier (posts a comment to the issue/PR). `ADMIN_TOKEN` falls back to `GITHUB_TOKEN`.

Provider behavior is controlled by `NOTIFICATIONS_DRY_RUN` (defaults to true in CI) and per‑provider overrides `ENABLE_<PROVIDER>_LIVE`.

For a connectivity check, see the canary workflow: `.github/workflows/discord-canary.yml`.

Record new hooks here to streamline future integrations.
