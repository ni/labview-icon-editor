# Milestone: Restore Python Coverage after scripts/lib migration

Purpose: Re-enable Python coverage in CI once scripts/lib completes migration of
helpers previously provided by codex_rules and thresholds are recalibrated.

Owners: QA (@team-qa), DevEx (@team-devex)
Target: R2 (next minor)

## Tasks

- [ ] Complete migration: scripts rely only on scripts/lib (no `codex_rules` imports)
- [ ] Add unit tests targeting scripts/lib modules (telemetry, storage, config)
- [ ] Re-introduce Python coverage in CI:
  - [ ] coverage-gate.yml: setup Python + pytest-cov + coverage
  - [ ] tests-gate.yml: optional per-PR Python coverage artifact (if needed)
  - [ ] release.yml: re-run Python coverage to publish combined reports
- [ ] Update ReportGenerator merge inputs to include Python XML
- [ ] Recalibrate thresholds in docs/compliance/coverage-thresholds.json:
  - [ ] Add entries for scripts/lib/* with sensible floors
  - [ ] Keep .NET floors unchanged
- [ ] Update README Local Coverage with combined (.NET + Python) instructions

## Coverage Governance

- Use conservative thresholds initially (e.g., total line ≥ 60%, branch ≥ 40%) and mark PRs with label `coverage:conservative` during the re‑enablement window.
- Raise thresholds iteratively as scripts/lib gains tests. Track increases via label `coverage:raise-iteratively` on PRs that bump floors and address gaps.
- Keep per‑file floors narrowly scoped to scripts/lib modules providing critical functionality; avoid blanket high floors that discourage incremental adoption.
 - Label hygiene is maintained by the Labels Sync workflow (see README badge link).

## Acceptance Criteria

- CI shows merged Cobertura (HTML + XML) including Python coverage
- Thresholds pass on main and PRs; new tests cover scripts/lib critical paths
- No `codex_rules` imports from scripts/ (enforced by pre-commit linter)

## Create a GitHub Issue (optional)

```
GITHUB_TOKEN=<pat> GITHUB_REPOSITORY=<owner>/<repo> \
python scripts/create_issue.py \
  --title "Milestone: Restore Python Coverage after scripts/lib migration" \
  --body "$(cat docs/issues/milestone-restore-python-coverage.md)" \
  --label milestone --label qa --label coverage
```
