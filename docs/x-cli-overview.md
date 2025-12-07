# x-cli Overview

## What is x-cli?

x-cli is a .NET-based command-line tool that provides automated workflows for LabVIEW icon editor development, including:
- **Source Distribution (SD) builds** - Package LabVIEW projects into distributable source distributions
- **VI Analyzer runs** - Run LabVIEW VI Analyzer checks on VIs
- **VI History comparison** - Compare VI metadata and track changes across versions
- **Telemetry tracking** - Record and validate build/test metrics
- **Log replay and diff** - Compare build outputs for regression detection

x-cli is developed and maintained **upstream in this repository** under `Tooling/x-cli/`.

## Platform Support

x-cli produces **native self-contained binaries** for:
- **Windows (x64)**: `x-cli-win-x64` / `XCli.exe`
- **Linux (x64)**: `x-cli-linux-x64` / `XCli`

Both binaries are published with every release and do not require .NET Runtime installation.

## Quick Start

### Using x-cli in this repository

The recommended way to run x-cli is through the wrapper script:
```powershell
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- --help
```

Or use VS Code tasks (see `.vscode/tasks.json` and `docs/vscode-tasks.md`):
- **Task 08**: `x-cli: VI Analyzer`
- **Task 09**: `x-cli: VI History`
- **Task 20**: `Build: Source Distribution`
- **Task 21**: `Verify: Source Distribution`

### Installing x-cli for other projects

