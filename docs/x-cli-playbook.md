# x-cli Playbook (LabVIEW Icon Editor)

Purpose: this repo is the upstream for x-cli. Use this guide to run x-cli here, and for consumers to vendor/pin binaries from this source.

## Quick entry points

- Wrapper (preferred): `pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- --help`
- VS Code tasks: `20 Build: Source Distribution`, `21 Verify: Source Distribution`, `08 x-cli: VI Analyzer`, `09 x-cli: VI History`, locked Ollama tasks `30/31/32/32b`.
- Minimal env: run from repo root; temp/log paths are set by the wrapper/tasks; avoids stale processes.

## Core flows

- Build SD (g-cli default): task 20 → `source-dist-build --repo . --commit-index builds/cache/commit-index.json --verbose-git --perf-cpu --allow-dirty`. Artifacts under `builds/`.
- Verify SD: task 21 → `source-dist-verify --repo . --source-dist-log-stash --source-dist-strict`.
- VI Analyzer: task 08 → `vi-analyzer-run --request configs/vi-analyzer-request.sample.json`; requires devmode bind. Output: `tests/results/_agent/vi-analyzer/<label>/`.
- VI History replay: task 09 → `vi-compare-run --request configs/vi-compare-run-request.sample.json`; requires devmode bind. Output: `.tmp-tests/vi-compare-replays/…` + `vi-comparison-summary.json`.

## SD→PPL and SD consumption

- Local SD→PPL handoff: `configs/x-cli/local-sd-ppl.json` + `scripts/orchestration/Run-LocalSd-Ppl.ps1` → emits `builds/artifacts/labview-icon-api.zip`, `artifacts/labview-icon-api.ppl`, and `artifacts/labview-icon-api-handshake.json`.
- Docker SD harness: `configs/x-cli/consume-sd-docker.json` + `scripts/orchestration/Run-ConsumeSd-DockerHarness.ps1` / `ConsumeSdInContainer.ps1` to validate handshake inside Docker Desktop.

## Log replay and diff (regressions)

- Deterministic output: `x-cli log-replay --from <capture.jsonl>` to mirror prior run output/timing.
- Timing drift: `x-cli log-diff --baseline <A.jsonl> --candidate <B.jsonl> --format text --by test` to compare elapsed per test or overall.

## Telemetry checks (fast gate)

- Validate shape: `x-cli telemetry validate --events --schema` and `--summary --schema` on `artifacts/qa-telemetry.jsonl` and `telemetry/summary.json`.
- Quick health: `x-cli telemetry check --summary telemetry/summary.json` (ensures required fields present).

## Telemetry helper pipeline

- Script: `scripts/telemetry/Invoke-TelemetryPipeline.ps1` appends one event, summarizes, and gates failures.
- Usage example: `pwsh -NoProfile -File scripts/telemetry/Invoke-TelemetryPipeline.ps1 -Step source-dist-build -Status pass -DurationMs 120000 -MaxFailures 0 -Stage build -Runner gcli -Artifacts builds/artifacts/source-distribution.zip -MarkdownPath artifacts/telemetry-summary.md`.
- Options: `-EventsPath` (default `artifacts/qa-telemetry.jsonl`), `-SummaryPath` (default `telemetry/summary.json`), `-HistoryPath` for roll-up, `-Meta @{runner='gcli';bitness='64'}`, `-MaxFailuresPerStep @{"vi-analyzer"=0}`, `-SchemaEventsPath` (default v2), `-SchemaSummaryPath`, `-MarkdownPath` to emit a brief summary.

### Wrap any command with telemetry (build/verify gating)

- Script: `scripts/telemetry/Run-Command-With-Telemetry.ps1` runs a command, records pass/fail + duration, then calls the telemetry pipeline with `MaxFailures=0` (configurable).
- Example: `pwsh -NoProfile -File scripts/telemetry/Run-Command-With-Telemetry.ps1 -Step source-dist-build -Command dotnet -CommandArgs @('run','--project','Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj','--','source-dist-build','--repo','.')`.
- Adjust `-MaxFailures`, `-MaxFailuresPerStep`, and `-Meta @{runner='gcli';bitness='64'}` as needed. The wrapper exits with the wrapped command’s exit code so CI/tasks can fail fast.

## Safety and env notes

- Set `XCLI_ALLOW_PROCESS_START=1` only for commands that need to spawn processes (Analyzer, History); leave unset otherwise to honor IsolationGuard.
- Prefer task 06/06b devmode bind/unbind to manage LocalHost.LibraryPaths; unbind when switching worktrees.
- Keep TMP/TEMP writable (wrapper sets them). Avoid editing tasks to run x-cli directly unless you reproduce those env settings.

## Packaging x-cli itself (if pinning a version)

- Build/test: `dotnet build XCli.sln -c Release` + `dotnet test XCli.sln -c Release`.
- Normalize artifacts: `scripts/build.ps1` → `dist/x-cli-win-x64`, `dist/x-cli-linux-x64`.
- Pack: `scripts/pack-cli.ps1` → `package/` (NuGet-style) if you need to distribute a fixed revision.
- Consumers: download the dist outputs or NuGet package from releases/tags in this repo and pin to that version; no vendored copy is tracked elsewhere.

## Helpful paths

- Configs: `configs/x-cli/*.json` (runners, SD/PPL handoff, docker harness).
- Wrapper: `scripts/common/invoke-repo-cli.ps1` (sets repo env, temp/log roots, clears stale x-cli processes).
- Tasks reference: `docs/vscode-tasks.md`.
