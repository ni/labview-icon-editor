# Notifications Plugin System

## Plugin System Overview

The notification system centers on two concepts:

- **`NotificationChannel` interface** – a lightweight protocol defining
  a single `send_alert(message, metadata)` method. Individual providers
  (e.g. Slack, email) implement this interface.
- **`NotificationManager`** – accepts a list of providers and offers a
  `notify_all` helper that dispatches providers concurrently, capturing
  success or failure per provider.

`NotificationManager.from_env()` discovers providers using environment
variables in a fixed precedence order. The table below lists the inputs
and retry strategy for each provider:

| Provider | Discovery variables | Retries |
| --- | --- | --- |
| Slack | `SLACK_WEBHOOK_URL` | 1 |
| Discord | `DISCORD_WEBHOOK_URL` | 1 |
| Email | `ALERT_EMAIL` | 0 |
| GitHub | `GITHUB_REPO`, `GITHUB_ISSUE`, and `ADMIN_TOKEN` (falls back to `GITHUB_TOKEN`) | 1 |

Providers are appended in the order shown, so when multiple variables are
set the manager yields `[Slack, Discord, Email, GitHub]`. Calling
`notify_all` returns a mapping of provider names to booleans (e.g.,
`{"slack": True, "email": False}`) to surface partial failures.

## Lifecycle

1. **Interface defined** (`notifications/channel.py`).
2. **Manager skeleton added** (`notifications/manager.py`).
3. **Provider discovery** populates the manager from environment
   variables.
4. **Specific providers** (e.g. Slack) plug into the interface.

## Status

Slack, email, GitHub, and Discord providers are implemented with
automatic discovery. Slack, Discord, and GitHub notifications perform a
single retry on failure, and all providers honor a global dry-run flag
for network-free simulation. Setting `ENABLE_<PROVIDER>_LIVE=true`
allows individual providers to bypass the dry run. When `metadata`
includes `dashboard_url`, providers append `Dashboard: <url>`
automatically. CI runs `scripts/validate_notifications.sh` and archives
its JSONL output to detect regressions. The Stage 3 workflow requires a
`DISCORD_WEBHOOK_URL` secret; a preflight step fails the job when it's
missing. Messages are only sent when `NOTIFICATIONS_DRY_RUN=false` or
when `ENABLE_DISCORD_LIVE=true` overrides the dry run. Payloads remain
plain text and no schema validation occurs. For offline CI or local
testing, set dummy values for `SLACK_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`,
`ALERT_EMAIL`, `GITHUB_REPO`, `GITHUB_ISSUE`, and `ADMIN_TOKEN` so
provider discovery can proceed without contacting external services.

## Using NotificationManager

```python
from notifications.manager import NotificationManager

mgr = NotificationManager.from_env()
results = mgr.notify_all("build complete")
print(results)
```

The printed dictionary reports success per provider.

Configure Slack by setting the webhook URL:

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
```

Slack is auto-enabled when `SLACK_WEBHOOK_URL` is set.

## Dry-Run Mode

| Variable | Default | Purpose |
| --- | --- | --- |
| `NOTIFICATIONS_DRY_RUN` | `false` (CI: `true`) | Force all providers to skip network calls |
| `ENABLE_SLACK_LIVE` | `false` | Allow Slack notifier to send real messages when dry-run is set |
| `ENABLE_DISCORD_LIVE` | `false` | Allow Discord notifier to send real messages when dry-run is set |
| `ENABLE_EMAIL_LIVE` | `false` | Allow Email notifier to send real messages when dry-run is set |
| `ENABLE_GITHUB_LIVE` | `false` | Allow GitHub notifier to send real messages when dry-run is set |

Set `NOTIFICATIONS_DRY_RUN=true` to force all notification providers into a
simulation mode. In this mode each notifier still constructs its payload and
stores it internally (e.g., `_last_payload` or `_last_mime`) but skips any
network activity. The constructed payload is printed to stdout prefixed with
`DRYRUN <Provider>:` followed by JSON (or MIME text for email). The flag is
useful for tests and CI environments. CI sets `NOTIFICATIONS_DRY_RUN=true` by
default and leaves all `ENABLE_<PROVIDER>_LIVE` variables unset so no messages
are sent unless a provider's flag explicitly overrides the dry run.

`scripts/qa.sh` runs `scripts/validate_notifications.sh` with this dry-run default. The validation script selectively clears `NOTIFICATIONS_DRY_RUN` for checks that need to exercise real send paths (e.g., retry or error handling), ensuring all milestones pass out of the box. To perform live network calls during QA, set `ENABLE_<PROVIDER>_LIVE=true` alongside the necessary provider credentials.

## Slack Provider

### Configuration

Set `SLACK_WEBHOOK_URL` in the environment with a Slack incoming webhook URL.
Slack notifications are discovered automatically. Posts are sent whenever
`NOTIFICATIONS_DRY_RUN` is false; set `ENABLE_SLACK_LIVE=true` to allow
posts even when the global dry-run flag is enabled.

### Behavior

- Sends a JSON payload with a single `text` field containing the message.
- If `metadata` includes `dashboard_url`, appends a blank line followed by
  `Dashboard: <url>` so callers do not need to embed the link in `message`.
- Issues a POST request with a five-second timeout.
- If the first attempt fails, waits one second and retries once using
  the same payload.
- Does not validate the payload schema.
- Honors `NOTIFICATIONS_DRY_RUN`; `ENABLE_SLACK_LIVE` overrides the dry-run.
- On final failure, logs a concise error to stderr.

## Discord Provider

### Configuration

Set `DISCORD_WEBHOOK_URL` in the environment with a Discord webhook URL or
pass `--discord-webhook` to telemetry dashboard scripts. The scripts set
`DISCORD_WEBHOOK_URL` before constructing `NotificationManager` so the
provider is discovered automatically. In CI, the value is supplied via the
`DISCORD_WEBHOOK_URL` GitHub secret. Real posts occur when
`NOTIFICATIONS_DRY_RUN=false` or when `ENABLE_DISCORD_LIVE=true` overrides
the dry run; otherwise the notifier simulates the call and exits
successfully.

### Quick Start

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
cat <<'EOF' > history.jsonl
{"timestamp":"2024-01-01T00:00:00Z","slow_test_count":0,"dependency_failures":{}}
{"timestamp":"2024-01-02T00:00:00Z","slow_test_count":1,"dependency_failures":{}}
EOF
python scripts/render_telemetry_dashboard.py history.jsonl
```