Download the latest release binaries from GitHub:
1. Go to [Releases](https://github.com/svelderrainruiz/labview-icon-editor/releases)
2. Download `x-cli-win-x64` or `x-cli-linux-x64`
3. Add to your PATH or invoke directly

## Building x-cli from Source

### Prerequisites
- .NET SDK 8.0.x (see `global.json` for pinned version)
- PowerShell 7+ (for build scripts)
- Git (for version info)

### Build Commands

```powershell
# Build and test (both platforms, from Tooling/x-cli/)
dotnet build XCli.sln -c Release
dotnet test XCli.sln -c Release

# Quick smoke test
dotnet run --project src/XCli/XCli.csproj -- --help

# Create distribution binaries (from Tooling/x-cli/)
pwsh scripts/build.ps1 -Version 1.0.0

# Outputs:
#   dist/x-cli-win-x64          (normalized Windows binary)
#   dist/x-cli-linux-x64        (normalized Linux binary)
#   dist/win-x64/               (full Windows publish output)
#   dist/linux-x64/             (full Linux publish output)
```

### Creating NuGet-style Packages

```powershell
# From Tooling/x-cli/
pwsh scripts/pack-cli.ps1 -Version 1.0.0

# Outputs:
#   package/*.nupkg             (NuGet package with both binaries)
```

## Key Concepts

### Wrapper Script (`invoke-repo-cli.ps1`)

The wrapper script provides:
- **Environment setup**: Sets `XCLI_REPO_ROOT`, temp/log paths
- **Process cleanup**: Kills stale x-cli processes before running
- **Convenience**: Single entry point for all repo CLIs

Always prefer the wrapper over direct invocation in repo contexts.

### Environment Variables

- `XCLI_REPO_ROOT`: Repository root path (auto-set by wrapper)
- `XCLI_ALLOW_PROCESS_START`: Set to `1` to allow process spawning (required for VI Analyzer/History)
- `XCLI_LOG_LEVEL`: Optional log verbosity (Debug, Info, Warn, Error)

### Isolation Guard

x-cli includes an `IsolationGuard` that prevents spawning external processes unless explicitly allowed via `XCLI_ALLOW_PROCESS_START=1`. This is a safety feature to prevent accidental system modifications during builds.

Commands that spawn processes (VI Analyzer, VI History) **require** this environment variable.

## Common Workflows

### Source Distribution Build

Build a LabVIEW source distribution (SD) with manifest and commit index:

```powershell
# Via wrapper (recommended)
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  source-dist-build `
  --repo . `
  --commit-index builds/cache/commit-index.json `
  --verbose-git `
  --perf-cpu

# Direct invocation
./Tooling/x-cli/dist/x-cli-win-x64 source-dist-build --repo . --commit-index builds/cache/commit-index.json
```

Outputs:
- `builds/<yyyy-MM-dd>/<HHmmss>/source-distribution.zip`
- `builds/<yyyy-MM-dd>/<HHmmss>/manifest.json`
- `builds/cache/commit-index.json` (updated)

### Source Distribution Verification

Verify SD contents match expectations:

```powershell
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  source-dist-verify `
  --repo . `
  --source-dist-log-stash `
  --source-dist-strict
```

### VI Analyzer Run

Run LabVIEW VI Analyzer checks (requires LabVIEW + dev-mode bind):

```powershell
# Set environment variable (required for process spawning)
$env:XCLI_ALLOW_PROCESS_START = "1"

# Run via wrapper
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  vi-analyzer-run `
  --request configs/vi-analyzer-request.sample.json
```

Outputs:
- `tests/results/_agent/vi-analyzer/<label>/analysis-results.json`
- `tests/results/_agent/vi-analyzer/<label>/vi-analyzer-report.html`

### VI History Comparison

Compare VI metadata across versions:

```powershell
# Set environment variable (required for process spawning)
$env:XCLI_ALLOW_PROCESS_START = "1"

# Run via wrapper
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  vi-compare-run `
  --request configs/vi-compare-run-request.sample.json
```

Outputs:
- `.tmp-tests/vi-compare-replays/<timestamp>/`
- `vi-comparison-summary.json`

### Telemetry Validation

Validate telemetry event format and summary:

```powershell
# Validate events schema
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  telemetry validate `
  --events artifacts/qa-telemetry.jsonl `
  --schema docs/schemas/x-cli/telemetry.events.v2.schema.json

# Validate summary schema
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  telemetry validate `
  --summary telemetry/summary.json `
  --schema docs/schemas/x-cli/telemetry.summary.v1.schema.json

# Check summary health (required fields present)
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  telemetry check `
  --summary telemetry/summary.json
```

## Release Process

### Automated Release (via GitHub Actions)

1. **Tag-based**: Push a git tag `v1.0.0`
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

2. **Workflow Dispatch**: Trigger `.github/workflows/x-cli-release.yml` manually with version input

Both methods:
- Build Windows and Linux binaries
- Create NuGet-style package
- Generate SHA256 checksums (`dist/checksums.sha256`)
- Upload artifacts to GitHub Release
- Publish release notes

### Manual Release (local)

```powershell
cd Tooling/x-cli

# Build binaries
pwsh scripts/build.ps1 -Version 1.0.0

# Create package
pwsh scripts/pack-cli.ps1 -Version 1.0.0

# Generate checksums
$items = Get-ChildItem -Path dist,package -Recurse -File
$items | ForEach-Object {
    $hash = Get-FileHash $_.FullName -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash, $_.FullName
} | Out-File -Encoding ascii dist/checksums.sha256

# Verify checksums
Get-Content dist/checksums.sha256
```

## Architecture

```
Tooling/x-cli/
├── src/
│   ├── XCli/                   # Main CLI entry point
│   ├── XCli.Commands/          # Command implementations
│   │   ├── SourceDist/         # Source distribution commands
│   │   ├── VIAnalyzer/         # VI Analyzer commands
│   │   ├── VIHistory/          # VI History comparison
│   │   └── Telemetry/          # Telemetry tracking
│   └── XCli.Core/              # Shared utilities
├── tests/                      # Unit tests
├── scripts/
│   ├── build.ps1               # Multi-platform build
│   ├── pack-cli.ps1            # NuGet packaging
│   └── stream-output.ps1       # Build output helper
├── dist/                       # Build outputs (gitignored)
│   ├── x-cli-win-x64           # Windows normalized binary
│   ├── x-cli-linux-x64         # Linux normalized binary
│   ├── win-x64/                # Full Windows artifacts
│   └── linux-x64/              # Full Linux artifacts
└── package/                    # NuGet packages (gitignored)
```

## Configuration Files

x-cli uses JSON configuration files in `configs/x-cli/`:

- **`local-sd-ppl.json`**: Local SD→PPL build configuration
- **`consume-sd-docker.json`**: Docker SD consumption harness
- **`vi-analyzer-request.sample.json`**: VI Analyzer run settings
- **`vi-compare-run-request.sample.json`**: VI History comparison settings

## Troubleshooting

### "IsolationGuard blocked process start"

**Cause**: x-cli prevented external process launch for safety.

**Solution**: Set `XCLI_ALLOW_PROCESS_START=1` environment variable before running commands that need process spawning (VI Analyzer, VI History).

### "dotnet: command not found" during build

**Cause**: .NET SDK not installed or not in PATH.

**Solution**: 
1. Install .NET SDK 8.0.x from https://dotnet.microsoft.com/download
2. Verify: `dotnet --version` should show 8.0.x
3. Check `global.json` for pinned SDK version

### Linux binary not executable

**Cause**: File permissions not set during build or download.

**Solution**:
```bash
chmod +x dist/x-cli-linux-x64
```

The build script automatically sets this on Linux hosts, but Windows builds may need manual chmod.

### "Failed to locate published binary"

**Cause**: Build output structure doesn't match expected binary names.

**Solution**: Check `scripts/build.ps1` candidates list matches actual .NET publish output. The script looks for `XCli.exe` or `XCli` (Windows) and `XCli` or `XCli.dll` (Linux).

### Stale x-cli processes

**Cause**: Previous x-cli invocation didn't exit cleanly.

**Solution**: The wrapper script (`invoke-repo-cli.ps1`) automatically kills stale processes, or manually:
```powershell
# Windows
Get-Process -Name XCli -ErrorAction SilentlyContinue | Stop-Process -Force

# Linux
pkill -f x-cli-linux-x64
```

## Related Documentation

- **`MAINTAINING-x-cli.md`**: Detailed build, test, and release procedures
- **`docs/x-cli-playbook.md`**: Practical usage examples and workflows
- **`docs/vscode-tasks.md`**: VS Code task descriptions and parameters
- **`.github/workflows/x-cli-build-test.yml`**: CI build and test workflow
- **`.github/workflows/x-cli-release.yml`**: Release automation workflow
- **`docs/schemas/x-cli/`**: JSON schemas for telemetry validation

## FAQ

### Where is x-cli source code?

**Upstream in this repository**: `Tooling/x-cli/`

x-cli is no longer vendored from elsewhere - this repo is the authoritative source.

### Do I need .NET Runtime to use x-cli?

**No**. Release binaries are self-contained and include the .NET runtime.

Development and building from source requires .NET SDK 8.0.x.

### Can I use x-cli outside this repository?

**Yes**. Download release binaries and use them in any LabVIEW project. Configuration is via JSON files.

### How do I update x-cli in this repository?

**Edit the source** under `Tooling/x-cli/src/`, then rebuild:
```powershell
cd Tooling/x-cli
dotnet build XCli.sln -c Release
dotnet test XCli.sln -c Release
```

The wrapper script will automatically use the latest built version.

### What about the packages.lock.json platform?

**Current policy**: `packages.lock.json` reflects `linux-x64` because primary CI runs on `ubuntu-latest`. 

Windows builds use the same dependencies but may have different resolved platform-specific packages. Both platforms produce working binaries.

### How do I version x-cli?

**Source of truth**: Git tags `v<major>.<minor>.<patch>` (optionally with prerelease suffix like `-rc.1`).

Release workflow parses tags and passes version to build/pack scripts.

