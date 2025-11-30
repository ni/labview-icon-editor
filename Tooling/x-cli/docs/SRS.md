# SRS Index

This directory hosts the normative specifications for X-CLI. These specifications follow the IEEE 830-1998 style; see the [Core Specification](srs/core.md) or the [IEEE 830-1998 standard](https://standards.ieee.org/ieee/830/7100/) for details.

Traceability expectations are defined in [ADR 0006: Requirements Traceability](adr/0006-requirements-traceability.md).

For the CI job that regenerates the SRS index, VCRM, and compliance report, see
[compliance/SRS-MAINTENANCE.md](compliance/SRS-MAINTENANCE.md).

## Traceability Matrix

Run `python scripts/generate-traceability.py` to produce `telemetry/traceability.json` summarizing coverage. Each requirement entry lists the SRS file (`spec`), test files (`tests`), and commit hashes (`commits`). The script uses the Python standard library and `git ls-files` to honour `.gitignore` rules, avoiding external dependencies at the cost of slower performance (~0.26 s vs 0.024 s for ~2 k files compared to ripgrep). Use this matrix to verify requirements are exercised by tests and tracked through commits.
The SRS sets a performance target: scanning ~2 k test files must finish within five seconds on a GitHub-hosted Ubuntu runner.

- [Core Specification](srs/core.md)
- [FGC-REQ-SPEC-001 — SRS Document Registry](srs/FGC-REQ-SPEC-001.md)
- [FGC-REQ-DEV-001 — Traceability updater records commit evidence](srs/FGC-REQ-DEV-001.md)
- [FGC-REQ-DEV-002 — Traceability verification ensures sources and IDs](srs/FGC-REQ-DEV-002.md)
- [FGC-REQ-DEV-003 — Telemetry modules expose agent feedback](srs/FGC-REQ-DEV-003.md)
- [FGC-REQ-DEV-004 — Telemetry entries include agent feedback block](srs/FGC-REQ-DEV-004.md)
- [FGC-REQ-DEV-005 — Commit messages include SRS metadata](srs/FGC-REQ-DEV-005.md)
 - [FGC-REQ-DEV-006 — Workflows declare valid SRS IDs](srs/FGC-REQ-DEV-006.md)
- [FGC-REQ-DEV-007 — Model and dataset version control](srs/FGC-REQ-DEV-007.md)
- [FGC-REQ-QA-COV-001 — Coverage Gate](srs/FGC-REQ-QA-COV-001.md)
- [FGC-REQ-QA-002 — Isolated test environment](srs/FGC-REQ-QA-002.md)
- [FGC-REQ-QA-003 — Reset stateful modules between tests](srs/FGC-REQ-QA-003.md)
- [FGC-REQ-TEL-001 — Telemetry analyses track SRS omissions and QA regressions](srs/FGC-REQ-TEL-001.md)
- [FGC-REQ-TEL-002 — Telemetry publish robustness](srs/FGC-REQ-TEL-002.md)
- [FGC-REQ-TEL-003 — Telemetry diagnostics and summaries](srs/FGC-REQ-TEL-003.md)
- [FGC-REQ-NOT-001 — GitHub Comment Alerts](srs/FGC-REQ-NOT-001.md)
- [FGC-REQ-NOT-002 — Slack Alerts](srs/FGC-REQ-NOT-002.md)
- [FGC-REQ-NOT-003 — Email Alerts](srs/FGC-REQ-NOT-003.md)
- [FGC-REQ-NOT-004 — Discord Alerts](srs/FGC-REQ-NOT-004.md)
- [FGC-REQ-CI-001 — Build pipelines](srs/FGC-REQ-CI-001.md)
- [FGC-REQ-CI-002 — Auto-advance on green](srs/FGC-REQ-CI-002.md)
- [FGC-REQ-CI-003 — Codex execute](srs/FGC-REQ-CI-003.md)
- [FGC-REQ-CI-004 — Codex orchestrator](srs/FGC-REQ-CI-004.md)
- [FGC-REQ-CI-005 — Configure branch protection](srs/FGC-REQ-CI-005.md)
- [FGC-REQ-CI-006 — Design lock](srs/FGC-REQ-CI-006.md) — workflow runs codex design validation script
- [FGC-REQ-CI-007 — Dispatch codex](srs/FGC-REQ-CI-007.md)
- [FGC-REQ-CI-008 — Enforce codex authorship](srs/FGC-REQ-CI-008.md)
- [FGC-REQ-CI-009 — Setup waterfall labels](srs/FGC-REQ-CI-009.md)
- [FGC-REQ-CI-010 — Telemetry aggregate](srs/FGC-REQ-CI-010.md)
- [FGC-REQ-CI-011 — Test workflow](srs/FGC-REQ-CI-011.md)
- [FGC-REQ-CI-012 — Trigger codex orchestration](srs/FGC-REQ-CI-012.md)
- [FGC-REQ-CI-013 — Validate codex metadata](srs/FGC-REQ-CI-013.md)
- [FGC-REQ-CI-014 — Validate waterfall state](srs/FGC-REQ-CI-014.md)
- [FGC-REQ-CI-015 — Waterfall advance](srs/FGC-REQ-CI-015.md)
- [FGC-REQ-CI-016 — Discord canary](srs/FGC-REQ-CI-016.md)
- [FGC-REQ-CI-017 — Agents contract check](srs/FGC-REQ-CI-017.md)
- [FGC-REQ-CI-018 — Codex mirror sign](srs/FGC-REQ-CI-018.md)
- [FGC-REQ-CI-019 — Commit message policy](srs/FGC-REQ-CI-019.md)
- [FGC-REQ-CI-020 — Stage 3 validation](srs/FGC-REQ-CI-020.md)

SRS requirement files live under `docs/srs/` and are named after their IDs,
using the pattern `FGC-REQ-<DOMAIN>-<NNN>.md` (e.g., `FGC-REQ-DEV-001.md`).
Version information is tracked within each document rather than in the file
name.

## Workflow Requirement Mapping

| Workflow | Requirement |
| --- | --- |
| `.github/workflows/build.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/build-release-assets.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/publish-container.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/release.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/release-dryrun.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/create-tag.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/stage1-telemetry.yml` | FGC-REQ-CI-010 |
| `.github/workflows/stage2-3-ci.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/stage2.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/stage3.yml` | FGC-REQ-CI-020 |
| `.github/workflows/telemetry-aggregate.yml` | FGC-REQ-CI-010 |
| `.github/workflows/tests-gate.yml` | FGC-REQ-CI-011 |
| `.github/workflows/pre-commit.yml` | FGC-REQ-CI-011 |
| `.github/workflows/yaml-lint.yml` | FGC-REQ-CI-011 |
| `.github/workflows/docs-gate.yml` | FGC-REQ-CI-011 |
| `.github/workflows/srs-gate.yml` | FGC-REQ-CI-011 |
| `.github/workflows/srs-maintenance.yml` | [FGC-REQ-CI-001](srs/FGC-REQ-CI-001.md) |
| `.github/workflows/design-lock.yml` | FGC-REQ-CI-006 |

## Development Script Requirement Mapping

| Script | Requirement |
| --- | --- |
| `scripts/analyze_srs_telemetry.py` | FGC-REQ-TEL-001 |
| `scripts/analyze_telemetry.py` | FGC-REQ-TEL-001 |
| `scripts/build.ps1` | FGC-REQ-DIST-001 |
| `scripts/build.sh` | FGC-REQ-DIST-001 |
| `scripts/check-commit-msg.py` | FGC-REQ-DEV-005 |
| `scripts/check_agent_feedback.py` | FGC-REQ-DEV-003 |
| `scripts/check_telemetry_block.py` | FGC-REQ-DEV-004 |
| `scripts/check_agent_feedback_block.py` | FGC-REQ-DEV-004 |
| `scripts/github_comment.py` | FGC-REQ-NOT-001 |
| `scripts/generate-traceability.py` | FGC-REQ-DEV-001 |
| `scripts/prepare-commit-msg.py` | FGC-REQ-DEV-005 |
| `scripts/qa.ps1` | FGC-REQ-DIST-001 |
| `scripts/qa.sh` | FGC-REQ-DIST-001 |
| `scripts/render_qa_telemetry_dashboard.py` | FGC-REQ-TEL-001 |
| `scripts/render_telemetry_dashboard.py` | FGC-REQ-TEL-001 |
| `scripts/update_traceability.py` | FGC-REQ-DEV-001 |
| `scripts/verify-traceability.py` | FGC-REQ-DEV-002 |
| `scripts/verify-workflow-srs.py` | FGC-REQ-DEV-006 |

## Linting & Mapping Checks

- `scripts/lint_srs_29148.py` enforces structure and language.
- `scripts/check_srs_title_ascii.py` prevents Unicode in SRS H1 titles for changed files.
- `scripts/verify_new_srs_mappings.py` ensures changed SRS IDs are present in `docs/traceability.yaml` and `docs/module-srs-map.yaml`.

## Module Requirement Mapping

Module directories map to their relevant SRS IDs in
[`module-srs-map.yaml`](module-srs-map.yaml). Add a new module by appending its
path and requirement list:

```yaml
path/to/module/:
  - TEST-REQ-EXAMPLE-001
  - TEST-REQ-EXAMPLE-002
```

These `TEST-REQ-EXAMPLE` identifiers are illustrative placeholders only and
are not tracked requirements in this SRS.

Paths are matched by prefix, so nested files inherit their parent module's
requirements.

When adding a module:

- Use the directory path with a trailing slash.
- List one or more SRS requirement IDs defined under `docs/srs/`.
- Run `python scripts/scan_srs_refs.py` to verify coverage. `scripts/qa.sh` invokes
  this check in QA and CI pipelines.
