<#
.SYNOPSIS
Reruns a workflow run by ID or resolves the latest by workflow/branch.

.PARAMETER Run
Run ID to rerun.

.PARAMETER Workflow
Workflow filename to resolve the latest run from.

.PARAMETER Branch
Optional branch when resolving latest run.

.PARAMETER Failed
Only rerun failed jobs.
#>
[CmdletBinding()]
param(
    [string]$Run,
    [string]$Workflow,
    [string]$Branch,
    [switch]$Failed,
    [switch]$DryRun,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/util-common.ps1"
Ensure-Gh -AllowDryRun:$DryRun
$repo = Get-RepoSlug
Initialize-Log -DryRun:$DryRun -Repo $repo -Json:$Json

function Resolve-RunId {
    param([string]$Workflow,[string]$Branch)
    if (-not $Workflow) { return '' }
    $listArgs = @('gh','run','list','-R',$repo,'--workflow',$Workflow,'-L','1','--json','databaseId','--jq','.[0].databaseId')
    if ($Branch) { $listArgs += @('--branch', $Branch) }
    if ($DryRun) {
        Invoke-Logged -DryRun:$true -Cmd $listArgs
        return '<resolved-run-id>'
    }
    $rid = (& @listArgs 2>$null).Trim()
    return $rid
}

$runId = $Run
if (-not $runId) {
    if (-not $Workflow) {
    Write-Error 'error: Provide --Run <id> or --Workflow <file> [--Branch <name>]' -ErrorAction Stop
}
    $runId = Resolve-RunId -Workflow $Workflow -Branch $Branch
}

if (-not $runId) {
    Write-Error 'error: No workflow run found to rerun' -ErrorAction Stop
}

$argsList = @('gh','run','rerun','-R',$repo)
if ($Failed.IsPresent) { $argsList += '--failed' }
$argsList += $runId

Invoke-Logged -DryRun:$DryRun -Cmd $argsList
Write-Notice "Rerun triggered for run $runId"

$extra = @{ run = $Run; workflow = $Workflow; branch = $Branch; failed = [bool]$Failed; runId = $runId }
Flush-Log -Json:$Json -Extra $extra
