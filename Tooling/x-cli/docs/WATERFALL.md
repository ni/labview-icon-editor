# Waterfall Process (Canonical)
> **Canonical source** — This is the authoritative document for the multi-stage pipeline (Requirements → Design → Implementation → Testing → Deployment). Any other WATERFALL.md is a stub that points here.

<!-- Required anchors for gate: -->
<!-- ANCHOR:final-orchestration -->
## Final orchestration (auto-advance)
_This section remains the single source of truth for stage criteria and automation references._

<!-- ANCHOR:criteria -->
### Stage criteria (objective)
- Requirements → Design: SRS index exists and SRS smoke passes (if present).
- Design → Implementation: `docs/Design.md` exists and includes `Status: Approved`.
- Implementation → Testing: required CI contexts (Linux/Windows) and overall status are green.
- Testing → Deployment: Stage 2 artifacts available (e.g., `water-stage2-artifacts`) and checks green.

<!-- ANCHOR:workflows -->
### Workflows & scripts implementing orchestration
- `.github/workflows/waterfall-advance.yml`
- `.github/workflows/validate-waterfall-state.yml`
- `.github/workflows/waterfall-stuck-alert.yml`
- `scripts/waterfall_state.py`, `scripts/waterfall_artifacts.py`

> Note: This consolidation resolves the prior duplication between root `WATERFALL.md` and `docs/WATERFALL.md`.

<!-- ANCHOR:orchestration-handler -->
**Automation handlers:**
- `.github/workflows/waterfall-advance.yml` shall advance stages and warn on missing `water-stage2-artifacts` (FGC-REQ-CI-014, FGC-REQ-CI-015).
- `.github/workflows/validate-waterfall-state.yml` shall validate state labels and entry prerequisites (FGC-REQ-CI-002).
- `.github/workflows/waterfall-stuck-alert.yml` shall comment on green but stalled pull requests (FGC-REQ-CI-015).

<!-- ANCHOR:stage-exit-criteria -->
**Stage exit criteria:**
- Design shall include `docs/Design.md` with `Status: Approved` (FGC-REQ-CI-014).
- Implementation shall report green Linux and Windows checks (FGC-REQ-CI-014).
- Testing shall publish Stage 2 artifact `water-stage2-artifacts` (FGC-REQ-CI-015).

<!-- ANCHOR:ac-map -->
**Acceptance criteria mapping:**
- FGC-REQ-CI-014 AC1 – lock prior stages and update the `stage:*` label.
- FGC-REQ-CI-014 AC2 – retain the current label when exit criteria fail.
- FGC-REQ-CI-014 AC3 – require design docs and SRS index before advancing.
- FGC-REQ-CI-015 AC1 – warn when `water-stage2-artifacts` is missing.
- FGC-REQ-CI-015 AC2 – comment on green but stalled pull requests.

