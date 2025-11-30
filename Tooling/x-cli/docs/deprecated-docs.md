# Deprecated Documents & Rationale

This page inventories repository documents that no longer match the current, minimal x-cli pipeline after removing legacy orchestration workflows. They remain in history for context but are not valid guidance for the live system.

Status key: Remove = safe to delete or archive; Revise = keep but update to x-cli scope; Legacy = keep for historical baselines only.

## Top-level apply guides (Remove)
- `APPLY_LEGACY_VALIDATOR_GATE.md`, `APPLY_LEGACY_VALIDATOR_SUMMARY.md`, `APPLY_LEGACY_VALIDATOR_SCHEMA_SYNC.md`
  - Why: Depend on legacy validator workflows removed from CI. Instructions no longer runnable.
- `WATERFALL.md`
  - Why: Waterfall orchestration/alerts were removed (validate-waterfall-state / waterfall-advance / waterfall-stuck-alert). This stub points to a process we no longer automate.

## ADRs (Revise / Remove)
- `docs/adr/0002-codex-verified-human-mirror.md` (Remove)
  - Why: Relies on `codex-mirror-sign.yml` which was removed. Policy no longer enforced.
- `docs/adr/0004-codex-environment-expectations.md` (Revise)
  - Why: Codex container assumptions may still be useful but need framing for x-cli; remove Codex-specific gates and ensure tools matrix reflects current CI images.
- `docs/adr/0016-ci-gates-scope-and-labels.md` (Revise)
  - Why: Mentions legacy validator–scoped gates we removed. Update scope/labels to the minimal pipeline.

## SRS & Baselines (Revise / Legacy)
- `docs/SRS.md` (Revise)
  - Why: Workflow mapping lists Codex workflows (codex-execute/orchestrator/mirror-sign/enforce-authorship). Replace with the current kept workflows and remove defunct references.
- `docs/baselines/R*/srs/FGC-REQ-CI-0**.md` where lines cite legacy validator workflows (Legacy)
  - Why: Baseline histories may mention removed jobs. Keep for historical record; annotate as legacy in next baseline release notes.

## Traceability & Telemetry (Revise)
- `docs/traceability.yaml`
  - Why: References removed workflow files (e.g., `.github/workflows/codex-*.yml`, `enforce-codex-authorship.yml`, `trigger-codex-orchestration.yml`). Update entries to reflect the kept pipeline or drop those mappings.
- `docs/telemetry.md`
  - Why: Sections about Codex telemetry (agent feedback blocks, codex-specific signals) should be reframed for x-cli or split into a separate doc about contributor telemetry.

## Tools & Tests (Revise / Remove)
- `tools/legacy_validator_json_summary.py` (Remove or move to archive)
  - Why: Consumed by legacy validator gate; no longer used.
- Python tests referring to removed workflows (e.g., `tests/test_ci_workflows.py` Codex/Waterfall cases) (Revise)
  - Why: Intentional CI break; update tests once the lean pipeline is settled.

## Next Steps
- Remove the documents marked Remove (or move to `docs/archive/`), and add a short note in release notes.
- Update the “Revise” items in the next PR: 
  - refresh `docs/SRS.md` workflow maps, `docs/traceability.yaml`, and CI docs;
  - refactor ADRs to reflect x-cli-only workflows;
  - pare down telemetry docs to the pieces we still produce.
