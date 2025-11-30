# SRS Maintenance — CI Job (FGC-REQ-GOV-010)

**Purpose.** Keep `docs/srs/index.yaml`, `docs/VCRM.csv`, and `docs/compliance/report.json` current on each push to the default branch.

**Shall (excerpt, normative reference):**
- Per **FGC-REQ-GOV-010 RQ1**, the CI system **shall** regenerate the SRS index, the verification cross‑reference matrix, and the compliance report on each push to the default branch.
- AC1–AC5 in `docs/srs/FGC-REQ-GOV-010.md` define verifiable outcomes: outputs are present and internally consistent, the commit remains idempotent, artifacts are published, the smoke test passes, and preflight is enforced.
- Per **FGC-REQ-GOV-010 RQ2**, pull requests modifying `docs/srs/**`, `docs/compliance/**`, or `scripts/**` shall compute ISO/IEC 29148 compliance, run the SRS maintenance smoke test, and enforce 100% compliance.

**Inputs (preflight):**
- `docs/srs/` exists; scripts present: `build_srs_index.py`, `generate_vcrm.py`, `compute_29148_compliance.py`
- Python 3.11 + `ruamel.yaml` (installed inline in the workflow)

**Outputs (evidence):**
- `docs/srs/index.yaml` (count + per-requirement rows)
- `docs/VCRM.csv`
- `docs/compliance/report.json` (includes `compliance_percent`)
- Uploaded as workflow artifact **`srs-maintenance`**
- Committed only if changed (`ci: update SRS index/VCRM/compliance [skip ci]`)

**Terminology.**
- **Outputs** — files written by the job: `docs/srs/index.yaml`, `docs/VCRM.csv`, `docs/compliance/report.json`.
- **Artifacts** — the uploaded bundle from the workflow run (artifact name **`srs-maintenance`**) that contains the Outputs for inspection.

**Smoke checks (objective):** E2 (index), E3 (VCRM schema), E4 (report range)

**Trace.**
- SRS: `docs/srs/FGC-REQ-GOV-010.md`
- Workflow: `.github/workflows/srs-maintenance.yml`
- PR gate: `.github/workflows/srs-pr-gate.yml`
- Smoke: `scripts/srs_maintenance_smoke.py`

**PR gate (objective, Priority: Medium):** `SRS PR Gate` runs `scripts/compute_29148_compliance.py`, executes the smoke test, and fails if a required script is missing or `docs/compliance/report.json` exists with `compliance_percent` below 100. Python dependencies are installed inline in the workflow (no requirements files).

**Attributes (informative for this job).**
- **Priority**: Medium — mitigates risk of stale SRS artifacts blocking compliant releases.
- **Owner**: DevEx (CI maintainers) — RACI: R=DevEx, A=QA, C=Security, I=All engineers
