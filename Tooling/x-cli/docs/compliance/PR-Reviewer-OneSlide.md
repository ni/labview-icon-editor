# PR Reviewer One‑Slide — Definition of Done (DoD)

> **Goal:** fast, objective “go/no‑go” on every PR.
> **Required checks (must be green):**
> • **PR Coverage Gate / coverage** • **Docs Link Check / lychee** • **Traceability Gate / rtm** • **ADR Lint / adr-lint**

---

## 1) Coverage Gate (ISO/IEC/IEEE 29119‑2/‑3)

-   **Unified Cobertura** across .NET + Python:
    -   `coverage.xml` (root) and HTML at `artifacts/coverage/index.html`.
-   **Thresholds** (from `docs/compliance/coverage-thresholds.json`):
    -   **Totals:** Line **≥ 75%**, Branch **≥ 60%**.
    -   **Per‑file floors**: all configured files meet or exceed.
-   **PR artifacts:** `artifacts/coverage-summary.md` shows no failing files.

## 2) Traceability Gate (ISO/IEC/IEEE 29148)

-   If **requirements changed** (`docs/srs/**`, `docs/traceability.yaml`) **or** code under `src/**` touched:
    -   Each in‑scope `FGC-REQ-*` has **≥ 1 Test** and **≥ 1 Code** path that resolve in `docs/traceability.yaml`.

## 3) ADR Hygiene (ISO/IEC/IEEE 42010 · 15289)

-   ADR files under `docs/adr/NNNN-*.md` have **H1 / Status / Date / Decision / Consequences**.
-   **Supersedes / Superseded‑by** references are valid and consistent.
-   `docs/adr/INDEX.md` exists and lists current ADRs.

## 4) Documentation Integrity (ISO/IEC/IEEE 15289)

-   **Docs Link Check** is green; no broken file links or anchors across `**/*.md`.

---

## Decision

-   **Approve** only if **all Required checks are green** and **coverage thresholds are met**.
-   **Request changes** for: coverage shortfalls, RTM gaps, ADR lint issues, or broken links.
-   **No waivers in PR**; follow formal concession/waiver policy if applicable (ISO 10007 · 12207).

---

### Handy Paths

-   Thresholds: `docs/compliance/coverage-thresholds.json`
-   Coverage HTML: `artifacts/coverage/index.html` (PR run)
-   Summary: `artifacts/coverage-summary.md` (PR run)
-   RTM mapping: `docs/traceability.yaml`
-   ADR index: `docs/adr/INDEX.md`
-   Workflows: `.github/workflows/coverage-gate.yml`, `docs-link-check.yml`, `traceability-gate.yml`, `adr-lint.yml`
