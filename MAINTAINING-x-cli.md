# Maintaining x-cli (upstream in this repo)

> **See also**: `docs/x-cli-overview.md` for comprehensive x-cli documentation including platform support, common workflows, and troubleshooting.

## Build & test

```powershell
# From Tooling/x-cli/ directory
dotnet build XCli.sln -c Release
dotnet test XCli.sln -c Release

# Quick help smoke test
dotnet run --project src/XCli/XCli.csproj -- --help
```

## Packaging

### Multi-Platform Binaries

The `build.ps1` script produces **Windows, Linux, and macOS** self-contained executables:

```powershell
# From Tooling/x-cli/ directory
pwsh scripts/build.ps1 -Version 1.0.0

# Outputs:
#   dist/x-cli-win-x64          (Windows native binary)
#   dist/x-cli-linux-x64        (Linux native binary)
#   dist/x-cli-osx-x64          (macOS native binary)
#   dist/win-x64/               (full Windows publish output)
#   dist/linux-x64/             (full Linux publish output)
#   dist/osx-x64/               (full macOS publish output)
#   artifacts/release/win-x64/  (intermediate build artifacts)
#   artifacts/release/linux-x64/(intermediate build artifacts)
#   artifacts/release/osx-x64/  (intermediate build artifacts)
```

**Note**: The script uses .NET cross-compilation to build binaries for all platforms.

### NuGet-Style Package

```powershell
# From Tooling/x-cli/ directory
pwsh scripts/pack-cli.ps1 -Version 1.0.0

# Outputs:
#   package/*.nupkg             (contains Windows, Linux, and macOS binaries)
```

### Versioning

- **Preferred**: Tag-based SemVer (e.g., `v1.0.0`, `v1.0.0-rc.1`)
- **Alternative**: Pass `-Version` parameter to build/pack scripts
- **CI**: Release workflow auto-extracts version from git tags

## Telemetry

- Schemas (authoritative): `docs/schemas/x-cli/telemetry.events.v2.schema.json`, `docs/schemas/x-cli/telemetry.summary.v1.schema.json`
- Validate after runs: `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- telemetry validate --events artifacts/qa-telemetry.jsonl --schema docs/schemas/x-cli/telemetry.events.v2.schema.json`
- Summarize: `... telemetry summarize --in artifacts/qa-telemetry.jsonl --out telemetry/summary.json`
- Gate: `... telemetry check --summary telemetry/summary.json --max-failures 0`

## Release Process

### Automated Release (Recommended)

#### CI Workflows

The x-cli project uses two automated GitHub Actions workflows:

1. **Build and Test** (`.github/workflows/x-cli-build-test.yml`)
   - Triggers on pushes/PRs affecting x-cli code
   - Matrix builds on `ubuntu-22.04`, `windows-2022`, and `macos-13`
   - Enforces package lock files (`--locked-mode`)
   - Runs smoke tests and full test suite per OS
   - Verifies build artifacts with SHA256 checksums
   - Publishes test results per platform

2. **Publish Release** (`.github/workflows/x-cli-release.yml`)
   - Triggers on git tags (`v*`) or manual workflow dispatch
   - Builds platform-specific archives (win-x64, linux-x64, osx-x64)
   - Creates NuGet package
   - Generates SHA256 checksums for all artifacts
   - Attaches to GitHub Release (tags only)

#### Option 1: Tag-based Release

1. Create and push annotated tag:
   ```bash
   git tag -a v1.0.0 -m "Release x-cli v1.0.0"
   git push origin v1.0.0
   ```

2. GitHub Actions automatically:
   - Builds separate jobs for `win-x64`, `linux-x64`, and `osx-x64` using `dotnet publish`
   - Creates ZIP archives: `x-cli-<version>-win-x64.zip`, `x-cli-<version>-linux-x64.zip`, and `x-cli-<version>-osx-x64.zip`
   - Generates individual SHA256 files per artifact
   - Packs NuGet package: `XCli.<version>.nupkg`
   - Creates consolidated `checksums-all.sha256` with all artifact hashes
   - Creates GitHub Release with all artifacts attached

#### Option 2: Workflow Dispatch (Pre-release Testing)

1. Go to Actions → "x-cli publish" workflow
2. Click "Run workflow"
3. Enter version (e.g., `v1.0.0-rc.1`)
4. Review generated artifacts (no GitHub Release created for manual runs)

