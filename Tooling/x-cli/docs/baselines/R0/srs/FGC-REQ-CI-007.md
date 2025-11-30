# FGC-REQ-CI-007 — Dispatch codex
Version: 1.0

## Description
Allow external systems to trigger codex runs via repository dispatch.
- `.github/workflows/dispatch-codex.yml` listens for `repository_dispatch` events.
- The workflow forwards the request to `codex-execute.yml` with the provided payload.

## Rationale
External dispatch enables integration with other automation systems.

## Verification
- Send a `repository_dispatch` event and confirm `.github/workflows/dispatch-codex.yml` triggers a codex execution run.
