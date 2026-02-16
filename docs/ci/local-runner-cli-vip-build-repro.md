# Local Repro: `Build VI Package` Runner-CLI Lane

Use this procedure when CI fails in `Build VI Package (LV 64-bit)` and you need deterministic local reproduction on a Windows runner host with LabVIEW/VIPM installed.

## 1. Preconditions

- Run from repo root.
- PowerShell 7 available.
- .NET SDK 8.x available.
- `vipm` available on `PATH`.
- LabVIEW 2026.1 (64-bit) installed for current canonical baseline.

## 2. Verify toolchain

```powershell
dotnet --info
dotnet --list-sdks
vipm --version
```

If .NET 8.x is missing:

```powershell
winget install --id Microsoft.DotNet.SDK.8 --exact --source winget
```

## 3. Prepare deterministic inputs

```powershell
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path .).Path
$env:REPO_ROOT = $repoRoot
$env:LVIE_VIPM_TIMEOUT_SECONDS = '900'
$env:LVIE_VIPM_MAX_ATTEMPTS = '2'
$env:LVIE_VIPM_RETRY_DELAY_SECONDS = '30'
$env:LVIE_REQUIRED_LABVIEW_VERSION = '26.1'
$env:LVIE_REQUIRED_LABVIEW_VERSION_YEAR = '2026'
$env:LVIE_REQUIRED_LABVIEW_MINOR_REVISION = '1'
$displayInfoPath = Join-Path $env:TEMP 'lvie-local-display-information.json'
```

Generate display JSON payload exactly like CI:

```powershell
$displayInformationJson = & "$repoRoot\.github\actions\generate-vipb-display-info\GenerateVIPBDisplayInfo.ps1" `
  -Major 0 -Minor 1 -Patch 1 -Build 9999 `
  -Commit 'local-repro' `
  -Repository $env:GITHUB_REPOSITORY

$displayInformationJson | Set-Content -Path $displayInfoPath -Encoding utf8
```

## 4. Reproduce via runner-cli (authoritative path)

Build runner-cli publish output:

```powershell
dotnet publish "$repoRoot\Tooling\runner-cli\RunnerCli\RunnerCli.csproj" `
  -c Release -r win-x64 --self-contained false `
  -o "$repoRoot\Tooling\runner-cli\publish\win-x64"
```

Run the same lane contract:

```powershell
& "$repoRoot\Tooling\runner-cli\publish\win-x64\runner-cli.exe" `
  vip build `
  --repo-root "$repoRoot" `
  --supported-bitness 64 `
  --vipb-path "Tooling/deployment/NI Icon editor.vipb" `
  --labview-version 26.1 `
  --labview-minor-revision 1 `
  --major 0 --minor 1 --patch 1 --build 9999 `
  --commit local-repro `
  --release-notes-file "$repoRoot\Tooling\deployment\release_notes.md" `
  --display-information-json-path "$displayInfoPath" `
  --vipm-timeout-seconds 900
```

## 5. Isolate backend script (if needed)

If wrapper behavior is unclear, run backend directly:

```powershell
pwsh -NoProfile -File "$repoRoot\Tooling\Invoke-VipBuild.ps1" `
  -SupportedBitness 64 `
  -RepoRoot "$repoRoot" `
  -VIPBPath "Tooling/deployment/NI Icon editor.vipb" `
  -LabVIEWVersion 26.1 `
  -LabVIEWMinorRevision 1 `
  -Major 0 -Minor 1 -Patch 1 -Build 9999 `
  -Commit local-repro `
  -ReleaseNotesFile "$repoRoot\Tooling\deployment\release_notes.md" `
  -DisplayInformationJsonPath "$displayInfoPath" `
  -VipmTimeoutSeconds 900
```

## 6. Collect evidence

- `builds/status/vip-build.json`
- `builds/logs/vipm-build.log`
- `builds/logs/vip/vipb-display-info.json` (or equivalent under artifact/log root)
- Console output from runner-cli and `Invoke-VipBuild.ps1`

## 7. Deterministic classification

- If runner-cli fails before launching PowerShell script: classify as **wrapper/CLI contract issue**.
- If `Invoke-VipBuild.ps1` parameter binding fails: classify as **script contract drift**.
- If script runs but VIP build fails: classify as **VIPM/LabVIEW build backend issue**.
- If outputs missing despite exit `0`: classify as **artifact resolution contract issue**.