**Use this for**:
- Testing release process without creating tags
- Creating test builds for manual verification
- Verifying cross-platform builds work correctly
- Downloading artifacts without publishing a release

**Note**: Manual workflow runs create artifacts but do not publish a GitHub Release. To publish, create an actual git tag.

### Manual Release (Local Development)

```powershell
cd Tooling/x-cli

# 1. Build all platforms
pwsh scripts/build.ps1 -Version 1.0.0

# 2. Create NuGet package
pwsh scripts/pack-cli.ps1 -Version 1.0.0

# 3. Generate checksums
New-Item -ItemType Directory -Force -Path dist | Out-Null
$items = Get-ChildItem -Path dist,package -Recurse -File
$items | ForEach-Object {
    $hash = Get-FileHash $_.FullName -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash, $_.FullName
} | Out-File -Encoding ascii dist/checksums.sha256

# 4. Verify checksums
Get-Content dist/checksums.sha256

# 5. (Optional) Create GitHub Release manually and attach:
#    - dist/x-cli-win-x64
#    - dist/x-cli-linux-x64
#    - dist/x-cli-osx-x64
#    - dist/checksums.sha256
#    - package/*.nupkg
```

### Versioning Policy

**Source of Truth**: Git tags `v<major>.<minor>.<patch>[<prerelease>]`

Examples:
- Release: `v1.0.0`, `v1.2.3`, `v2.0.0`
- Pre-release: `v1.0.0-alpha.1`, `v1.2.0-beta.2`, `v1.0.0-rc.1`

**Version Extraction**:
- Tags starting with `v` have the `v` prefix stripped (e.g., `v1.0.0` → `1.0.0`)
- Version is passed to .NET build via `-p:Version=<version>`
- Version appears in binary metadata (`XCli --version`) and NuGet package ID

**Checksum Verification**:

Downloads from GitHub Releases include individual `.sha256` files plus a consolidated `checksums-all.sha256`:

```bash
# Verify all artifacts (Linux/macOS)
sha256sum -c checksums-all.sha256

# Verify single artifact (Linux/macOS)
sha256sum -c x-cli-1.0.0-linux-x64.zip.sha256

# Verify on Windows (PowerShell)
Get-Content checksums-all.sha256 | ForEach-Object {
  $hash, $file = $_ -split '  '
  if (Test-Path $file) {
    $actual = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
    if ($hash -eq $actual) { "✓ OK: $file" } else { "✗ FAIL: $file" }
  } else {
    "⚠ SKIP: $file (not downloaded)"
  }
}
```

## Repo Layout & Platform Notes

### x-cli Source Structure

```
Tooling/x-cli/
├── src/
│   ├── XCli/                   # Main CLI entry point
│   ├── XCli.Commands/          # Command implementations
│   └── XCli.Core/              # Shared utilities
├── tests/                      # Unit tests
├── scripts/
│   ├── build.ps1               # Multi-platform build (Windows + Linux)
│   ├── pack-cli.ps1            # NuGet packaging
│   └── stream-output.ps1       # Build output helper
├── dist/                       # Build outputs (gitignored)
├── package/                    # NuGet packages (gitignored)
└── artifacts/                  # Intermediate build artifacts (gitignored)
```

### Source of Truth

- **x-cli source**: Lives under `Tooling/x-cli` (no longer treated as vendored)
- **Repo-level wrappers**: `scripts/telemetry`, `scripts/common/invoke-repo-cli.ps1`
- **Telemetry schemas**: `docs/schemas/x-cli/` (authoritative)

### Dependencies

- **.NET SDK**: Pinned via `global.json` (currently 8.0.x)
- **packages.lock.json**: Reflects `linux-x64` platform (primary CI platform)
  - Windows and macOS builds use same dependencies but platform-specific resolutions may differ
  - All platforms produce working self-contained binaries
- **Restore policy**: Deterministic restore from lock file when present

### Cross-Platform Build Notes

- **Build host**: Can build Windows, Linux, and macOS binaries from any platform
- **.NET cross-compilation**: Uses `-r win-x64`, `-r linux-x64`, and `-r osx-x64` runtime identifiers
- **Self-contained**: All binaries include .NET runtime (no installation required)
- **Executable permissions**: Linux and macOS binaries automatically get `+x` on Unix hosts
  - Windows hosts building Unix binaries cannot set permissions
  - Download from releases includes correct permissions
  - Manual download may need: `chmod +x x-cli-linux-x64` or `chmod +x x-cli-osx-x64`
