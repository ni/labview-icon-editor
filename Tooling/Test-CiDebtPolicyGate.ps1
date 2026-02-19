#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('warn', 'enforce')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'support/CodexSkillLayer.ps1'
if (-not (Test-Path -Path $supportPath -PathType Leaf)) {
    throw "Codex skill layer support script not found: $supportPath"
}
. $supportPath

$state = Get-CodexSkillLayerState -RepoRoot $RepoRoot
Test-CodexSkillLayerVersionRoot -State $state | Out-Null

$targetScript = Join-Path $state.VersionRoot 'ci-debt/Test-CiDebtPolicyGate.ps1'
if (-not (Test-Path -Path $targetScript -PathType Leaf)) {
    throw "Codex skill layer entrypoint not found: $targetScript"
}

& $targetScript @PSBoundParameters