The second entry forces a regression and the script emits an alert. It
exits with code `1` and writes `telemetry-dashboard.html`; the notifier
appends `Dashboard: <link>` automatically. Set
`NOTIFICATIONS_DRY_RUN=true` to log the payload without contacting
Discord.

For a CI connectivity check, run the canary workflow
`.github/workflows/discord-canary.yml` with a custom message.

### Behavior

- Sends a JSON payload with a single `content` field containing the message.
- If `metadata` includes `dashboard_url`, appends a blank line followed by
  `Dashboard: <url>`.
- Issues a POST request with a five-second timeout and retries once after a
  one-second delay.
- Honors `NOTIFICATIONS_DRY_RUN` to skip the network call.
- On final failure, logs a concise error to stderr.
  HTTP responses include the status code and body for easier debugging.

## Email Provider

### Configuration

Email alerts are enabled when `ALERT_EMAIL` contains a comma-separated
list of recipients. Configuration is driven by environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ALERT_EMAIL` | *(none)* | Comma-separated recipients enabling email alerts |
| `ENABLE_EMAIL_LIVE` | `false` | Allow email notifier to send real mail |
| `EMAIL_FROM` | `ci@x-cli.local` | Sender address |
| `SMTP_HOST` | `127.0.0.1` | SMTP server host |
| `SMTP_PORT` | `25` | SMTP server port |
| `SMTP_STARTTLS` | `false` | Upgrade connection via STARTTLS |
| `SMTP_SSL` | `false` | Connect with SMTPS (mutually exclusive with STARTTLS) |
| `SMTP_USERNAME` | *(none)* | Username for SMTP auth |
| `SMTP_PASSWORD` | *(none)* | Password for SMTP auth |
| `SMTP_TIMEOUT_SEC` | `5` | Network timeout in seconds |

### Behavior

By default, emails are composed but not sent when `NOTIFICATIONS_DRY_RUN`
is enabled. Set `ENABLE_EMAIL_LIVE=true` to allow delivery while dry-run
is active, or ensure `NOTIFICATIONS_DRY_RUN=false`.

- `SMTP_SSL=true` – use SMTPS over SSL.
- `SMTP_STARTTLS=true` – connect then upgrade via STARTTLS.
- neither flag – plain SMTP without TLS.
- Does not retry failed deliveries; network errors return `False` immediately.

Credentials are optional; when provided via `SMTP_USERNAME` and
`SMTP_PASSWORD`, the client will authenticate. `SMTP_TIMEOUT_SEC`
defaulting to five seconds keeps network operations bounded for CI.

In CI, notification validations simulate email delivery and do not send
real messages unless `ENABLE_EMAIL_LIVE=true` is set. The global flag
forces simulation until overridden.

If `metadata` includes `dashboard_url`, the notifier appends a blank line and
`Dashboard: <url>` to the email body, similar to other providers.

Example real send configuration:

```bash
export NOTIFICATIONS_DRY_RUN=false
export ENABLE_EMAIL_LIVE=true  # omit if dry-run is disabled
export ALERT_EMAIL="ops@example.com"
export SMTP_HOST="smtp.example.com"
export SMTP_STARTTLS=true
export SMTP_USERNAME="bot"
export SMTP_PASSWORD="s3cret"
export EMAIL_FROM="ci@example.com"
```

### Troubleshooting Email

- **Conflicting TLS flags**: Setting both `SMTP_SSL` and `SMTP_STARTTLS` to `true`
  is treated as a misconfiguration and the notifier skips sending.
- **Timeouts**: Exceeding `SMTP_TIMEOUT_SEC` results in a `False` return without
  raising an exception.
- **Authentication errors**: Invalid `SMTP_USERNAME` / `SMTP_PASSWORD` values
  trigger an auth failure that is caught and reported as `False`.

## GitHub Provider

### Configuration

GitHub notifications post comments to an existing issue or pull request. The
provider activates when the following environment variables are set:

| Variable | Purpose |
| --- | --- |
| `GITHUB_REPO` | Repository in `owner/name` format |
| `GITHUB_ISSUE` | Issue or pull request number |
| `ADMIN_TOKEN` | Personal access token used for authentication (falls back to `GITHUB_TOKEN`) |
| `ENABLE_GITHUB_LIVE` | Allow GitHub notifier to send real messages when dry-run is set |

### Behavior

When enabled, `NotificationManager.from_env()` includes a GitHub provider that
sends a simple text comment to the configured issue. If the POST request fails
or returns a non-201 status, the notifier waits one second and retries once.
If `metadata` supplies `dashboard_url`, the notifier appends a blank line and
`Dashboard: <url>` to the comment before posting. The provider honours
`NOTIFICATIONS_DRY_RUN`; `ENABLE_GITHUB_LIVE` overrides the dry-run. On
final failure, it prints a concise error to stderr. Missing configuration
is detected and logged once, and a valid token is required for the API
request.
