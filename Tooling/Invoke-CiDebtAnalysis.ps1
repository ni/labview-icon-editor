#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [long]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$OutJson,

    [Parameter(Mandatory = $false)]
    [string]$OutMarkdown,

    [Parameter(Mandatory = $false)]
    [string]$SignaturePath,

    [Parameter(Mandatory = $false)]
    [string]$FixturePath,

    [switch]$FailOnUnknown
)

$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'support/CodexSkillLayer.ps1'
if (-not (Test-Path -Path $supportPath -PathType Leaf)) {
    throw "Codex skill layer support script not found: $supportPath"
}
. $supportPath

$state = Get-CodexSkillLayerState
Test-CodexSkillLayerVersionRoot -State $state | Out-Null

$targetScript = Join-Path $state.VersionRoot 'ci-debt/Invoke-CiDebtAnalysis.ps1'
if (-not (Test-Path -Path $targetScript -PathType Leaf)) {
    throw "Codex skill layer entrypoint not found: $targetScript"
}

. $targetScript

$defaultSignaturePath = Join-Path $state.VersionRoot 'ci-debt/signatures.json'
if (-not (Test-Path -Path $defaultSignaturePath -PathType Leaf)) {
    throw "Codex skill layer signature file not found: $defaultSignaturePath"
}
if ($null -eq $PSDefaultParameterValues) {
    $global:PSDefaultParameterValues = @{}
}
$PSDefaultParameterValues['Invoke-CiDebtAnalysis:SignaturePath'] = $defaultSignaturePath

if ($MyInvocation.InvocationName -ne '.') {
    $invokeArgs = @{}
    foreach ($key in $PSBoundParameters.Keys) {
        $invokeArgs[$key] = $PSBoundParameters[$key]
    }
    if (-not $invokeArgs.ContainsKey('SignaturePath') -or [string]::IsNullOrWhiteSpace([string]$invokeArgs['SignaturePath'])) {
        $invokeArgs['SignaturePath'] = Join-Path $state.VersionRoot 'ci-debt/signatures.json'
    }
    Invoke-CiDebtAnalysis @invokeArgs | Out-Null
}
