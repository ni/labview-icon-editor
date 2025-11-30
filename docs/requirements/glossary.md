# Glossary (ISO/IEC/IEEE 29148 aligned)

- **fail-closed** — default to failure/deny when a dependency or check cannot be completed; no changes are applied.
- **no-op** — an execution path that performs zero state changes (files, tags, releases) and records the decision.
- **protected branch** — branch/ruleset that enforces required status checks and restricts direct pushes (e.g., main, develop, release/*).
- **prerelease** — version intended for non-GA use (alpha/beta/rc); version string carries suffix, tags do not.
- **idempotent** — repeated execution with the same inputs produces no additional state changes (same tags/releases/config).
- **manifest** — structured JSON source of truth for CLA entries (github, cla_type, cla_version, signed_on, status, evidence_ref).
- **dry-run/report-only** — executes detection/validation and produces logs/JSON but makes no file/INI/tag/release modifications.
- **scope guard** — check that limits mutations to the provided repository_path/boundary unless an explicit Force override is set.
