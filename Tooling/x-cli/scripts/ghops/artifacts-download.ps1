<#
.SYNOPSIS
Downloads artifacts for a run into an output directory.

.PARAMETER Run
Run ID to download artifacts from.

.PARAMETER Workflow
Workflow filename; resolves latest run when Run not specified.

.PARAMETER Branch
Optional branch when resolving latest run.

.PARAMETER Out
Output directory (created if missing).
#>
[CmdletBinding()]
param(
    [string]$Run,
    [string]$Workflow,
    [string]$Branch,
    [Parameter(Mandatory=$true)] [Alias('o')] [string]$Out,
    [switch]$DryRun,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/util-common.ps1"
Ensure-Gh -AllowDryRun:$DryRun
$repo = Get-RepoSlug
Initialize-Log -DryRun:$DryRun -Repo $repo -Json:$Json

if (-not (Test-Path -LiteralPath $Out)) {
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
}

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
    Write-Error 'error: No workflow run found to download artifacts from' -ErrorAction Stop
}

Invoke-Logged -DryRun:$DryRun -Cmd @('gh','run','download','-R',$repo,$runId,'-D',$Out)
Write-Notice "Artifacts downloaded to: $Out"

$extra = @{ run = $Run; workflow = $Workflow; branch = $Branch; out = (Resolve-Path -LiteralPath $Out).Path; runId = $runId }
Flush-Log -Json:$Json -Extra $extra
