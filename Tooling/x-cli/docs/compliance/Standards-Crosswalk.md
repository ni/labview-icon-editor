# Standards Crosswalk (Process Backbone = 12207)

_Bracket‑style citations use titles (edition‑agnostic). See_ **Standards — Edition Appendix**.

-   **Pins used**: 12207 (2017), 29148 (2018), 29119‑2/‑3 (2021), 15289 (2019), 42010 (2022/2011), 10007 (2017), IEEE‑828 (2012), EIA‑649C.

---

## 1) How to read

-   Cite **titles** (e.g., **[29119‑2 — Test monitoring & control]**).
-   Keep direct quotes ≤ 25 words; prefer paraphrase + citation.
-   Map each repo gate/practice to its nearest standard anchors.

---

## 2) Gates (what blocks merge/release)

| Gate / Practice                                                                         | 12207 (process)                                         | 29148 (reqs)                                             | 29119‑2 (test proc)                                   | 29119‑3 (test docs)                          | 15289 (info items)                            | 10007 (CM)                                    | 42010 (arch)                                  | IEEE‑828 (SCMP)                       | EIA‑649C (CM principles) | **Repo evidence**                                                                                                           |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------- | -------------------------------------------- | --------------------------------------------- | --------------------------------------------- | --------------------------------------------- | ------------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **PR Coverage Gate** (merged Cobertura; thresholds; artifacts; **Required**)            | **[Verification]**, **[Project control]**               | **[Verifiable requirements]** (trace targets)            | **[Test monitoring & control]**; **[Test execution]** | **[Test report]**; **[Measurement records]** | **[Reports/records]**                         | **[Change control]** (gate before change)     | —                                             | —                                     | **[Change]**             | `.github/workflows/coverage-gate.yml`, `scripts/enforce_coverage_thresholds.py`, `docs/compliance/coverage-thresholds.json` |
| **SemVer Release Gate** (tag `v*.*.*` re‑runs coverage; abort on breach; attach assets) | **[Transition]**, **[Verification]**                    | **[Traceability]** (reqs→tests)                          | **[Test completion]** (re‑assess exit criteria)       | **[Test report]**                            | **[Release records]**                         | **[Status accounting]**, **[Identification]** | —                                             | **[SCMP content]** (release record)   | **[Record/Status]**      | `.github/workflows/release.yml`, `docs/compliance/Release-Record.md`                                                        |
| **Traceability Gate (RTM)** (Req→Test→Code on changed reqs/touched src)                 | **[Requirements definition]**, **[Verification]**       | **[Requirements information items]**, **[Traceability]** | **[Test planning]** (coverage/trace scope)            | **[Test design/report]**                     | **[Specifications/records]**                  | **[Status accounting]** (linkage visible)     | —                                             | **[SCMP content]** (trace in CM plan) | **[Identify]**           | `.github/workflows/traceability-gate.yml`, `scripts/rtm_verify.py`, `docs/traceability.yaml`                                |
| **Docs Link‑Check** (lychee; anchors; local)                                            | **[Information management]**                            | —                                                        | —                                                     | —                                            | **[Information items]** (quality/consistency) | —                                             | —                                             | —                                     | —                        | `.github/workflows/docs-link-check.yml`, `.lychee.toml`                                                                     |
| **ADR Lint** (headers, status, supersede integrity; builds index)                       | **[Architecture design]**, **[Information management]** | —                                                        | —                                                     | —                                            | **[Design description]**, **[Records]**       | —                                             | **[Architecture rationale]**, **[Decisions]** | —                                     | —                        | `.github/workflows/adr-lint.yml`, `scripts/adr_lint.py`, `docs/adr/INDEX.md`                                                |
| **Branch Protection** (required checks: coverage, docs, RTM, ADR)                       | **[Project control]**, **[Configuration management]**   | —                                                        | **[Test monitoring & control]** (as gate)             | —                                            | **[Records]** (policy doc)                    | **[Change control]**                          | —                                             | **[SCMP content]**                    | **[Change]**             | `.github/workflows/configure-branch-protection.yml`, `docs/compliance/Branch-Protection.md`                                 |

> **Exit criteria default**: Total line ≥ 75%; branch ≥ 60%; critical files have floors. Adjust with risk (document changes).

---

## 3) Foundational practices (supporting)

| Practice                                                                                  | 12207                                     | 29148 | 29119‑2                         | 29119‑3           | 15289                    | 10007                                                      | 42010                                                     | 828                | 649C                    | **Repo evidence**                                                                            |
| ----------------------------------------------------------------------------------------- | ----------------------------------------- | ----- | ------------------------------- | ----------------- | ------------------------ | ---------------------------------------------------------- | --------------------------------------------------------- | ------------------ | ----------------------- | -------------------------------------------------------------------------------------------- |
| **Architecture packet** (Context/Container/Component/Deployment + Correspondences + ADRs) | **[Architecture design]**                 | —     | —                               | —                 | **[Design description]** | —                                                          | **[Viewpoints, views, correspondences]**; **[Rationale]** | —                  | —                       | `docs/architecture/*.md`, `docs/adr/INDEX.md`, `docs/compliance/Architecture-42010-Trace.md` |
| **CM tagging policy** (SemVer baseline)                                                   | **[Configuration management]**            | —     | —                               | —                 | **[Plans/Records]**      | **[Identification]**, **[Status accounting]**, **[Audit]** | —                                                         | **[SCMP content]** | **[Identify]/[Record]** | `docs/CM-Tagging-Policy.md`, `.github/workflows/release.yml`                                 |
| **Coverage policy & ratchet**                                                             | **[Verification]**, **[Project control]** | —     | **[Test monitoring & control]** | **[Test report]** | **[Records]**            | —                                                          | —                                                         | —                  | —                       | `docs/compliance/coverage-thresholds.json`, `scripts/enforce_coverage_thresholds.py`         |
| **Release record & notes**                                                                | **[Transition]**                          | —     | **[Test completion]**           | **[Test report]** | **[Release records]**    | **[Status accounting]**                                    | —                                                         | **[SCMP content]** | **[Record]**            | `docs/compliance/Release-Record.md`, `docs/CHANGELOG.md`                                     |

---

## 4) Citation snippets (ready‑to‑paste)

-   PR gate rationale → **[29119‑2 — Test monitoring & control]**, **[29119‑3 — Test report]**.
-   Tag baseline & attachments → **[10007 — Configuration identification / Status accounting]**.
-   RTM enforcement → **[29148 — Traceability]**.
-   4‑view + ADRs → **[42010 — Viewpoints, views, correspondences / Architecture rationale]**.
-   Documentation QA → **[15289 — Information items]**.
-   Release approval (gated) → **[12207 — Transition/Verification]**.

---

## 5) House rules (repo usage)

-   **Titles over numbers** in citations; add edition only when contractually required.
-   Keep quotes short; otherwise paraphrase + citation.
-   Update this crosswalk when gates/policies change; keep Edition Appendix nearby.

_See also_: **Standards — Edition Appendix** for curated clause titles and edition pins.
