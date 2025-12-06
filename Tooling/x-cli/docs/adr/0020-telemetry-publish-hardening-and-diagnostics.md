# ADR 0020: Telemetry Publish Hardening and Diagnostics
- Status: Accepted
- Date: 2025-09-26

## Context
Stage 3 (Windows) occasionally failed when posting telemetry due to brittle string formatting (`-f`), brace/colon parsing, and large message size. Diagnostics were limited, making failures harder to triage.

## Decision
- Refactor `scripts/telemetry-publish.ps1` to remove `-f` formatting in favor of interpolation with `${var}` where needed.
- Add robust error handling and dry‑run fallback when the Discord secret is missing or posting fails.
- Support chunking for 2000‑char Discord limits and optional attachment posting.
- Emit diagnostics: chunk metadata JSON, optional PR comment markdown, and job summary content in Stage 3.

## Consequences
- Stage 3 publishes reliably, or falls back to dry‑run while saving history and diagnostics.
- CI operators can inspect job summary and history artifacts without digging into raw logs.
- Unit tests cover dry‑run, baseline/diff, error handling, and comment output.

## Verification
- Pester tests under `scripts/tests/TelemetryPublish.Tests.ps1`.
- Stage 3 job includes a summary step that consumes `summary-latest.json`, `diff-latest.json`, and `chunk-diagnostics-latest.json`.
