# Standards Checklists (Lean)

> Tick these in PRs/reviews. Titles are canonical anchors; cite in comments with bracket style.

## A. SRS Quality (🧩 **[29148 — Requirements information items]**)

-   [ ] Each requirement is **necessary, singular, unambiguous, feasible, verifiable**.
-   [ ] Has **ID**, rationale, **fit criterion**, verification method.
-   [ ] RTM row exists (Req→Test→Code) for critical items (**[29148 — Traceability]**).
-   [ ] Changes recorded and linked to tests/code.

## B. Test Plan / Strategy (🧪 **[29119‑2 — Test planning]**)

-   [ ] Gates & **exit criteria** defined (total line ≥ 75%, branch ≥ 60%; file floors).
-   [ ] Environment defined (runners, .NET/Python, tools).
-   [ ] Measures (coverage, failures, anomalies) and reporting path (**[29119‑3]**).
-   [ ] Roles & responsibilities set.

## C. Test Report (📈 **[29119‑3 — Test report]**)

-   [ ] Totals (line & branch) vs thresholds.
-   [ ] Failures/anomalies captured or linked.
-   [ ] Artifacts listed: `coverage.xml`, HTML, logs.
-   [ ] Version/build context (tag/commit, environment) recorded.

## D. CM Plan (SCMP) (🔐 **[IEEE 828 — SCMP content]**, **[10007 — CM process]**)

-   [ ] Baselines: SemVer tags define configuration **baselines** (**[10007 — Identification]**).
-   [ ] **Required checks** listed and enforced (**[10007 — Change control]**).
-   [ ] **Status accounting**: release record + artifacts attached (**[10007 — Status accounting]**).
-   [ ] **Audit** triggers (FCA/PCA) and log location (**[10007 — Audit]**).

## E. Architecture Packet (🏗 **[42010 — Viewpoints, views, correspondences]**)

-   [ ] 4 views present (Context/Container/Component/Deployment).
-   [ ] **Stakeholders & concerns** and **viewpoints** defined.
-   [ ] **Correspondence rules** + examples; **rationale**; ADR index.
-   [ ] Packet links checked (CI link‑check green) (**[15289 — Information items]**).
