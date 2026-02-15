#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$LockPath,

    [Parameter(Mandatory = $false)]
    [string]$LayerRoot
)

$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'support/CodexSkillLayer.ps1'
if (-not (Test-Path -Path $supportPath -PathType Leaf)) {
    throw "Codex skill layer support script not found: $supportPath"
}
. $supportPath

$state = Get-CodexSkillLayerState -RepoRoot $RepoRoot -LockPath $LockPath -LayerRoot $LayerRoot

try {
    Test-CodexSkillLayerVersionRoot -State $state | Out-Null
} catch {
    $msg = @(
        "Codex skill layer validation failed: $($_.Exception.Message)",
        "Install the pinned layer with:",
        "pwsh -NoProfile -File .\\Tooling\\Install-CodexSkillLayer.ps1"
    ) -join [Environment]::NewLine
    throw $msg
}

Write-Host ("Codex skill layer is ready at {0} (repo={1}, tag={2})" -f $state.VersionRoot, [string]$state.Lock.repo, [string]$state.Lock.tag)

[pscustomobject]@{
    repo = [string]$state.Lock.repo
    tag = [string]$state.Lock.tag
    asset_name = [string]$state.Lock.asset_name
    version_root = $state.VersionRoot
    license_spdx = [string]$state.Lock.license_spdx
}
