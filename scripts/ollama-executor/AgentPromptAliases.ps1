[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Keyword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Map single-word keywords to full agent prompts.
$aliases = @{
    seed2021 = @"
Create a seeded branch targeting LabVIEW 2021 Q1 64-bit using the vendored Seed image.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2021 -LabVIEWMinor 0 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2021q1-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    seed2024q3 = @"
Create a seeded branch targeting LabVIEW 2024 Q3 64-bit using the vendored Seed image.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2024 -LabVIEWMinor 3 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2024q3-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    seedlatest = @"
Create a seeded branch for the latest LabVIEW version we support (update the parameters as needed).
- Default: LabVIEW 2025 Q3 64-bit.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2025q3-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    vipbparse = @"
Parse and round-trip the VIPB using the Seed container (for troubleshooting).
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From repo root:
  docker run --rm --entrypoint /usr/local/bin/vipb2json -v ""${PWD}:/repo"" -w /repo $env:SEED_IMAGE --input Tooling/deployment/seed.vipb --output Tooling/deployment/seed.vipb.json
  docker run --rm --entrypoint /usr/local/bin/json2vipb -v ""${PWD}:/repo"" -w /repo $env:SEED_IMAGE --input Tooling/deployment/seed.vipb.json --output Tooling/deployment/seed.vipb
- Report success or any errors.
"@
}

if (-not $aliases.ContainsKey($Keyword.ToLower())) {
    $valid = ($aliases.Keys | Sort-Object) -join ', '
    throw "Unknown keyword '$Keyword'. Known keywords: $valid"
}

$aliases[$Keyword.ToLower()]
