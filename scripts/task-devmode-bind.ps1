[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryPath,
    [ValidateSet('bind','unbind','status','cleanup')][string]$Mode = 'bind',
    [ValidateSet('both','32','64')][string]$Bitness = 'both',
    [switch]$UseWorktree,
    [switch]$Preclear,
    [string]$LabVIEWVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot 'bind-development-mode/BindDevelopmentMode.ps1'
if (-not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    throw "Missing BindDevelopmentMode.ps1 at $bindScript"
}

function Invoke-Bind {
    param([string]$BindMode)
    & pwsh -NoProfile -File $bindScript -RepositoryPath $repo -Mode $BindMode -Bitness $Bitness -LabVIEWVersion $LabVIEWVersion
}

if ($Preclear) {
    Invoke-Bind -BindMode 'cleanup'
}

Invoke-Bind -BindMode $Mode
