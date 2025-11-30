# Definition of Done (DoD) & Exit Criteria (Concise)

_Edition‑agnostic citations use titles; see_ **Standards — Edition Appendix** _for pins._

---

## A) Pull Request DoD — **Required checks** (branch protection)

| Check (context)                 | Verifies                                                              | Thresholds / Rules                                                                                                   | Evidence & Paths                                                                                                                                                                                        |
| ------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PR Coverage Gate / coverage** | Unified Cobertura from **.NET + Python**; thresholds enforced.        | **Line ≥ 75%**, **Branch ≥ 60%**; file floors in config; PR fails on breach.                                         | `coverage.xml`; `artifacts/coverage/` (HTML); `artifacts/coverage-summary.md`; cfg: `docs/compliance/coverage-thresholds.json`. **[29119‑2 — Test monitoring & control]** · **[29119‑3 — Test report]** |
| **Docs Link Check / lychee**    | Local links + anchors valid in Markdown.                              | Offline; fragments on; scope `**/*.md`.                                                                              | CI log; `.github/workflows/docs-link-check.yml`; `.lychee.toml`. **[15289 — Information items]**                                                                                                        |
| **Traceability Gate / rtm**     | Changed **Reqs** (or touched `src/**`) trace to **Tests** & **Code**. | IDs match `FGC-REQ-*`; at least 1 test + 1 code path resolve.                                                        | `docs/traceability.yaml`; gate: `scripts/rtm_verify.py`. **[29148 — Traceability]**                                                                                                                     |
| **ADR Lint / adr-lint**         | ADR hygiene + index.                                                  | Filenames `NNNN-title.md`; H1/Status/Date/Decision/Consequences present; Supersedes links valid; `INDEX.md` updated. | `docs/adr/*.md`; `docs/adr/INDEX.md`; `scripts/adr_lint.py`. **[42010 — Rationale/Decisions]** · **[15289 — Design description]**                                                                       |

> **Required status checks (default)** → `PR Coverage Gate / coverage`, `Docs Link Check / lychee`, `Traceability Gate / rtm`, `ADR Lint / adr-lint`. **[10007 — Change control]**

---

## B) Release (tag **vX.Y.Z**) DoD — **Release gate**

| Criterion             | Rule                                                                              | Evidence & Paths                                                                                                                                                            |
| --------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SemVer tag**        | Pattern `v*.*.*`; tag == baseline id.                                             | Tag event; Release created. **[10007 — Identification]**                                                                                                                    |
| **Coverage re‑run**   | Rebuild & re‑test on tag; merge .NET+Py; enforce thresholds; **abort on breach**. | `coverage.xml`; `artifacts/coverage/` (HTML). **[29119‑2 — Completion]** · **[12207 — Transition]**                                                                         |
| **Binaries**          | Single‑file, self‑contained for linux‑x64 & win‑x64; `--version` == tag sans `v`. | `artifacts/release/linux-x64/x-cli-linux-x64-<ver>`; `.../x-cli-win-x64-<ver>.exe`.                                                                                         |
| **Release assets**    | Attach binaries + coverage HTML + Cobertura XML + Release Record.                 | `artifacts/coverage/Cobertura.xml`; `artifacts/coverage/index.html` (and `coverage-html.zip` if zipped); `docs/compliance/Release-Record.md`. **[15289 — Release records]** |
| **Status accounting** | Release Record lists tag/commit, coverage totals vs thresholds, assets.           | `docs/compliance/Release-Record.md`. **[10007 — Status accounting]**                                                                                                        |

---

## C) Thresholds & Ratchet (house defaults)

| Metric           | Default                                                           | Config / Enforcement                                                                                          |
| ---------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Total line**   | **≥ 75%**                                                         | `docs/compliance/coverage-thresholds.json` → `"total"`; enforced by `scripts/enforce_coverage_thresholds.py`. |
| **Total branch** | **≥ 60%**                                                         | `"branch_total"` in same config; enforced by script.                                                          |
| **File floors**  | Critical modules have per‑file floors (line and optional branch). | `"files"` map in config (e.g., `src/XCli/Cli/Cli.cs` line 60 / branch 50).                                    |
| **Ratchet**      | On green PRs, raise (never lower) totals and floors.              | `--ratchet` in `enforce_coverage_thresholds.py`; changes reviewed in PR.                                      |

---

## D) Minimal evidence bundle per PR / Release

-   **PR**: `coverage.xml` · `artifacts/coverage/index.html` (or zipped) · `artifacts/coverage-summary.md` · CI logs for all required checks.
-   **Release**: binaries (linux/win) · `artifacts/coverage/Cobertura.xml` · `artifacts/coverage/index.html` · `docs/compliance/Release-Record.md` (with totals vs thresholds).
-   Keep artifacts for audit; link from Release page. **[15289 — Records]** · **[10007 — Status accounting]**

---

## E) Standards (quick mapping)

-   **Testing**: **[29119‑2 — Test processes]**, **[29119‑3 — Test documentation]**
-   **Requirements**: **[29148 — Requirements & Traceability]**
-   **CM / Release**: **[10007 — Identification/Change control/Status accounting]**, **[12207 — Transition/Verification]**
-   **Architecture**: **[42010 — Views/Viewpoints/Correspondences/Rationale]**
-   **Documentation**: **[15289 — Information items]**

> **Terminology**: “Gate” = automated **Required** check with objective thresholds. “Baseline” = SemVer tag after gates pass.
