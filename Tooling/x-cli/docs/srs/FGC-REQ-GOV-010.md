# FGC-REQ-GOV-010 - Automated SRS maintenance on default branch
Version: 1.0

## Statement(s)
- RQ1. The default branch shall automatically regenerate the SRS index, VCRM, and compliance report, validate them with a smoke test, and commit updates when necessary.
- RQ2. Pull requests modifying `docs/srs/**`, `docs/compliance/**`, or `scripts/**` shall compute ISO/IEC 29148 compliance, run the SRS maintenance smoke test, and enforce 100% compliance.

## Rationale
Automated maintenance keeps SRS artifacts accurate without manual intervention.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. **Outputs present & coherent.** A run on the default branch shall write `docs/srs/index.yaml` with `count` matching the number of `docs/srs/FGC-REQ-*.md` files and `requirements[].file` covering all of them; `docs/VCRM.csv` shall include columns `Requirement ID` and `Evidence count`; `docs/compliance/report.json` shall report numeric `compliance_percent` within [0, 100].
- AC2. **Idempotent commit.** If any of the three files changed, the run shall commit them with message exactly `ci: update SRS index/VCRM/compliance [skip ci]`; otherwise, it shall make no commit.
- AC3. **Artifacts.** The run shall upload the three files as workflow artifacts with artifact name exactly `srs-maintenance`.
- AC4. **Smoke test passes.** The job step `Smoke test (objective checks)` shall exit with code 0 and print `SMOKE TEST OK` when the repository is in a healthy state.
- AC5. **Preflight enforcement.** If required inputs or imports are missing, the job shall fail in the `Preflight checks` step with an actionable error message.
- AC6. **PR gate.** A pull request touching those paths shall trigger job `SRS PR Gate` which shall fail if `scripts/compute_29148_compliance.py` or `scripts/srs_maintenance_smoke.py` is missing or exits non-zero. If `docs/compliance/report.json` exists and its `compliance_percent` is below 100, the job shall fail; otherwise, the numeric enforcement step shall be skipped.

## Attributes
Priority: Medium
Owner: DevEx
RACI: R=DevEx, A=QA, C=Security, I=All engineers
Risk: Stale SRS artifacts prevent compliant releases
Source: Process policy
Status: Proposed
Trace: `.github/workflows/srs-maintenance.yml`, `scripts/build_srs_index.py`, `scripts/generate_vcrm.py`, `scripts/compute_29148_compliance.py`, `scripts/srs_maintenance_smoke.py`

## Terms used (workflow context)
- **Artifacts** — the uploaded bundle from a workflow run (artifact name: `srs-maintenance`) that contains:
  `docs/srs/index.yaml`, `docs/VCRM.csv`, and `docs/compliance/report.json`.
- **Outputs** — the same three files written into the repository working tree by the job prior to commit.
- **Smoke test** — `scripts/srs_maintenance_smoke.py` verifying basic SRS hygiene.
- **Compliance** — `scripts/compute_29148_compliance.py` producing `docs/compliance/report.json` and a numeric `compliance_percent`.
