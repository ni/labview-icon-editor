# Repository Guidelines

## Project Structure & Module Organization
Core CLI code lives under `src/XCli` (e.g., `Cli/`, `Logging/`, `Simulation/`, `Util/`). Tests mirror the layout under `tests/XCli.Tests` with shared helpers in `tests/TestUtil`. Specs and architecture notes live in `docs/`. Automation helpers and QA scripts reside in `scripts/`.

## Build, Test, and Development Commands
- `./scripts/qa.sh` or `pwsh ./scripts/qa.ps1` runs static checks, builds, and tests. Pre-commit is optional for local use.
  - Defaults to serial tests to avoid cross-test interference.
  - Enable parallel with `QA_ENABLE_PARALLEL=1` (or `true|yes|on`).
  - Force serial explicitly with `-NoParallel`.
- `dotnet build XCli.sln -c Release` builds CLI and libraries.
- `dotnet test XCli.sln -c Release` runs xUnit suites.
- `python scripts/generate-traceability.py` refreshes the SRS mapping.

## Coding Style & Naming Conventions
Use `.editorconfig` defaults (UTF‑8, final newline, 4‑space indent). PascalCase for types/members, camelCase for locals, `_camelCase` for private readonly. Keep analyzers happy via `dotnet format`. Developers may run `pre-commit` locally.

## Testing Guidelines
Target .NET 8 with xUnit. Name tests `Method_Scenario_Expectation`. Keep CLI output stable; prefer explicit asserts. Maintain coverage floors (75% line / 60% branch) and update compliance docs when thresholds change.

## Commit & Pull Request Guidelines
Commits follow the two-line template:
`<summary (<=50 chars)>` then `codex: <change_type> | SRS: <ids>@<spec-version> | issue: #<n>` when applicable. PRs include Codex metadata JSON, the Agent Checklist, and AGENTS.md digest lines. Link impacted SRS IDs and attach Stage 1 telemetry.

---
Feedback: Initial template render — please note any missing sections or confusing phrasing.
