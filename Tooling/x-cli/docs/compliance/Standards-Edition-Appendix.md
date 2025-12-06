# Standards — Edition Appendix

_Curated clause/title lists and edition pins for bracket‑style citations._
Use titles in citations (numbers can shift across editions). Examples:

-   PR gate rationale → **[29119‑2 — Test monitoring & control]**
-   Baseline/tag policy → **[10007 — Configuration identification]**

---

## 0) Edition Pins (use these unless a contract says otherwise)

-   **ISO/IEC/IEEE 12207:2017** — Systems & software engineering — Software life cycle processes
-   **ISO/IEC/IEEE 29148:2018** — Requirements engineering
-   **ISO/IEC/IEEE 29119‑2:2021** — Software testing: Test processes
-   **ISO/IEC/IEEE 29119‑3:2021** — Software testing: Test documentation
-   **ISO/IEC/IEEE 15289:2019** — Content of information items
-   **ISO/IEC/IEEE 42010:2022** (accept **2011** as equivalent for titles) — Architecture description
-   **ISO 10007:2017** — Quality management — Configuration management guidelines
-   **IEEE 828‑2012** — Configuration Management Plan (SCMP) content
-   **SAE/EIA‑649C** — Configuration management standard (principles)

> **Rule of thumb:** Cite **titles**; add edition only where needed (e.g., “(2017)” in a footnote). Keep direct quotes ≤ 25 words.

---

## 1) ISO/IEC/IEEE 12207:2017 — Practical anchors

**Technical processes**

-   Stakeholder needs & requirements definition
-   System/software requirements definition
-   Architecture design / Detailed design
-   Software construction / integration
-   **Verification**
-   **Validation**
-   **Transition** (into operation)
-   Operation / Maintenance (as applicable)

**Technical management**

-   Project planning & control (measurement, monitoring)
-   **Configuration management (process)**
-   Risk management / Information management

**Use in repo**

-   Release gate → **[12207 — Transition/Verification]**
-   PR gates & dashboards → **[12207 — Project control]**
-   CM plan pointer → **[12207 — Configuration management]**

---

## 2) ISO/IEC/IEEE 29148:2018 — Requirements anchors

**Information items & practice**

-   **Requirements information items (SRS)**
-   Requirements quality characteristics (necessary, singular, unambiguous, feasible, **verifiable**)
-   **Traceability** (Req ↔ Test ↔ Code)
-   Changes to requirements (record, analyze, trace)

**Use in repo**

-   SRS and RTM → **[29148 — Requirements information items]**, **[29148 — Traceability]**
-   PR RTM check → **[29148 — Verifiable requirements]**

---

## 3) ISO/IEC/IEEE 29119‑2:2021 — Test processes

**Core process anchors**

-   **Test planning**
-   **Test monitoring & control**
-   Test design & implementation (techniques/coverage targets)
-   Test execution & incident management
-   **Test completion** (assess exit criteria, summarize results)

**Use in repo**

-   PR coverage gate (thresholds) → **[29119‑2 — Test monitoring & control]**
-   Release gate (re‑evaluate criteria) → **[29119‑2 — Test completion]**

---

## 4) ISO/IEC/IEEE 29119‑3:2021 — Test documentation

**Information items**

-   **Test plan / strategy**
-   Test design specification
-   Test case & procedure specs
-   **Test report** (results, measures, anomalies, environment)
-   Measurement records (e.g., **coverage**)

**Use in repo**

-   Coverage summary & artifacts → **[29119‑3 — Test report]**
-   Storing `coverage.xml` + HTML → **[29119‑3 — Measurement records]**

---

## 5) ISO/IEC/IEEE 15289:2019 — Information items

**Document families**

-   **Plans** (e.g., SCMP, Test Plan/Strategy)
-   **Specifications** (SRS)
-   **Reports/records** (Test Report, Release Record, CM status)
-   **Procedures & guidelines** (operational guidance)

**Use in repo**

-   `docs/compliance/Release-Record.md` → **[15289 — Reports/records]**
-   Link‑check CI & doc hygiene → **[15289 — Information items]**

---

## 6) ISO/IEC/IEEE 42010:2022 (≈2011) — Architecture description

**Anchors**

-   **Stakeholders & concerns**
-   **Viewpoints** (definitions/purposes)
-   **Views** (Context / Container / Component / Deployment)
-   **Correspondences & consistency**
-   **Architecture rationale** (decisions)
-   **Architecture decisions** (ADRs as supporting records)

**Use in repo**

-   4‑view packet + ADR index → **[42010 — Viewpoints, views, correspondences]**
-   Per‑view “Rationale” sections → **[42010 — Architecture rationale]**

---

## 7) ISO 10007:2017 — Configuration management

**Process anchors**

-   **Configuration identification** (baselines, items, versions/tags)
-   **Configuration change control** (gates/approvals)
-   **Configuration status accounting** (records of what was released)
-   **Configuration audit** (functional/physical)

**Use in repo**

-   SemVer tags & release assets → **[10007 — Status accounting]**
-   Required PR checks → **[10007 — Change control]**
-   Tag defines baseline → **[10007 — Configuration identification]**

---

## 8) IEEE 828‑2012 — SCMP content (what to include)

**Minimum SCMP sections**

-   Scope & referenced standards
-   **Configuration identification** (items, naming, baselines)
-   **Change management** (process, boards/approvals, tools)
-   **Status accounting** (reports, repositories)
-   **Audits** (FCA/PCA criteria)
-   Roles & responsibilities, interfaces with QA/Test/Release

**Use in repo**

-   `docs/CM-Tagging-Policy.md` + required checks list → **[IEEE 828 — SCMP content]**

---

## 9) SAE/EIA‑649C — CM principles (pragmatic anchors)

-   **Identify** (what is controlled)
-   **Change** (authorization and implementation)
-   **Record/Status** (know current/approved baselines)
-   **Verify/Audit** (evidence matches definition)

**Use in repo**

-   Release attachments (binaries + coverage) → **[EIA‑649C — Record/Status]**
-   Gate before baseline → **[EIA‑649C — Change]**

---

## 10) Quick Citation Map (ready‑to‑paste)

-   PR coverage gate (thresholds, artifacts) → **[29119‑2 — Test monitoring & control]**, **[29119‑3 — Test report]**
-   Release tag re‑run & abort on breach → **[12207 — Transition/Verification]**
-   SemVer baseline + Release assets → **[10007 — Configuration identification]**, **[10007 — Status accounting]**
-   RTM (Req→Test→Code) → **[29148 — Traceability]**
-   Architecture packet (4 views + ADRs) → **[42010 — Viewpoints, views, correspondences]**
-   Docs quality & link‑check CI → **[15289 — Information items]**
-   CM Plan sections → **[IEEE 828 — SCMP content]**

---

## 11) House rules

-   Prefer **titles**; keep quotes ≤ 25 words; otherwise **paraphrase + bracket citation**.
-   If an external customer mandates clause numbers, include both:
    “Exit criteria enforced (**29119‑2 §Test monitoring & control**, 2021).”
