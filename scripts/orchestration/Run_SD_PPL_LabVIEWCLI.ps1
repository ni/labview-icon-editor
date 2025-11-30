[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,
    [string]$LabVIEWVersion,
    [int]$TimeoutSec = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$scriptRoot = Split-Path -Parent $PSCommandPath
$tempHelper = Join-Path $scriptRoot '..\common\Ensure-StandardTempPath.ps1'
if (-not (Test-Path -LiteralPath $tempHelper)) { throw "Missing temp helper at $tempHelper" }
. $tempHelper
Ensure-StandardTempPath -Label 'labview-icon-editor' | Out-Null

function Run-Step {
    param([scriptblock]$Action)
    & $Action
}

function Invoke-Bind {
    param([string]$Path,[string]$Mode)
    $bindScript = Join-Path $repo "scripts\bind-development-mode\BindDevelopmentMode.ps1"
    & pwsh -NoProfile -File $bindScript -RepositoryPath $Path -Mode $Mode -Bitness both -Force | Out-Null
}

function Invoke-LabVIEWCLI-Build {
    param([string]$Project,[string]$BuildSpec,[string]$Target,[string]$LogPath,[string]$Vipb)
    $lvsd = Join-Path $repo "scripts/labview/build-source-distribution.ps1"
    $args = @{
        RepositoryPath = $repo
        ProjectPath    = $Project
        VipbPath       = $Vipb
        BuildSpecName  = $BuildSpec
        TargetName     = $Target
        LogFilePath    = $LogPath
        AllowLabVIEWFallback = $true
    }
    if ($LabVIEWVersion) { $args["LabVIEWPath"] = $null; $args["Package_LabVIEW_Version"] = $LabVIEWVersion }
    & pwsh -NoProfile -File $lvsd @args
}

Write-Host "[STEP] Binding repo..."
Invoke-Bind -Path $repo -Mode bind

Write-Host "[STEP] Building Source Distribution via LabVIEWCLI..."
$sdLog = Join-Path $repo "reports/logs/lvsd-labviewcli-sd.log"
Invoke-LabVIEWCLI-Build -Project (Join-Path $repo 'lv_icon_editor.lvproj') -BuildSpec 'Source Distribution' -Target 'My Computer' -LogPath $sdLog -Vipb 'Tooling/deployment/seed.vipb'

Write-Host "[STEP] Unbinding repo..."
Invoke-Bind -Path $repo -Mode unbind

$zipPath = Join-Path $repo 'builds/artifacts/source-distribution.zip'
if (-not (Test-Path -LiteralPath $zipPath)) { throw "source-distribution.zip not found at $zipPath" }
$extractRoot = Join-Path $env:TMP 'sd-extract'
if (-not (Test-Path $extractRoot)) { New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null }
Write-Host "[STEP] Extracting source distribution to $extractRoot"
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

Write-Host "[STEP] Binding extracted SD..."
Invoke-Bind -Path $extractRoot -Mode bind

Write-Host "[STEP] Building PPL via LabVIEWCLI..."
$pplLog = Join-Path $repo "reports/logs/lvsd-labviewcli-ppl.log"
Invoke-LabVIEWCLI-Build -Project (Join-Path $extractRoot 'lv_icon_editor.lvproj') -BuildSpec 'Editor Packed Library' -Target 'My Computer' -LogPath $pplLog -Vipb 'Tooling/deployment/seed.vipb'

Write-Host "[STEP] Unbinding extracted SD..."
Invoke-Bind -Path $extractRoot -Mode unbind

Write-Host "[INFO] SD→PPL flow via LabVIEWCLI completed."
