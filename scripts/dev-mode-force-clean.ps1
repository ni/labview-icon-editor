[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$VipbPath,
    [switch]$SkipConfirm
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot 'bind-development-mode/BindDevelopmentMode.ps1'

if (-not $VipbPath) {
    $deployment = Join-Path $repo 'Tooling/deployment'
    if (-not (Test-Path $deployment)) {
        throw "Tooling/deployment directory missing; specify -VipbPath."
    }
    $candidates = Get-ChildItem -Path $deployment -Filter '*.vipb' -File | Sort-Object LastWriteTime -Descending
    if (-not $candidates) {
        throw "No .vipb files found under $deployment; specify -VipbPath."
    }
    $VipbPath = $candidates[0].FullName
} 
else {
    $VipbPath = (Resolve-Path -LiteralPath $VipbPath).Path
}

$reportsDir = Join-Path $repo 'reports'
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }
$vipbRecord = Join-Path $reportsDir 'vipb-path.txt'
Set-Content -LiteralPath $vipbRecord -Value $VipbPath -Encoding UTF8

 $startTime = Get-Date
 $metaPath = Join-Path $reportsDir 'dev-mode-force-clean.json'

Write-Host "Dev Mode Bind (force clean): clearing LocalHost.LibraryPaths entries from the canonical LabVIEW INIs in Program Files / Program Files (x86) and unbinding both bitnesses (Force)"
Write-Host "Using VIPB: $VipbPath"
Write-Host @"
Token updates – `Set_Development_Mode.ps1` (via `DevModeBind`/`DevModeForceClean`) calls `AddTokenToLabVIEW.ps1`, which:
- resolves `$VipbPath` to determine LabVIEW version/bitness,
- writes `LocalHost.LibraryPaths=C:\repos\...` directly into the canonical INI (no Create_LV_INI_Token.vi) so LabVIEW loads your source tree instead of packed libraries.

Preparing sources – once the tokens are present, `Prepare_LabVIEW_source.ps1`:
- calls `g-cli` / `PrepareIESource.vi`, unpacks `vi.lib`, removes packed libs, and makes sure the repo VIs are runnable.

Closing LabVIEW – `Close_LabVIEW.ps1` runs `g-cli QuitLabVIEW` so no running instance holds the INI or packaged files.

In summary, development mode rewrites the LabVIEW INIs, clears any packed state, and restarts LabVIEW to operate on your source tree.
"@
if (-not $SkipConfirm) {
    $continue = Read-Host "Continue with unbind/bind sequence after reviewing the note? (y/N)"
    if (-not ($continue -match '^(?i:y|yes)$')) {
        Write-Host "Operation cancelled."
        exit 1
    }
}

& $bindScript -RepositoryPath $repo -Mode unbind -Bitness both -Force

Write-Host "Dev Mode Bind (force clean): writing this repo into LocalHost.LibraryPaths for both bitnesses, prepping sources, and rerunning binder validation (Force)"
& $bindScript -RepositoryPath $repo -Mode bind -Bitness both -Force

$endTime = Get-Date
$duration = $endTime - $startTime
$meta = @{
    VipbPath   = $VipbPath
    StartTime  = $startTime.ToString("o")
    EndTime    = $endTime.ToString("o")
    Duration   = $duration.TotalSeconds
}
$meta | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
