# ADR 0023: Internalize codex_rules (no packaging; extract helpers)

- Date: 2025-09-26
- Status: Accepted

## Context

Historically, repo scripts and tests imported Python modules from `codex_rules`.
Editable installs (`pip install -e .`) and wheel metadata occasionally leaked
console entry points (e.g., `codex-rules.exe`) into local PATHs, causing noisy
warnings and drift between CI and developer machines.

## Decision

Treat `codex_rules` as an internal, unshipped helper library:

- Do not package or install it in CI. Avoid editable installs in bootstrap
  scripts; remove tracked `*.egg-info` artifacts.
- Prefer imports from `scripts/lib/*` for functionality used by repo scripts.
  Keep `codex_rules` available for tests and legacy doc samples.
- Add a pre-commit lint to block new `codex_rules` imports from `scripts/` and to
  forbid `pip install -e` usage in repo scripts.

## Implementation (R1)

- Added `scripts/lib/telemetry.py` (existing) and `scripts/lib/storage.py` with
  shims that delegate to `codex_rules` when present, otherwise return safe
  defaults.
- Updated scripts to import internal helpers instead of `codex_rules`:
  `scripts/run_pre_commit.py`, `scripts/finalize_commit_memory.py`,
  `scripts/generate_preventative_measures.py`.
- Removed tracked `codex_rules.egg-info/` files and blocked editable installs in
  `scripts/install_dependencies.sh` and `scripts/setup-venv.sh`.
- Added `scripts/lint_codex_rules_usage.py` and wired it into pre-commit.

## Consequences

- CI and local runs no longer emit PATH warnings for `codex-rules.exe`.
- Tests may continue importing `codex_rules` directly; scripts should import
  from `scripts/lib` to avoid packaging drift.
- Future extractions can move more helpers from `codex_rules` to `scripts/lib`
  until the legacy module is no longer needed by tests.

## Follow-ups

- Extract minimal mapping/guidance helpers used by docs automation into
  `scripts/lib`, update callers, and retire remaining script imports of
  `codex_rules`.
- Keep `codex_rules` source for test coverage until fully migrated.
