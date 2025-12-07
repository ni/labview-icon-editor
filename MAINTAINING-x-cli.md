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

The `build.ps1` script produces **both Windows and Linux** self-contained executables:

```powershell
# From Tooling/x-cli/ directory
pwsh scripts/build.ps1 -Version 1.0.0

# Outputs:
#   dist/x-cli-win-x64          (Windows native binary)
#   dist/x-cli-linux-x64        (Linux native binary)
#   dist/win-x64/               (full Windows publish output)
#   dist/linux-x64/             (full Linux publish output)
#   artifacts/release/win-x64/  (intermediate build artifacts)
#   artifacts/release/linux-x64/(intermediate build artifacts)
```

**Note**: The script uses .NET cross-compilation to build Linux binaries on Windows and vice versa.

### NuGet-Style Package

```powershell
# From Tooling/x-cli/ directory
pwsh scripts/pack-cli.ps1 -Version 1.0.0

# Outputs:
#   package/*.nupkg             (contains both Windows and Linux binaries)
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

#### Option 1: Tag-based Release

1. Create and push annotated tag:
   ```bash
   git tag -a v1.0.0 -m "Release x-cli v1.0.0"
   git push origin v1.0.0
   ```

2. GitHub Actions (`.github/workflows/x-cli-release.yml`) automatically:
   - Builds Windows and Linux binaries via `scripts/build.ps1`
   - Creates NuGet package via `scripts/pack-cli.ps1`
   - Generates SHA256 checksums (`dist/checksums.sha256`)
   - Creates GitHub Release with:
     - `dist/x-cli-win-x64` (Windows binary)
     - `dist/x-cli-linux-x64` (Linux binary)
     - `dist/checksums.sha256` (verification file)
     - `package/*.nupkg` (NuGet package with both binaries)

#### Option 2: Workflow Dispatch (Pre-release Testing)

1. Go to Actions → "x-cli release" workflow
2. Click "Run workflow"
3. Enter version (e.g., `v1.0.0-rc.1`)
4. Review generated artifacts before creating actual tag

**Use this for**:
- Testing release process without creating tags
- Creating pre-releases (`-alpha`, `-beta`, `-rc` suffixes)
- Verifying cross-platform builds work correctly

### Manual Release (Local Development)

```powershell
cd Tooling/x-cli

# 1. Build both platforms
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
```powershell
# Verify a downloaded binary
$hash = (Get-FileHash -Algorithm SHA256 dist/x-cli-win-x64).Hash
# Compare with published checksums.sha256
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
  - Windows builds use same dependencies but platform-specific resolutions may differ
  - Both platforms produce working self-contained binaries
- **Restore policy**: Deterministic restore from lock file when present

### Cross-Platform Build Notes

- **Build host**: Can build both Windows and Linux binaries from either platform
- **.NET cross-compilation**: Uses `-r win-x64` and `-r linux-x64` runtime identifiers
- **Self-contained**: Both binaries include .NET runtime (no installation required)
- **Executable permissions**: Linux binary automatically gets `+x` on Linux hosts
  - Windows hosts building Linux binaries cannot set permissions
  - Download from releases includes correct permissions
  - Manual download may need: `chmod +x x-cli-linux-x64`
