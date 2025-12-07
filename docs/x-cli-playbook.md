# x-cli Playbook (LabVIEW Icon Editor)

> **For comprehensive x-cli documentation**, see `docs/x-cli-overview.md` which covers:
> - Platform support (Windows + Linux binaries)
> - Building from source
> - Release process
> - Architecture and troubleshooting

**Purpose**: This repo is the upstream for x-cli. Use this guide for running x-cli workflows in this repository, and for consuming published binaries in other projects.

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

## Packaging x-cli itself (for pinning a version to other projects)

> **Note**: Release binaries for **both Windows and Linux** are published with every tag.

### Build from Source

```powershell
# Navigate to x-cli directory
cd Tooling/x-cli

# Build and test
dotnet build XCli.sln -c Release
dotnet test XCli.sln -c Release

# Create platform-specific binaries (both Windows AND Linux)
pwsh scripts/build.ps1 -Version 1.0.0
# Outputs:
#   dist/x-cli-win-x64          (Windows executable)
#   dist/x-cli-linux-x64        (Linux executable)

# (Optional) Create NuGet package containing both binaries
pwsh scripts/pack-cli.ps1 -Version 1.0.0
# Outputs:
#   package/*.nupkg
```

### Download Pre-built Binaries

**Recommended for consumers**: Download from [GitHub Releases](https://github.com/svelderrainruiz/labview-icon-editor/releases)

Each release includes:
- `x-cli-win-x64` - Windows 64-bit executable (no .NET Runtime required)
- `x-cli-linux-x64` - Linux 64-bit executable (no .NET Runtime required)
- `checksums.sha256` - SHA256 hashes for verification
- `*.nupkg` - NuGet package (optional, contains both binaries)

**Usage**:
```bash
# Download and verify checksum
curl -LO https://github.com/svelderrainruiz/labview-icon-editor/releases/download/v1.0.0/x-cli-linux-x64
curl -LO https://github.com/svelderrainruiz/labview-icon-editor/releases/download/v1.0.0/checksums.sha256
sha256sum -c checksums.sha256 --ignore-missing

# Make executable (Linux only)
chmod +x x-cli-linux-x64

# Run
./x-cli-linux-x64 --help
```

**Pinning strategy**:
- Download specific version binaries from releases
- Commit to your project's `tools/` or `.local/bin/` directory
- Add to `.gitignore` and document download process, OR
- Commit binaries and use Git LFS for large files

No vendored copy is tracked in this repository - download from releases or build from tagged source.

## Helpful paths

- Configs: `configs/x-cli/*.json` (runners, SD/PPL handoff, docker harness).
- Wrapper: `scripts/common/invoke-repo-cli.ps1` (sets repo env, temp/log roots, clears stale x-cli processes).
- Tasks reference: `docs/vscode-tasks.md`.
