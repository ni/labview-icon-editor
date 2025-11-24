[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path
    , [string]$VipbPath = "Tooling/deployment/labview-icon-editor.vipb"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot '..\.github\actions\bind-development-mode\BindDevelopmentMode.ps1'

Write-Host "Dev Mode Bind (force clean): clearing LocalHost.LibraryPaths entries from the canonical LabVIEW INIs in Program Files / Program Files (x86) and unbinding both bitnesses (Force)"
- resolves `$VipbPath` to determine LabVIEW version/bitness,
- uses the VIPB at `$repo\Tooling\deployment\labview-icon-editor.vipb` to derive that version,
- invokes `g-cli` / `Create_LV_INI_Token.vi` to insert the repo path into each canonical `LabVIEW.ini`,
- writes `LocalHost.LibraryPaths=C:\repos\...` so LabVIEW loads your source tree instead of packed libraries.

Preparing sources - once the tokens are present, `Prepare_LabVIEW_source.ps1`:
- calls `g-cli` / `PrepareIESource.vi`, unpacks `vi.lib`, removes packed libs, and makes sure the repo VIs are runnable.

Closing LabVIEW - `Close_LabVIEW.ps1` runs `g-cli QuitLabVIEW` so no running instance holds the INI or packaged files.

In summary, development mode rewrites the LabVIEW INIs, clears any packed state, and restarts LabVIEW to operate on your source tree.
"@
$continue = Read-Host "Continue with unbind/bind sequence after reviewing the note? (y/N)"
if (-not ($continue -match '^(?i:y|yes)$')) {
    Write-Host "Operation cancelled."
    exit 1
}
& $bindScript -RepositoryPath $repo -Mode unbind -Bitness both -Force

Write-Host "Dev Mode Bind (force clean): writing this repo into LocalHost.LibraryPaths for both bitnesses, prepping sources, and rerunning binder validation (Force)"
& $bindScript -RepositoryPath $repo -Mode bind -Bitness both -Force
