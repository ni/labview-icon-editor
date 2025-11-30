# Orchestration CLI Standardization Plan

Goal: move common PowerShell-driven workflows into a consistent .NET CLI surface with uniform arguments, timing (`[T+Xs Δ+Yms]`), exit codes, and JSON output. This simplifies local/CI usage and reduces bespoke task wiring.

Repo structure guardrail: keep orchestration/tooling at the repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`) and shared modules under `src/tools/` with thin loaders under `tools/` as needed per `docs/adr/ADR-2025-011-repo-structure.md`. New shared modules should land in `src/tools/` to keep managed CLI preflights and path resolution stable.

## Candidate workflows

- Dev mode bind/unbind: manage LocalHost.LibraryPaths tokens; status JSON; optional force/rebind.
- VI Analyzer: run `Invoke-VIAnalyzer.ps1`/wrapper; return analyzer exit code plus manifest/log paths.
- Missing-in-project check: drive `RunMissingCheckWithGCLI.ps1`; emit missing items list JSON.
- Unit tests (LUnit): drive run-unit-tests; expose junit path and pass/fail exit codes.
- Close LabVIEW / cleanup: ensure no LabVIEW instances running; useful as a pre/post action.
- VIPM packaging: wrap VIPM build (already partially in IntegrationEngineCli); standardize flags/output.
- Restore packaged sources: run `RestoreSetupLVSource` with token guard; skip when not bound.
- Apply dependencies (VIPC): invoke existing apply-deps flow with consistent flags/timeouts.

## Status

| Workflow                  | Status        | Notes                                                                                  |
|---------------------------|---------------|----------------------------------------------------------------------------------------|
| Dev mode bind/unbind      | completed     | Subcommands in OrchestrationCli (pwsh wrappers) with JSON envelope/tests (owner: codex). |
| VI Analyzer               | completed     | `vi-analyzer` subcommand shells RunWithDevMode.ps1; JSON envelope/tests in place (owner: codex). |
| Missing-in-project check  | completed     | `missing-check` subcommand wraps RunMissingCheckWithGCLI; JSON envelope/tests in place (owner: codex). |
| Unit tests (LUnit)        | completed     | `unit-tests` subcommand shells run-unit-tests/RunUnitTests.ps1; JSON envelope/tests in place (owner: codex). |
| Close LabVIEW / cleanup   | completed     | `labview-close` subcommand calls QuitLabVIEW via close script; JSON envelope/tests in place (owner: codex). |
| VIPM packaging            | completed     | `package-build` subcommand calls IntegrationEngineCli; flags/output aligned with JSON envelope (owner: codex). |
| Restore packaged sources  | completed     | `restore-sources` subcommand drives g-cli + RestoreSetupLVSourceCore.vi with token guard (no legacy delegate); JSON/timeouts handled (owner: codex). |
| Apply dependencies (VIPC) | completed     | `apply-deps` subcommand wraps task-verify-apply-dependencies with JSON envelope/tests (owner: codex). |

## Next steps (wrap-up)

1) Finalize and publish the CLI contract (args/exit codes/JSON schema) for all subcommands; align with log-stash expectations; sign-off owner: codex.
2) Point VS Code tasks to the new subcommands (`apply-deps`, `restore-sources`, `labview-close`, `unit-tests`, `vi-analyzer`, `missing-check`, `package-build`) and keep PS scripts as thin delegates; owner: codex. **Done (tasks.json updated).**
3) Add a short consumer README under `Tooling/dotnet/OrchestrationCli/` summarizing commands/flags and JSON envelope shape; owner: codex. **Done (README added).**

## CLI contract (published)

Envelope (all subcommands):
- Common flags: `--repo`, `--bitness (both|64|32)`, `--lv-version` (where applicable), `--pwsh`, `--timeout-sec`, `--plain` (reserved), `--verbose`.
- Timing/logging: stdout lines prefixed `[cmd][(T+Xs Δ+Yms)]`; JSON array printed at end; exit 0 only when all commands succeed.
- JSON shape: `{ "command": "...", "status": "success|fail|skip", "exitCode": int, "durationMs": int, "details": { ... } }`.
- Log-stash alignment: include `scriptPath`, inputs (bitness, lvVersion, project/request), and stdout/stderr so log-stash helpers can capture paths and diagnostics.

Subcommands:
- `devmode-bind` / `devmode-unbind`
  - Args: `--repo`, `--bitness`, `--lv-version`, `--pwsh`; bind forces token add.
  - Details: `{ bitness, mode, lvVersion, scriptPath, exit, stdout, stderr }`.
  - Exit: 0 on success, nonzero on failure.
- `apply-deps`
  - Args: `--repo`, `--bitness`, `--vipc-path` (default `runner_dependencies.vipc`), `--lv-version?`, `--timeout-sec`.
  - Details: `{ bitness, vipcPath, lvVersion, scriptPath, exit, stdout, stderr }`.
  - Exit: 0 on success; nonzero on VIPM/g-cli errors.
- `restore-sources`
  - Args: `--repo`, `--bitness`, `--lv-version`, `--timeout-sec` (default 20).
  - Details: `{ bitness, lvVersion, viPath, projectPath, tokenPresent, gcliExit, stdout, stderr, connectionIssue }`; `status=skip` when token absent or g-cli cannot connect.
  - Exit: 0 on success/skip; nonzero on failure.
- `labview-close`
  - Args: `--repo`, `--bitness`, `--lv-version`, `--timeout-sec`, `--pwsh`.
  - Details: `{ bitness, lvVersion, scriptPath, closed, exit, stdout, stderr }`.
  - Exit: 0 when closed or not running; nonzero on failure.
- `vi-analyzer`
  - Args: `--repo`, `--bitness`, `--request` (default `configs/vi-analyzer-request.sample.json`), `--timeout-sec`, `--pwsh`.
  - Details: `{ bitness, requestPath, scriptPath, exit, stdout, stderr }`.
  - Exit: mirrors script exit (analyzer exit code).
- `missing-check`
  - Args: `--repo`, `--bitness`, `--project` (default `lv_icon_editor.lvproj`), `--lv-version`, `--timeout-sec`, `--pwsh`.
  - Details: `{ bitness, lvVersion, projectPath, scriptPath, exit, stdout, stderr }`.
  - Exit: mirrors script exit (0 none missing, 2 missing, >2 error).
- `unit-tests`
  - Args: `--repo`, `--bitness`, `--project` (default `lv_icon_editor.lvproj`), `--lv-version`, `--timeout-sec`, `--pwsh`.
  - Details: `{ bitness, lvVersion, projectPath, scriptPath, exit, stdout, stderr }`.
  - Exit: mirrors RunUnitTests.ps1 exit (0 pass, nonzero on failures/errors).
- `package-build`
  - Args: IntegrationEngineCli flags via `--repo`, `--ref`, `--bitness`, `--lvlibp-bitness`, `--major|--minor|--patch|--build`, `--company`, `--author`, `--labview-minor`, `--run-both-bitness-separately`, `--managed?`, `--pwsh`, `--timeout-sec`.
  - Details: `{ repo, refName, bitness, lvlibpBitness, version:{...}, company, author, labviewMinor, managed, runBothBitnessSeparately, projectPath, exit, stdout, stderr }`.
  - Exit: 0 on success; nonzero on failure.

## Owners & timeline (wrap-up)

- Lead / coordinator: codex (interim), target: contract sign-off and task wiring this week.
- All subcommands: Owner codex; status: completed in CLI with JSON/test coverage.
- VS Code task updates and README: Owner codex; target: same week as contract sign-off.

After wrap-up: integrate VS Code tasks, publish README, and deprecate direct PS entrypoints gradually.

## Deprecation glide path (PS entrypoints)

1) Default callers to the orchestration CLI (done): VS Code tasks and docs point to `apply-deps`, `restore-sources`, `labview-close`, `unit-tests`, `vi-analyzer`, `missing-check`, `package-build`; PS scripts remain as delegates.
2) Add deprecation warnings to PS wrappers: emit a one-line notice in each script pointing to the corresponding CLI subcommand; behavior unchanged.
3) Documentation: note in `scripts/README` (or script headers) and this plan that the CLI is the supported entrypoint and PS scripts are legacy delegates. **Done.**
4) Telemetry/trace: add a lightweight log line (“legacy-ps”) from PS wrappers to track remaining usage and inform removal timing.
5) Staged removal: after a grace period, flip PS wrappers to invoke the CLI with a warning, then remove/archive them once usage drops.
