# ADR: Bind/Unbind LabVIEW Development Mode via Composite Helper

- **ID**: ADR-2025-003  
- **Status**: Accepted  
- **Date**: 2025-11-20

## Context
Setting LabVIEW “development mode” differs by bitness and host state (INI tokens, packed libs, installed LV versions). Manual use of `Set_Development_Mode.ps1` / `RevertDevelopmentMode.ps1` and ad-hoc tasks leaves no machine-readable status, inconsistent token cleanup, and weak recovery. BIND-001..BIND-014 require deterministic bind/unbind, JSON status, dry-run support, and scoped INI changes.
We need a repeatable way to point LabVIEW at the repo source (via LocalHost.LibraryPaths), remove stale packed libraries so edits/tests use source, and then cleanly unbind to avoid cross-repo side effects. The composite makes this state explicit, auditable, and safe (dry-run/force), instead of ad-hoc toggling.

## Options
- **A** — Composite action + helper that inspects LocalHost.LibraryPaths per bitness, applies set/revert with safety checks, emits JSON + human-readable summaries, supports dry-run/force, and removes tokens on unbind. (Pros: automatable, traceable, meets BIND requirements; Cons: more code surface to maintain.)
- **B** — Keep the existing scripts and VS Code tasks without orchestration. (Pros: minimal change; Cons: no status JSON, easy to leave stale tokens/packed libs, harder CI/task integration.)
- **C** — Rely only on CI worktrees/build scripts; leave local dev-mode manual. (Pros: smallest footprint; Cons: poor local ergonomics, no guarantees on INI state.)

## Decision
Choose **Option A**. Standardize on `scripts/bind-development-mode` backed by `BindDevelopmentMode.ps1` to: (a) detect LocalHost.LibraryPaths per bitness; (b) bind only when missing/mismatched or packed libs remain; (c) unbind by clearing tokens and running revert; (d) emit JSON + console summaries with exit codes; (e) support dry-run and force to guard cross-repo tokens; (f) write outputs to a predictable path for CI/tasks.

## Consequences
- **+** Deterministic, auditable dev-mode binding across bitness with JSON for CI/tasks.
- **+** Scoped token handling protects other repos; dry-run aids safety.
- **–** More helper/composite code to maintain (and JSON schema to keep stable).
- **–** Requires g-cli and LV INI availability; skipped gracefully but still a dependency.

## Follow-ups
- [ ] Wire VS Code/CI tasks to call the composite and upload the JSON artifact. (Dev/CI)
- [ ] Add tests/lints for JSON schema and BIND requirement coverage. (QA/Automation)
- [ ] Document usage and failure modes in `docs/ci` or `docs/requirements`. (Docs)

> Traceability: BIND-001..BIND-014; scripts: `scripts/bind-development-mode/BindDevelopmentMode.ps1`; helpers: `scripts/set-development-mode/Set_Development_Mode.ps1`, `scripts/revert-development-mode/RevertDevelopmentMode.ps1`.

