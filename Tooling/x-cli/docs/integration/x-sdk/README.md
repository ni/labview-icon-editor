# x-sdk Orchestration (Example)

This example shows how an external SDK repository (e.g., `LabVIEW-Community-CI-CD/x-sdk`) can orchestrate x-cli's Stage 1/2/3 workflows as reusable workflows and consume their outputs.

What Stage 2 exposes as outputs:
- `run_id` - the GitHub Actions run id for Stage 2
- `manifest_path` - expected `telemetry/manifest.json` path
- `summary_path` - expected `telemetry/summary.json` path

Usage
- Stage 2 only: copy `orchestrate-x-cli.yml` to your SDK's `.github/workflows/` and trigger via workflow_dispatch.
- Full chain (Stage123): copy `orchestrate-x-cli-full.yml` to run the end-to-end flow driven by the SDK.
Both samples write a Job Summary and upload `orchestration.json` for downstream tooling.

Notes
- Pin the ref (`@main`/`@develop`/`@<sha>`) to your desired stability level.
- Ensure the SDK repo has `actions: read` permissions to call reusable workflows and `contents: read` at minimum.
- Stage 3 requires `DISCORD_WEBHOOK_URL`; pass via `secrets: inherit` or map explicitly in the calling job.
- Stage 3 outputs to callers: `summary_path` and `published` ("true" when a Discord post succeeded; otherwise "false" in dry-run or on publish failure).
- Stage 3 also exposes `diagnostics_path` (points to `telemetry/stage3-diagnostics.json`).

GK-CLI (required for local SDK workflows)
- x-sdk leverages GitKraken GK-CLI v3.1.37 for multi-repo work items and AI-assisted commit/PR flows.
- Install guidance and examples live in `docs/integration/x-sdk/GK-CLI.md`.

Advanced
- Force dry-run in Stage 3 (deterministic, no Discord post):
  uses: LabVIEW-Community-CI-CD/x-cli/.github/workflows/stage3.yml@develop
  with:
    stage2_repo: LabVIEW-Community-CI-CD/x-cli
    stage2_run_id: ${{ needs.stage2.outputs.run_id }}
    force_dry_run: true
  secrets: inherit

- Diagnostics: Stage 3 uploads `stage3-diagnostics` artifact containing `telemetry/stage3-diagnostics.json` with fields: `published`, `dry_run_forced`, `webhook_present`, `summary_bytes`, `comment_bytes`, and chunk diagnostics when available.
  - Schema: see `docs/schemas/stage3-diagnostics.schema.json` for a portable JSON Schema you can use to validate on any runner (e.g., `python -m jsonschema -i telemetry/stage3-diagnostics.json docs/schemas/stage3-diagnostics.schema.json`).

- Enforce schema validation in Stage 3 (behind a flag):
  uses: LabVIEW-Community-CI-CD/x-cli/.github/workflows/stage3.yml@develop
  with:
    stage2_repo: LabVIEW-Community-CI-CD/x-cli
    stage2_run_id: ${{ needs.stage2.outputs.run_id }}
    validate_schema: true
  secrets: inherit
  # This installs Python 3.12 and validates `stage3-diagnostics.json` against the schema.
