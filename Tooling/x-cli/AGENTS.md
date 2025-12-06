# Repository Guidelines

## Project Structure & Module Organization
Core CLI code lives under `src/XCli`; `Program.cs` wires command handlers in `Cli/` and feature folders such as `Simulation/`, `Logging/`, and `Upper/`. Requirement registry APIs live in `src/SrsApi`. .NET test suites mirror the layout under `tests/XCli.Tests` with shared utilities in `tests/TestUtil`. Python-based contract and telemetry tooling sits in `tests/__ci__`. Specs, compliance guides, and architecture notes live in `docs/`, while automation helpers and QA scripts reside in `scripts/`.

## Build, Test, and Development Commands
- `./scripts/qa.sh` (POSIX) or `pwsh ./scripts/qa.ps1` (Windows) runs repository static checks, builds every project, and executes contract tests. CI does not rely on local pre-commit; pre-commit is optional for developer machines only.
  - Default behavior: runs tests serially to avoid cross-test interference.
  - Enable parallel tests by setting `QA_ENABLE_PARALLEL=1` (or `true|yes|on`).
  - Force serial explicitly with `-NoParallel`.
- `dotnet build XCli.sln -c Release` produces release binaries for the CLI and supporting libraries.
- `dotnet test XCli.sln -c Release` runs the xUnit suites; add `--collect:"XPlat Code Coverage"` when Cobertura output is required.
- `python scripts/generate-traceability.py` refreshes the SRS <-> test matrix prior to review.

### Telemetry Standardization (C#)
- Prefer the built-in CLI for telemetry operations:
  - Summarize: `dotnet run -- telemetry summarize --in artifacts/qa-telemetry.jsonl --out telemetry/summary.json [--history telemetry/qa-summary-history.jsonl]`
  - Write: `dotnet run -- telemetry write --out artifacts/qa-telemetry.jsonl --step <name> --status pass|fail [--duration-ms N] [--meta k=v]`
  - Gate: `dotnet run -- telemetry check --summary telemetry/summary.json --max-failures <N>`
- The QA pipeline already calls the summarizer (see `scripts/qa.ps1` step `qa-telemetry-summarize`).
- Optional gate: set `MAX_QA_FAILURES` before running QA to fail the run if total failures exceed the threshold.
- Optional per-step gates: set `MAX_QA_FAILURES_STEP="stepA=N,stepB=N"` before running QA.
- Optional schema validation: set `QA_VALIDATE_SCHEMA=1` locally, or pass `validate_schema: true` to Stage 1 (or set repo var `VALIDATE_TELEMETRY_SCHEMA=1`).
- Docs: see `docs/cli/telemetry.md`.

## Coding Style & Naming Conventions
`.editorconfig` enforces UTF-8, LF endings, trailing newline, and four-space indentation. Use PascalCase for types and public members, camelCase for locals, and `_camelCase` for private readonly fields. Keep analyzers happy with `dotnet format XCli.sln`. Developers may use `pre-commit run --all-files` locally, but CI runs the underlying linters and repo checks directly.

## Testing Guidelines
Target .NET 8 with xUnit. Place new tests alongside the feature under `tests/XCli.Tests` and name methods `MethodUnderTest_Scenario_Expectation`. Run `python -m pytest tests -q` whenever Python automation changes. Maintain coverage floors (>=75% line, >=60% branch); coordinate updates to `docs/compliance/coverage-thresholds.json` with compliance owners before merging.

## Commit & Pull Request Guidelines
Commits follow the two-line template: a <=50 character summary followed by ``codex: <change_type> | SRS: <ids>@<spec-version> | issue: #<n>`` when applicable. Keep branches clean and group atomic changes together. PR descriptions must include the Codex metadata JSON, Agent Checklist, and digest lines for any AGENTS snippets touched. Link impacted SRS IDs, summarize validation evidence, and attach Stage 1 telemetry (e.g., `./scripts/qa.sh` results) so downstream stages can reuse artifacts without rework.

## External CI Access
- When asked to review a private GitHub Actions run, use the helper in `docs/ci/github-actions-annotations.md` (PowerShell script under `scripts/ghops/tools/get-run-annotations.ps1`) to fetch annotations if you have access. If you do not, reply with the short request template in that doc so the user can provide the minimal JSON/logs needed.

## External GitHub Issue Access
- Preferred: use `gh` with repo context to read issues. Example: `gh issue view 768 --repo LabVIEW-Community-CI-CD/x-cli --json title,body,labels,assignees,state,url`.
- Token setup: authenticate with `gh auth login` or export `GH_TOKEN`/`GITHUB_TOKEN` (scopes: `repo`, `read:org` if needed). See `docs/ci/token-awareness.md`.
- If access is denied (404/403), send this concise request template:
  - “I can’t access issue <number> in <owner/repo> (permission 404/403). Please paste the following so I can proceed:
    - Title
    - Summary/problem statement
    - Acceptance criteria (bullets or Given/When/Then)
    - Repro/steps and expected vs. actual
    - Constraints or scope limits (out-of-scope, deadlines)
    - Links to related PRs/runs/logs (if any)
    - Priority/labels/milestone (optional)
  - If available, include any failure logs or screenshots relevant to the issue.”
