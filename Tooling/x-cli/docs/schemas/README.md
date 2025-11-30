# Schemas — Index

This index lists versioned JSON schemas used by CI helpers, with their producing jobs and typical consumers.

- ghops logs (`ghops.logs/v1`)
  - Path: `docs/schemas/v1/ghops.logs.v1.schema.json`
  - Producer: `.github/workflows/ghops-smoke.yml` (unified `ghops-logs-all/all-logs.json`)
  - Validation: PowerShell `Test-Json` + Ajv (non‑blocking)
  - Consumers: CI summaries, optional PR comments, dashboards

- RTM verify (`rtm.verify/v1`)
  - Path: `docs/schemas/v1/rtm.verify.v1.schema.json`
  - Producer: `tools/rtm-verify-ts` via `.github/workflows/srs-gate.yml`
  - Validation: PowerShell `Test-Json` + Ajv (non‑blocking)
  - Consumers: Job Summary, artifact `telemetry/rtm/rtm-summary.json`, optional PR comments

- Stage 3 diagnostics
  - Paths: see `docs/schemas/v1/` (`stage3-diagnostics.schema.json`) and related
  - Producer: `.github/workflows/stage3.yml`
  - Validation: PowerShell `Test-Json`
  - Consumers: Job Summary, history artifacts

Notes
- Keep schemas stable within a major version. Introduce new versions under `v2/` when breaking.
- Prefer Ajv validation when Node is already in use; keep PowerShell `Test-Json` for parity across shells.

- Telemetry (QA)
  - Events (`telemetry.events/v1`)
    - Path: `docs/schemas/v1/telemetry.events.v1.schema.json`
    - Producer: QA pipeline (`scripts/qa.ps1` Run-Step) via C# `telemetry write`
    - Validation: `x-cli telemetry validate --events --schema`
  - Summary (`telemetry.summary/v1`)
    - Path: `docs/schemas/v1/telemetry.summary.v1.schema.json`
    - Producer: `x-cli telemetry summarize` (C#)
    - Validation: `x-cli telemetry validate --summary --schema`
