# Tracking: Deprecate legacy orchestration artifacts; update SRS/traceability

This issue tracks removal or revision of documents that no longer fit the minimal x-cli CI after pruning workflows. See `docs/workflows-inventory.md` and `docs/deprecated-docs.md`.

Owners reflect the Workflow Ownership Matrix; update as needed.

## Remove (archive or delete)
- [x] APPLY_LEGACY_VALIDATOR_GATE.md (Owner: DevEx @team-devex)
- [x] APPLY_LEGACY_VALIDATOR_SUMMARY.md (Owner: DevEx @team-devex)
- [x] APPLY_LEGACY_VALIDATOR_SCHEMA_SYNC.md (Owner: DevEx @team-devex)
- [x] WATERFALL.md (Owner: DevOps @team-devops)
- [x] tools/legacy_validator_json_summary.py (Owner: DevEx @team-devex)
- [x] docs/adr/0002-codex-verified-human-mirror.md (Owner: DevEx @team-devex)

## Revise (update to x-cli scope)
- [ ] docs/adr/0004-codex-environment-expectations.md (Owner: DevEx @team-devex) — remove Codex specifics, align with current CI images
- [ ] docs/adr/0016-ci-gates-scope-and-labels.md (Owner: QA @team-qa) — reflect fewer gates and labels
- [x] docs/SRS.md (Owner: QA @team-qa) — update Workflow Requirement Mapping to kept workflows only
- [x] docs/traceability.yaml (Owner: QA @team-qa) — drop removed workflow paths; keep valid mappings
- [x] docs/telemetry.md (Owner: QA @team-qa, DevEx @team-devex) — remove Codex-only sections or reframe for x-cli
- [x] tests/test_ci_workflows.py (Owner: QA @team-qa) — remove cases tied to deleted workflows; add cases for kept gates
- [ ] docs/baselines/R*/srs/* references to removed workflows (Owner: QA @team-qa) — mark as legacy in next baseline notes

## Validation
- [ ] Pre-commit (`pre-commit.yml`) passes
- [ ] SRS gates (`srs-gate.yml`) pass; no references to removed files
- [ ] Traceability scan OK

## Notes
- Intentionally accept short-term CI breakage while pruning; reintroduce only minimal, well-rationalized workflows with SRS/ADR links and tests.

---

To create this issue automatically:
```
GITHUB_TOKEN=<pat> GITHUB_REPOSITORY=<owner>/<repo> \
python scripts/create_issue.py \
  --title "Deprecate legacy orchestration artifacts; update SRS/traceability" \
  --body "$(cat docs/issues/cleanup-workflows-and-docs.md)" \
  --label maintenance --label docs
```

