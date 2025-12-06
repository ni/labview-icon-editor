# Glossary & Synonyms (Edition‑agnostic)

_Use titles in citations (see_ **Standards — Edition Appendix** _for edition pins)._

## 1) Style rules (terminology)

-   **Use**: _shall_ (normative), _should_ (recommended), _may_ (optional), _must not_ (prohibition).
-   Prefer **titles over clause numbers** in citations; keep quotes ≤ 25 words, else paraphrase + citation.
-   Treat **SemVer tags** (`vX.Y.Z`) as **configuration baselines**; “tag” ≈ “baseline identifier” only when release gate passes.

---

## 2) Core terms (with synonyms & anchors)

| Term                        | Our usage (concise)                                         | Also known as                     | Avoid/notes                          | Anchors (see Edition Appendix)                                     | Repo evidence                                     |
| --------------------------- | ----------------------------------------------------------- | --------------------------------- | ------------------------------------ | ------------------------------------------------------------------ | ------------------------------------------------- |
| **Requirement**             | Verifiable capability/constraint with ID and fit criterion. | Stakeholder/system req.           | Vague multi‑shall bullets.           | **[29148 — Requirements]**, **[15289 — Information items]**        | `docs/srs/*`, `docs/traceability.yaml`            |
| **SRS**                     | Requirements specification artifact.                        | System Requirements Spec.         | Mixing design/reqs in SRS.           | **[29148 — Information items]**                                    | `docs/SRS.md`, `docs/srs/*`                       |
| **RTM / Traceability**      | Req→Test→Code links (kept current).                         | Requirements traceability matrix. | One‑way links only.                  | **[29148 — Traceability]**, **[15289 — Records]**                  | `docs/traceability.yaml`, `scripts/rtm_verify.py` |
| **Verification**            | “Built right” checks (tests, reviews) vs. criteria.         | V&V (V part).                     | Mixing V with user validation.       | **[12207 — Verification]**, **[29119‑2 — Test Execution/Control]** | Coverage/PR gates                                 |
| **Validation**              | “Built the right thing” (fitness for intended use).         | V&V (V part #2).                  | Using validation to bypass failures. | **[12207 — Validation]**                                           | Design/ADR reviews                                |
| **Test Strategy/Plan**      | Scope, approach, exit criteria, measures.                   | Strategy/Plan.                    | Unstated exit criteria.              | **[29119‑2 — Test processes]**, **[15289 — Plans]**                | `docs/compliance/TestStrategy-Coverage.md`        |
| **Test Report**             | Results vs. exit criteria; coverage metrics.                | Test summary.                     | Pass/fail without measures.          | **[29119‑3 — Test documentation]**, **[15289 — Reports]**          | Coverage HTML/XML, Release Record                 |
| **Coverage (line/branch)**  | % lines/branches executed; unified Cobertura.               | Code coverage.                    | Non‑merged per‑lang coverage.        | **[29119‑2 — Monitoring & control]**                               | `coverage.xml`, `artifacts/coverage/**`           |
| **Threshold / Gate**        | Quantified pass/fail criteria; block merge/release.         | Exit/completion criteria.         | Soft guidance in place of a gate.    | **[29119‑2 — Completion]**, **[12207 — Transition]**               | `scripts/enforce_coverage_thresholds.py`          |
| **Baseline**                | Identified configuration state (SemVer tag).                | Release baseline.                 | Untagged “latest” as baseline.       | **[10007 — Identification]**, **[12207 — CM/Transition]**          | `v*.*.*` tags, Releases                           |
| **Configuration Item (CI)** | Item under CM (code, docs, configs).                        | Configured item.                  | Fuzzy “asset” naming.                | **[10007 — Configuration items]**, **[IEEE‑828 — SCMP]**           | Repo content                                      |
| **CM Plan (SCMP)**          | Who/what/when for CM; records & audits.                     | SCMP.                             | Implicit “process by convention”.    | **[IEEE‑828 — SCMP]**, **[10007 — CM]**                            | `docs/CM-Tagging-Policy.md`                       |
| **Status Accounting**       | Record of baseline, changes, checks, artifacts.             | Release record.                   | Missing evidence trail.              | **[10007 — Status accounting]**, **[15289 — Records]**             | `docs/compliance/Release-Record.md`               |
| **Change Control**          | Approvals & required checks before merge.                   | Change mgmt.                      | Ad‑hoc merges.                       | **[10007 — Change control]**, **[12207 — Project control]**        | Branch protection                                 |
| **ADR**                     | Architecture decision + status/rationale/supersedes.        | Decision log.                     | ADRs without status/date.            | **[42010 — Rationale/Decisions]**, **[15289 — Design desc.]**      | `docs/adr/*.md`, `docs/adr/INDEX.md`              |
| **View / Viewpoint**        | C4‑style Context/Container/Component/Deployment.            | Architecture views.               | Views without correspondences.       | **[42010 — Views/Viewpoints/Correspondences]**                     | `docs/architecture/*.md`                          |
| **Release Record**          | Tag, commit, coverage totals vs. thresholds, assets.        | Release notes (technical).        | Notes without evidence.              | **[15289 — Release records]**, **[12207 — Transition]**            | `docs/compliance/Release-Record.md`               |

---

## 3) Term normalization (house usage)

-   **Baseline** = the **SemVer tag** after gates pass; not a branch tip.
-   **Gate** = an automated **Required check** with objective thresholds.
-   **Coverage default** = line ≥ 75%, branch ≥ 60%, file floors for critical modules (raise with risk reduction).
-   **Required checks (names)** = `PR Coverage Gate / coverage`, `Docs Link Check / lychee`, `Traceability Gate / rtm`, `ADR Lint / adr-lint`.

---

## 4) Abbreviations

-   **ADR** (Architecture Decision Record) · **CM** (Configuration Management) · **CI** (Configuration Item / Continuous Integration—disambiguate by context)
-   **FCA/PCA** (Functional/Physical Configuration Audit) · **RTM** (Requirements Traceability Matrix)
-   **SCMP** (Software Configuration Management Plan) · **SRS** (System Requirements Specification)

---

## 5) Quick citation snippets (pasteable)

-   Gates/thresholds → **[29119‑2 — Test monitoring & control]**; records → **[29119‑3 — Test report]**.
-   Baselines & releases → **[10007 — Identification / Status accounting]**, **[12207 — Transition]**.
-   Traceability → **[29148 — Traceability]**.
-   Architecture packet → **[42010 — Views/Correspondences/Rationale]**.
-   Documentation QA → **[15289 — Information items]**.

_See also_: **Standards Crosswalk** · **Standards — Edition Appendix**.
