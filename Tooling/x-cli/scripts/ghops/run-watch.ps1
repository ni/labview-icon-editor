<#
.SYNOPSIS
Watches a workflow run by ID or resolves latest by workflow and optional branch.

.PARAMETER Target
Workflow filename (e.g., build.yml) or a numeric run ID.

.PARAMETER Branch
Optional branch to scope workflow lookup.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)] [string]$Target,
    [string]$Branch,
    [switch]$DryRun,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/util-common.ps1"
Ensure-Gh -AllowDryRun:$true
$repo = Get-RepoSlug
Initialize-Log -DryRun:$DryRun -Repo $repo -Json:$Json

function Resolve-RunId {
    param([string]$Target, [string]$Branch)
    if ($Target -match '^[0-9]+$') { return $Target }
    $listArgs = @('gh','run','list','-R',$repo,'--workflow',$Target,'-L','1','--json','databaseId','--jq','.[0].databaseId')
    if ($Branch) { $listArgs += @('--branch', $Branch) }
    if ($PSBoundParameters.ContainsKey('Branch')) { $null = $Branch }
    if ($PSBoundParameters.ContainsKey('Target')) { $null = $Target }
    if ($DryRun) {
        Invoke-Logged -DryRun:$true -Cmd $listArgs
        return '<resolved-run-id>'
    }
    $rid = (& @listArgs 2>$null).Trim()
    return $rid
}

$runId = Resolve-RunId -Target $Target -Branch $Branch
if (-not $runId) {
    Write-Error 'error: No workflow run found' -ErrorAction Stop
}

Invoke-Logged -DryRun:$DryRun -Cmd @('gh','run','watch','-R',$repo,$runId,'--exit-status')
Invoke-Logged -DryRun:$DryRun -Cmd @('gh','run','view','-R',$repo,$runId)

$extra = @{ target = $Target; branch = $Branch; runId = $runId }
Flush-Log -Json:$Json -Extra $extra
