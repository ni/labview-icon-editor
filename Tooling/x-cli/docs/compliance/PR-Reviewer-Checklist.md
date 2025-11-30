# PR Reviewer Checklist — Definition of Done (DoD)

_Edition‑agnostic citations use bracketed titles; see Standards — Edition Appendix for pins._

---

## A) 60‑Second Triage (Required checks must be **green**)

-   **Required status checks** (branch protection):
    **PR Coverage Gate / coverage** · **Docs Link Check / lychee** · **Traceability Gate / rtm** · **ADR Lint / adr-lint**
    **[10007 — Change control]**
-   **Coverage summary** (`artifacts/coverage-summary.md`) shows **Line ≥ 75%**, **Branch ≥ 60%**, and **no failing files**.
    **[29119‑2 — Test monitoring & control] · [29119‑3 — Test report]**
-   **Artifacts present** on the PR run:
    -   `coverage.xml` (root, Cobertura)
    -   `artifacts/coverage/index.html` (or zipped HTML)
    -   PR comment / Step Summary with coverage table
-   **Traceability OK** (gate green): changed reqs or touched `src/**` have **Req→Test→Code** rows in `docs/traceability.yaml`.
    **[29148 — Traceability]**
-   **ADRs OK** (gate green): ADR filenames/headers valid; `docs/adr/INDEX.md` exists/updated.
    **[42010 — Rationale/Decisions]**
-   **Docs links OK**: link checker green; no broken anchors in `**/*.md`.
    **[15289 — Information items]**

---

## B) Coverage DoD (what to spot quickly)

-   **Merged, cross‑lang** Cobertura: .NET (**XPlat Code Coverage**) + Python (**pytest‑cov**, `--cov-branch`) combined by ReportGenerator into:
    -   `coverage.xml` and `artifacts/coverage/index.html`.
-   **Thresholds enforced**: totals **Line ≥ 75%**, **Branch ≥ 60%**; **file floors** from
    `docs/compliance/coverage-thresholds.json` (look for any red rows in the PR summary).
-   **Per‑stack signals**:
    -   .NET test projects include **coverlet.collector** (via `tests/Directory.Build.props`).
    -   Python has **pytest‑cov** in `tests/requirements.txt`.
        **[29119‑2/‑3]**

---

## C) Traceability DoD (changed reqs / touched code)

-   IDs match `FGC-REQ-[A-Z]+-\d{3,}`; each in‑scope entry has **≥1 test** and **≥1 code path** that resolve.
    **[29148 — Requirements; Traceability]**
-   If gate failed, request: add/update RTM rows or adjust globs to real paths.

---

## D) Architecture & ADR DoD

-   **ADR Lint** green; each new/significant decision is recorded with **H1/Status/Date/Decision/Consequences**, proper numbering, and **Supersedes** integrity; `docs/adr/INDEX.md` updated.
    **[42010 — Rationale] · [15289 — Design description]**
-   If architecture affects the views, ensure **view → ADR cross‑links** exist (Context/Container/Component/Deployment).

---

## E) Documentation DoD

-   **Docs Link Check** green; anchors valid across `**/*.md`.
    **[15289 — Information items]**
-   Keep diffs focused; long design narrative belongs in `docs/Design.md` or ADRs, not PR description.

---

## F) Decision

-   **Approve** only if **all required checks are green** and coverage thresholds met (or raised with ratchet).
-   **Request changes** if any required check is red, coverage below thresholds, RTM gaps, ADR hygiene issues, or broken links.
-   **No waivers in PR**: use a formal concession/waiver path if policy allows.
    **[10007 — Change control] · [12207 — Verification/Transition]**

---

## G) Handy Paths

-   Coverage config: `docs/compliance/coverage-thresholds.json`
-   Coverage summary: `artifacts/coverage-summary.md` (PR run artifacts)
-   RTM: `docs/traceability.yaml` · Gate: `scripts/rtm_verify.py`
-   ADRs: `docs/adr/*.md` · Index: `docs/adr/INDEX.md` · Lint: `scripts/adr_lint.py`
-   Link check: `.github/workflows/docs-link-check.yml` · `.lychee.toml`

> **DoD = Definition of Done**. This checklist operationalizes the DoD gates on PRs.
