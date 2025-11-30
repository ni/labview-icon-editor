# Release Audit Checklist — FCA / PCA

> Cite: ISO 10007 — Audit/Status_Accounting; 12207 — Release/Verification; 15289 — Reports; 29119‑2 — Exit_Criteria

## A. Pre‑audit (Administrative)

-   [ ] Tag **vX.Y.Z** exists on target commit; CHANGELOG entry present.
-   [ ] Required checks green on default branch: Coverage / Docs / Traceability / ADR.
-   [ ] Release run completed (workflow: _Semver Release (Coverage Gate + Binaries)_).

## B. FCA — Functional Configuration Audit

-   [ ] RTM complete for scope; all in‑scope reqs have **Tests** and **Code** links (see `docs/traceability.yaml`).
-   [ ] Test results present (CI logs) and **exit criteria met**: total line ≥ 75%, total branch ≥ 60% (see `docs/compliance/coverage-thresholds.json`).
-   [ ] Coverage evidence attached: `artifacts/coverage/index.html`, `coverage.xml` (Cobertura totals recorded in `Release-Record.md`).
-   [ ] Any waivers/concessions documented (link ADR or waiver note).

## C. PCA — Physical Configuration Audit

-   [ ] Release assets present and named canonically:
    -   `x-cli-linux-x64-<ver>` · `x-cli-win-x64-<ver>.exe`
    -   `artifacts/coverage/Cobertura.xml` · `artifacts/coverage/index.html`
    -   `docs/compliance/Release-Record.md`
-   [ ] **Version string** of binaries equals `<ver>` (tag without `v`) via `--version`.
-   [ ] Optional (if used): SBOM/signature/hashes recorded.
-   [ ] Links in Release page resolve (CI link‑check covers docs; spot‑check release assets).

## D. Outcome

-   [ ] **PASS** FCA/PCA
-   [ ] **FAIL** (list non‑conformances and dispositions in Audit Record)
