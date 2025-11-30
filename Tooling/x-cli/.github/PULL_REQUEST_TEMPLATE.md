# PR Reviewer Checklist (Concise)

## A) Scope & Risk
- [ ] Change type: Feature / Fix / Docs / CI / Release / Other: ___
- [ ] Risk: Low / Med / High
- [ ] Tests added/updated for changed code

## B) Required Status Checks (must be green)
- [ ] **PR Coverage Gate / coverage**
- [ ] **Docs Link Check / lychee**
- [ ] **Traceability Gate / rtm** (if `docs/srs/**`, `docs/traceability.yaml`, or `src/**` changed)
- [ ] **ADR Lint / adr-lint** (if `docs/adr/**` or `docs/architecture/**` changed)
- [ ] **DoD Gate / dod** (if policy enforced)
  
CI tip: To run the Pre-Commit workflow in CI (otherwise manual/opt‑in), add label `ci:pre-commit` to this PR. Local `pre-commit` remains the primary path during development.

Docs preview links:

[![Markdown Templates Preview](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates.yml/badge.svg)](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates.yml)
[![Markdown Templates Sessions](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates-sessions.yml/badge.svg)](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates-sessions.yml)

Job summaries for these workflows show “Effective thresholds: TopN, MinCount.” Adjust via repo variables `MD_TEMPLATES_TOPN`/`MD_TEMPLATES_MINCOUNT` when needed.

<details>
<summary>Reviewer Guide — Markdown Templates</summary>

- Preview artifacts: `md-templates-suggestions-rolling-preview`, `md-templates-suggestions-preview`
- Sessions artifacts: `md-templates-suggestions-rolling`, `md-templates-suggestions`
- Job Summary: look for “Rolling window entries: X” and “Rolling Suggestions (last N cycles)”
- History (gh-pages): [blob](https://github.com/LabVIEW-Community-CI-CD/x-cli/blob/gh-pages/telemetry/templates/suggestions.jsonl) · [raw](https://raw.githubusercontent.com/LabVIEW-Community-CI-CD/x-cli/gh-pages/telemetry/templates/suggestions.jsonl)
- Tuning: `MD_TEMPLATES_CYCLE_WINDOW` (default 8), `MD_TEMPLATES_SUGGEST_MINCOUNT` (default 2), `MD_TEMPLATES_INCLUDE_SNIPPETS` (0/1), `MD_TEMPLATES_HISTORY_PUBLISH` (1)

</details>

## Cross-Agent Telemetry & Session Reflection
- First: include your own “Cross-Agent Telemetry Recommendation” block.
- Then: add a brief “Cross-Agent Session Reflection” noting agreement/deltas vs the most recent prior recommendation and any concrete next tweaks (3–5 bullets).
  - Keep it non‑blocking and concise; this establishes continuity without biasing your own recommendation.
 
<details>
<summary>Optional snippet (copy/paste)</summary>

```md
# Cross-Agent Session Reflection (non-blocking)

- Agreements with prior recommendation:
  - ...
- Deltas or deviations (and why):
  - ...
- Concrete next tweaks (3–5 bullets max):
  - ...
```

</details>

Dev tip: If you edited `scripts/ghops/tests/Ghops.Tests.ps1`, run the shim guard locally:
`pre-commit run ghops-shim-guard --files scripts/ghops/tests/Ghops.Tests.ps1`

## Node Tooling (if applicable)
- [ ] For new/updated Node tools (e.g., TypeScript utilities):
  - Use Node 20.x via `actions/setup-node@v4` with npm cache
  - Commit `package-lock.json`; install with `npm ci` (not `npm install`)
  - Validate JSON outputs with PowerShell `Test-Json -SchemaFile`
  - See patterns: `docs/ci/node-patterns.md`

Merge policy note: This repo is squash‑only with auto‑merge. The final commit uses the PR title as the commit title and the PR body as the commit message. Keep the title concise (≤ 50 chars) and the body clear.

## C) Coverage (29119‑2/‑3)
- [ ] Unified **`coverage.xml`** present; **HTML** uploaded (coverage‑html.zip)
- [ ] Totals ≥ thresholds: **line ≥ 75%** (actual: __%), **branch ≥ goal** (actual: __%)
- [ ] File floors met for critical modules (list deficits): ___  
_Evidence:_ Actions run URL / artifact: ___

## D) Requirements & Traceability (29148)
- [ ] Requirement IDs present (e.g., `FGC-REQ-…`) and updated
- [ ] **RTM** row(s) updated (**Req → Test → Code**)  
_Evidence:_ `docs/traceability.yaml` lines: ___

## E) Architecture (42010)
- [ ] Affected **view(s)** updated (Context / Container / Component / Deployment)
- [ ] **ADR** added/updated for decisions; cross‑links present  
_Evidence:_ `docs/architecture/*.md`, `docs/adr/NNNN-*.md`

## F) Configuration Management & Release (10007 / 12207)
- [ ] **CHANGELOG** updated (if user‑visible)
- [ ] SemVer tag plan: none / next `vX.Y.Z`
- [ ] If tagging: release gate re‑runs coverage; binaries + coverage HTML/XML attach

## G) Documentation (15289)
- [ ] Docs updated (Plan / Spec / Report / Procedure as needed)
- [ ] Links & anchors resolve (CI proves)

## H) Definition of Done (DoD)
- [ ] Team DoD satisfied (note exceptions, if any): ___

## I) Reviewer Notes (Obs / Assumptions / Confidence)
- **Observations:** ___
- **Assumptions:** ___
- **Confidence:** High / Med / Low
