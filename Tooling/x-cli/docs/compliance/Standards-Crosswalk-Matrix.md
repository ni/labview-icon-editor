# Standards Crosswalk — Matrix (Repo‑Authored Synthesis)

> Use **clause titles** as canonical anchors (edition numbering can vary). Cite like: **[29119‑2 — Test monitoring & control]**.
> See also: Edition pins in _Standards‑Edition‑Appendix.md_ and citation rules in _Standards‑Citation‑Guide.md_.

## A. Backbone Map (12207 → others → repo evidence)

| Backbone topic               | 12207 anchor                            | Primary standards                                           | Supporting standards                                          | Expected repo evidence                                               |
| ---------------------------- | --------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------- |
| Change & approvals (PR gate) | **Technical management (CM/QA)**        | **[10007 — Change control]**                                | **[15289 — Information items]**                               | Branch protection w/ required checks; gate logs; PR rule doc         |
| Release/transition (tag)     | **Transition; Verification**            | **[29119‑2 — Test completion]**                             | **[29119‑3 — Test report]**, **[10007 — Status accounting]**  | Tag workflow; re‑run tests; Release assets + Release‑Record          |
| Verification & validation    | **Verification; Validation**            | **[29119‑2 — Test processes]**                              | **[29119‑3 — Test documentation]**                            | Coverage gate plan; thresholds; results; anomalies                   |
| Requirements mgt             | **Requirements definition/maintenance** | **[29148 — Requirements information items]**                | **[15289 — Information items]**                               | SRS; RTM; change notes linking to tests/code                         |
| Architecture description     | **Architecture & design**               | **[42010 — Viewpoints, views, correspondences, rationale]** | **[15289 — Architecture information item]**                   | Context/Container/Component/Deployment views; ADRs; rules            |
| Configuration management     | **Technical management (CM)**           | **[10007 — Identification/Change/Status/Audit]**            | **[IEEE 828 — SCMP content]**, **[EIA‑649C — CM principles]** | CM Plan (SCMP); baseline/tag policy; status reports; audit checklist |
| Information items (docs)     | **Measurement & information**           | **[15289 — Information items]**                             | —                                                             | Minimal docs set mapped to processes                                 |
| Measurement/metrics          | **Information & measurement**           | **[29119‑2 — Monitoring & control]**                        | —                                                             | Thresholds, trends, coverage deltas                                  |

## B. Gate‑to‑Standard Map (ready to cite)

| Gate / control             | Primary anchor                                    | Secondary anchors                                              | Minimal evidence                                             |
| -------------------------- | ------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------ |
| **PR Coverage (required)** | **[29119‑2 — Test monitoring & control]**         | **[29119‑3 — Test report]**, **[10007 — Status accounting]**   | `coverage.xml`, HTML, summary, job green, required check set |
| **Tag Release Gate**       | **[12207 — Transition/Verification]**             | **[29119‑2 — Completion]**, **[29119‑3 — Test documentation]** | Re‑run tests, enforce thresholds, Release assets & record    |
| **Branch protection**      | **[10007 — Change control]**                      | **[12207 — Technical management]**                             | Rule showing required contexts                               |
| **RTM (Req→Test→Code)**    | **[29148 — Traceability]**                        | **[29119‑3 — Test results]**                                   | `docs/traceability.yaml`, RTM check log                      |
| **Architecture packet**    | **[42010 — Viewpoints, views & correspondences]** | **[15289 — Architecture info item]**                           | 4 views + ADR index + correspondence rules                   |

## C. Doc Type Map (15289 anchor)

| Doc / record                 | Standard anchor                                        | “Smallest sufficient” content                             |
| ---------------------------- | ------------------------------------------------------ | --------------------------------------------------------- |
| **SRS**                      | **[29148 — Requirements information items]**           | IDs, “shall”, fit criteria, verification, trace           |
| **Test Plan/Strategy**       | **[29119‑2 — Test planning]**                          | Scope, gates/thresholds, measures, roles                  |
| **Test Report**              | **[29119‑3 — Test report]**                            | Totals, failures, artifacts, environment                  |
| **CM Plan (SCMP)**           | **[IEEE 828 — SCMP content]**                          | Baselines/tags, change control, status accounting, audits |
| **Architecture Description** | **[42010 — Viewpoints, views, correspondences]**       | 4 views, rationale, ADRs, correspondence rules            |
| **Release Record**           | **[15289 — Reports]**, **[10007 — Status accounting]** | Tag, commit, coverage vs thresholds, assets list          |

> This matrix is original synthesis for this repo. Use titles for citations; keep verbatim quotes ≤25 words.
