# Draft Release Summary (Source Distribution Only)

- Date: 2025-12-06
- Scope: Source Distribution only (exclude VIP/PPL)
- LabVIEW: 2021 (64-bit)
- Workspace: Dirty allowed; serialization and clean-output guards enabled

## Artifacts

- Zip: `builds/artifacts/labview-icon-api.zip`
- Zip SHA256: `<fill-after-build>`
- Manifest (JSON): `builds/LabVIEWIconAPI/manifest.json`
- Manifest (CSV): `builds/LabVIEWIconAPI/manifest.csv`
- Verify Report: `builds/reports/source-distribution-verify/`

## Policies

- Serialization lock: `builds/.locks/source-distribution.lock`
- Guard: `-RequireCleanOutput` prevents overwriting existing SD outputs
- Strict verify: `source-dist-verify --source-dist-strict`

## Next Steps

- Run guarded build for 2021 x64, then strict verify:

```powershell
Remove-Item -LiteralPath builds/artifacts/labview-icon-api.zip -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath builds/LabVIEWIconAPI -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath builds/.locks/source-distribution.lock -Force -ErrorAction SilentlyContinue

pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 `
  -RepositoryPath "$PWD" `
  -Package_LabVIEW_Version 2021 `
  -SupportedBitness 64 `
  -RequireCleanOutput

dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- `
  source-dist-verify `
  --repo "$PWD" `
  --source-dist-log-stash `
  --source-dist-strict

# Fill summary values
Get-FileHash -LiteralPath builds/artifacts/labview-icon-api.zip -Algorithm SHA256
($m = Get-Content builds/LabVIEWIconAPI/manifest.json -Raw | ConvertFrom-Json).Count
Get-Item builds/artifacts/labview-icon-api.zip | Select-Object Length
```

## Notes

- If `g-cli lvbuildspec` fails, the build falls back to copy-based staging; strict verification must still pass.
- If the guard fails (exit 1), clean existing outputs and retry.
