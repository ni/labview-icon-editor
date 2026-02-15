#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$LockPath,

    [Parameter(Mandatory = $false)]
    [string]$LayerRoot,

    [Parameter(Mandatory = $false)]
    [string]$Token,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'support/CodexSkillLayer.ps1'
if (-not (Test-Path -Path $supportPath -PathType Leaf)) {
    throw "Codex skill layer support script not found: $supportPath"
}
. $supportPath

$state = Get-CodexSkillLayerState -RepoRoot $RepoRoot -LockPath $LockPath -LayerRoot $LayerRoot
$result = Install-CodexSkillLayerInternal -State $state -Token $Token -Force:$Force

if ($result.Installed) {
    Write-Host ("Installed Codex skill layer to {0}" -f $result.VersionRoot)
} else {
    Write-Host ("Codex skill layer already satisfied at {0}" -f $result.VersionRoot)
}

[pscustomobject]@{
    repo = [string]$state.Lock.repo
    tag = [string]$state.Lock.tag
    asset_name = [string]$state.Lock.asset_name
    sha256 = [string]$state.Lock.sha256
    version_root = $result.VersionRoot
    installed = [bool]$result.Installed
}
