# SRS Changelog

## Unreleased
- Harmonized requirement phrasing by replacing non-normative terms with "shall" across the SRS baseline for clearer, testable requirements.
 - Pipeline simplification: archived legacy orchestration workflows and related docs. See `docs/workflows-inventory.md` and issue #728.
 - Legacy references: any links to removed documents now point to `docs/archive/`. If you find a stale link, update it to the archive or the live equivalent.
 - Schemas: Introduced `ghops.logs/v1` (+ aggregate/summary v1) under `docs/schemas/v1/`. When schema versions change, include a short note here and update CI validation accordingly.

## R2 (Planned)
- Add a short “Legacy References” note in release notes summarizing archived items and their new locations under `docs/archive/`.
- Ensure SRS Workflow Requirement Mapping and `docs/traceability.yaml` reflect only kept workflows.