- When details arrive, restate them as a brief spec and confirm assumptions before implementing.

## Branch Naming & Protection
- Feature branches: use `feat/<topic>` or `feature/<topic>` (e.g., `feat/parser-rewrite`).
- Main branch: `main` carries full protections and required checks.
- Feature branches: a light ruleset applies (currently requires `YAML Lint / lint`).
- Source of truth: `docs/settings/branch-protection.expected.json` defines patterns under `feature_branch_patterns` and expected checks under `feature_expected_required_checks`.
- Verification: `scripts/tests/BranchProtection.Tests.ps1` validates that sample `feat/*` and `feature/*` branches receive the expected checks using `scripts/ghops/tools/branch-protection-awareness.ps1`.
- If you add or change patterns, update the expectation JSON and re-run `pwsh ./scripts/qa.ps1` (or the targeted script test) to validate.

## Shell Tips (PowerShell/Bash)
- Find a section line in a file (PowerShell):
  - `pwsh -NoProfile -Command "$p=''AGENTS.md''; $m = Select-String -Path $p -SimpleMatch ''## External GitHub Issue Access'' | Select-Object -First 1; if ($m) { ''{0}:{1}'' -f $p, $m.LineNumber }"`
- Same, POSIX shells (ripgrep fallback):
  - `rg -n -S "^## External GitHub Issue Access$" AGENTS.md | head -1`
- Avoid complex nested quoting in `-Command`; prefer `Select-String` + `-f` formatting over `"$($var)"` inside one-liners.
- Compute SHA256 digest (PowerShell):
  - `pwsh -NoProfile -Command "$p=''AGENTS.md''; $h=(Get-FileHash -Algorithm SHA256 -Path $p).Hash; ''{0} digest: SHA256 {1}'' -f $p,$h"`
- Compute SHA256 digest (POSIX):
  - `shasum -a 256 AGENTS.md | awk '{print "AGENTS.md digest: SHA256 "$1}'`
- View a GitHub issue (gh):
  - `gh issue view 768 --repo LabVIEW-Community-CI-CD/x-cli --json title,body,labels,state,url`
- Issue view via REST (POSIX):
  - `curl -sSf -H "authorization: token $GH_TOKEN" -H 'accept: application/vnd.github+json' https://api.github.com/repos/LabVIEW-Community-CI-CD/x-cli/issues/768 | jq '{title,state,labels:([.labels[].name]),url,body}'`
- Branch protection awareness (PowerShell):
  - `pwsh -NoProfile -File scripts/ghops/tools/branch-protection-awareness.ps1 -Repo 'LabVIEW-Community-CI-CD/x-cli' -Branch 'feat/smoke' -Json`
- Run targeted Pester (PowerShell):
  - `pwsh -NoProfile -Command "Import-Module Pester; Invoke-Pester -CI -Output Detailed -Script 'scripts/tests/BranchProtection.Tests.ps1'"`
- Search repo (ripgrep, ignore .git):
  - `rg -n --hidden --glob '!.git' -S "feature_branch_patterns|feature_expected_required_checks"`

- Safely prune merged branches (aware of protected deletions):
  - `pwsh -NoProfile -File scripts/ghops/tools/prune-branches.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -Base develop -DryRun`
  - Remove `-DryRun` to actually delete. Skips branches protected by rulesets (deletion restricted) or with open PRs and reports what was skipped.

- Normalize local workspace (idempotency):
  - Stash UNSTAGED changes only: `pwsh -NoProfile -File scripts/ghops/tools/clean-unstaged.ps1`
  - Discard UNSTAGED (keep staged), preview first: `pwsh -NoProfile -File scripts/ghops/tools/clean-unstaged.ps1 -Mode discard -IncludeUntracked -DryRun`
  - Execute discard (destructive): `pwsh -NoProfile -File scripts/ghops/tools/clean-unstaged.ps1 -Mode discard -IncludeIgnored -Force`

- Local-only linter (dev machines only):
  - `pwsh -NoProfile -File scripts/dev/lint-local.ps1 [-Fix]`
  - Runs yamllint, dotnet format, Python ruff/flake8 (if available), and PSScriptAnalyzer.

- Local CI (post-commit hook):
  - Install: `pwsh -NoProfile -File scripts/dev/install-git-hooks.ps1 -Enable`
  - Uninstall: `pwsh -NoProfile -File scripts/dev/install-git-hooks.ps1 -Disable`
  - Hook runs: `scripts/dev/run-local-ci.ps1` after each commit; writes `artifacts/local-ci-summary.md`.
