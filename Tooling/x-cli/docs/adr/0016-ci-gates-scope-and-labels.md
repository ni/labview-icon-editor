# ADR 0016: CI Gates Scope and Label Strategy

- Status: Proposed
- Date: 2025-09-24
- Deciders: x-cli maintainers
- Tags: ci, governance, process

## Context
Numerous PR checks were failing noisily (PR #725) due to gates running out of
scope or relying on legacy dependencies. This obscures real regressions and
slows iteration. We’ve simplified the pipeline to keep only representative
quality gates.

Related ADRs:
- ADR 0006 — Requirements Traceability (commit metadata requirement)
- ADR 0012 — Traceability Matrix (PR gates reflect representative signals)
- ADR 0014 — Traceability Telemetry (CI artifacts & evidence)
- ADR 0015 — Commit Message Issue Requirement (commit policy)

## Decision
Introduce a simplified scope model and dependencies:

- Keep: tests-gate, coverage-gate, yaml-lint, docs-gate (links), srs-gate,
  srs-maintenance, design-lock, adr-lint.
- Remove: authorship/mode gates and orchestration-specific gates.
- SRS compliance numeric gate (100%) on PRs remains opt‑in via label `srs-strict`;
  on main, the numeric gate remains mandatory.
- Install required Python tools inline in workflows; no repo-wide requirements files.

## Consequences
- Reduces false failures for human PRs; targeted checks still enforce policy
  when the appropriate label is present.
- CI logs remain actionable; contributors can opt‑in to stricter gates by
  applying labels.
- Workflows become self‑sufficient without repo‑pinned requirements files.

## Rollout
- Gate selected jobs by `contains(github.event.pull_request.labels.*.name, '…')`.
- Inline minimal `pip install` in stage workflows; remove `tests/requirements.txt`
  references.
