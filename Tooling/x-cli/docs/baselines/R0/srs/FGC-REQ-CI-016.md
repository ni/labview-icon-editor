# FGC-REQ-CI-016 — Discord canary
Version: 1.0

## Description
Verify connectivity to the project's Discord notification channel.
- `.github/workflows/discord-canary.yml` posts a canary message to the configured Discord webhook.
- The workflow fails if the message cannot be delivered.

## Rationale
Regular canary checks alert maintainers to broken notification channels.

## Verification
- Run `.github/workflows/discord-canary.yml` and confirm a message appears in the Discord channel.
