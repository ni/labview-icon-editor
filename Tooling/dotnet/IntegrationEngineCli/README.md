# Integration Engine CLI

.NET console entry point for running the Integration Engine build for the LabVIEW Icon Editor.

## Build
```bash
dotnet build Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj
```

## Usage
From repo root:
```bash
dotnet run --project Tooling/dotnet/IntegrationEngineCli -- \
  --repo . \
  --ref HEAD \
  --bitness 64 \
  --lvlibp-bitness both \
  --major 0 --minor 1 --patch 0 --build 1 \
  --company "LabVIEW-Community-CI-CD" \
  --author "Local Developer"
```

Modes:
- Default (no `--managed`): shells out to `scripts/ie.ps1 -Command build-worktree` and streams output.
- `--managed`: invokes each build step directly (bind dev mode, close LabVIEW, build lvlibp for requested bitness, rename/stash, stage PPLs, `build_vip.ps1`) with the same arguments. Requires Windows with LabVIEW, VIPM, and g-cli on PATH.

Optional flags:
- `--run-both-bitness-separately` to mirror the wrapper’s split lanes.
- `--pwsh <path>` to point at a specific PowerShell executable.
- `--verbose` to pass `-Verbose` through to the underlying scripts.
- `-h|--help` for help.

## Publishing (optional)
Produce a single-file win-x64 executable (framework-dependent) with:
```bash
dotnet publish Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj \
  -c Release -r win-x64 -p:PublishSingleFile=true --self-contained false
```
