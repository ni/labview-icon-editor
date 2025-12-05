# ADR: RequirementsSummarizer Non-Mutating Reports

- **ID**: ADR-2025-008  
- **Status**: Accepted  
- **Date**: 2025-11-26

## Context
Contributors need fast, repeatable summaries of `docs/requirements/requirements.csv` for reviews and CI without risking edits to the source CSV. The tool shall run inside the devcontainer (dotnet 8 + PowerShell) and support filtering/sorting so teams can focus on priority/status slices while emitting Markdown/HTML artifacts for traceability.

## Options
- **A** - Maintain manual spreadsheets or ad-hoc scripts (non-reproducible; high drift risk).
- **B** - Commit static exports manually (stale quickly; no filtering knobs).
- **C** - Provide a read-only CLI that renders summaries with filters/sorts and regenerates artifacts on demand (chosen).

## Decision
- Keep `Tooling/dotnet/RequirementsSummarizer` as a read-only CLI that validates required CSV headers, fails fast when the file is missing, and renders Markdown summaries/tables plus optional HTML/JSON exports. The tool never writes to the CSV; it only reads and writes new artifacts.
- **Interfaces**: key flags include `--csv` (default `docs/requirements/requirements.csv`), `--summary-output`, `--full-output`, `--json-output`, `--html-output`, `--summary-full`, `--details/--details-open`, `--rows <n>`, `--filter-priority <comma list>`, `--filter-status <comma list>`, `--sort <comma fields>`, `--title`, `--repo`, `--section-details`, `--section-details-open`. Example (matches README/task):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli RequirementsSummarizer -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary.md --summary-full --details --details-open`
- **Scope/out-of-scope**: In scope: rendering summaries with filters/sorts and generating Markdown/HTML/JSON outputs under caller-provided paths. Out of scope: editing the CSV, enforcing requirement semantics, or altering source encoding.
- **Verification**: TOOL-001/TOOL-002 (runs in the .NET-enabled devcontainer and emits summary under `reports/`), TOOL-007 (non-mutating read of CSV; exit 0 with Markdown/HTML outputs; checksum unchanged), TOOL-008 (filters/sorts honored so filtered summary has fewer/equal rows and prioritized ordering). Missing CSV causes exit 1 with a clear diagnostic.

## Consequences
- **+** Deterministic, non-mutating reporting enables CI checks and reviewer workflows without risking source drift.
- **+** Flexible filters/sorts reduce noise for focused audits.
- **Risks/mitigations**: Stale generated artifacts (mitigate by regenerating in CI and documenting paths under `reports/`); CSV format changes breaking header validation (mitigate with required header checks and early failures); large CSVs impacting performance (mitigate with filtering and limited `--rows` defaults).

## Follow-ups
- [ ] Add CI task to regenerate summaries (Markdown and HTML) and fail on CSV header regressions.
- [ ] Document checksum-before/after tip in developer docs to reinforce non-mutation expectation.
- [ ] Consider adding unit tests for filter/sort combinations (High priority only, status filters) to guard TOOL-008.
