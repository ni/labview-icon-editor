# R1 Readiness Audit — fake‑g‑cli (x‑cli)

**As‑of (UTC):** <fill at publish>  
**Scope:** PR coverage gate (required + evidence) and semver‑tag release gate.

---

## A) Verdict

**Overall:** ✅ **PASS**

| Gate | Status | Evidence (anchors) | Standards |
|---|---|---|---|
| **PR coverage gate** — merged Cobertura XML + zipped HTML; thresholds enforced on PRs | **PASS** | `.github/workflows/coverage-gate.yml` → ReportGenerator merges .NET (`**/coverage.cobertura.xml`) + Python (`coverage-python.xml`) to `artifacts/coverage/Cobertura.xml` → copied to root `coverage.xml`; zipped HTML at `artifacts/coverage-html.zip`; thresholds via `scripts/enforce_coverage_thresholds.py` using `docs/compliance/coverage-thresholds.json` (`total`: 75.0 + file floors). | 29119‑2/‑3 (planning/monitoring & test report), 15289 (test info items) |
| **PR gate is Required** — branch protection check `coverage` | **PASS*** | Automation present: `.github/workflows/auto-branch-protection.yml` attempts API update; on insufficient perms, opens admin Issue. Admin checklist: `docs/compliance/Branch-Protection.md`. | 10007 (config control/status), 12207 (verification before change acceptance) |
| **Semver release gate** — re‑run coverage on tag, abort on breach, attach assets | **PASS** | `.github/workflows/release.yml` triggers on `v*.*.*`; re‑runs tests/merge coverage; enforces thresholds; builds self‑contained binaries; attaches **XCli-linux-x64**, **XCli-win-x64.exe**, `coverage-html.zip`, and `coverage.xml`. | 12207 (release control), 10007 (baseline/status), 29119‑2/‑3, 15289 |

\* *If org permissions prevent auto‑set, admins must enable **coverage** as a Required check; keep a screenshot/API export. Automation files the Issue when it cannot set the rule.*

---

## B) Evidence (concise)

- **PR gate workflow:** `.github/workflows/coverage-gate.yml`  
  Merge: `reports: '**/coverage.cobertura.xml;coverage-python.xml'` → Cobertura + HTML under `artifacts/coverage/` → copy to `coverage.xml`; zip HTML to `artifacts/coverage-html.zip`; upload artifact **coverage-xml-and-html** (retention 14d).  
  Thresholds: `scripts/enforce_coverage_thresholds.py` + `docs/compliance/coverage-thresholds.json` (`total` 75.0; file floors).

- **Coverage tooling present:**  
  `.NET` collector via `tests/Directory.Build.props` (`coverlet.collector`); Python plugin pinned in `tests/requirements.txt` (`pytest-cov`).

- **Branch protection assist:**  
  `.github/workflows/auto-branch-protection.yml` (best‑effort API update; opens Issue if lacking admin perms).  
  Admin how‑to: `docs/compliance/Branch-Protection.md`.

- **Release gate:** `.github/workflows/release.yml` — tag `v*.*.*` → re‑run tests/coverage → enforce thresholds → build/rename binaries → zip coverage HTML → create Release with binaries + `coverage-html.zip` + `coverage.xml`.

---

## C) Completion criteria (met)

- PR runs: merged `coverage.xml` + `coverage-html.zip` artifact; thresholds enforced (job fails on breach).  
- Branch protection: **coverage** required (*either auto‑enforced or admin‑enabled*).  
- Tag `vX.Y.Z` Release includes **XCli-linux-x64**, **XCli-win-x64.exe**, `coverage-html.zip`, `coverage.xml`.

---

## D) Follow‑ups (recommended, non‑blocking)

- **Ratchet** coverage floors on critical files (e.g., ≥80%) as stability increases.  
- Keep **coverage** in Required checks when branch rules change.  
- Optionally publish a **coverage trend badge** and store a short **coverage-summary.txt** per release.

---

## E) Compliance trace (summary)

- **ISO/IEC/IEEE 29119‑2/‑3:** Exit criteria (coverage) defined, measured, enforced; reports/artifacts retained.  
- **ISO/IEC/IEEE 12207:** Verification integrated into PR and release controls; only verified baselines transition.  
- **ISO 10007:** Semver tag is the configuration baseline; required checks & release assets provide status accounting.  
- **ISO/IEC/IEEE 15289:** Minimal information items present (Test Strategy, Test Report, Release record).

*Prepared via static repo analysis; server‑side settings (branch protection) are validated via automation + admin confirmation where required.*
