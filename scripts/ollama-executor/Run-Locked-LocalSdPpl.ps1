<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed local-sd-ppl orchestration command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [int]$CommandTimeoutSec = 60,
    [int]$LabVIEWVersion = 2025,
    [ValidateSet('0','3')]
    [string]$LabVIEWMinor = '3',
    [ValidateSet('32','64')]
    [string]$Bitness = '64',
    [string]$SeedAssistantRunCommand
)

. "$PSScriptRoot/Resolve-OllamaHost.ps1"
. "$PSScriptRoot/CommandBuilder.ps1"
. "$PSScriptRoot/SeededWorktree.ps1"

$resolvedHost = Resolve-OllamaHost -RequestedHost $Endpoint
if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    Write-Host "[locked-local-sd-ppl] Auto-selected OLLAMA_HOST=$resolvedHost"
}
elseif ($resolvedHost -ne $Endpoint) {
    Write-Warning "Requested OLLAMA_HOST '$Endpoint' was unreachable; fell back to '$resolvedHost'."
}
if ([string]::IsNullOrWhiteSpace($Model)) {
    $Model = "llama3-8b-local:latest"
    Write-Warning "OLLAMA_MODEL_TAG missing; defaulting to '$Model'. Override with -Model or set the env var."
}

$healthParams = @{
    Host            = $resolvedHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams

$seededInfo = Get-SeededWorktree -RepoPath $RepoPath -TargetLabVIEWVersion $LabVIEWVersion -TargetLabVIEWMinor $LabVIEWMinor -TargetBitness $Bitness
$worktreePath = $seededInfo.WorktreePath
$repoArgument = Format-CommandValue $worktreePath
$pplCmd = "pwsh -NoProfile -File scripts/orchestration/Run-LocalSd-Ppl.ps1 -Repo $repoArgument -RunKey local-sd-ppl"
$effectiveCmd = if (-not [string]::IsNullOrWhiteSpace($SeedAssistantRunCommand)) { $SeedAssistantRunCommand.Trim() } else { $pplCmd }
$allowedRuns = @($effectiveCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $effectiveCmd + '"} and then {"done":true}.'

$params = @{
    Host                 = $resolvedHost
    Model                 = $Model
    RepoPath              = $worktreePath
    Goal                  = $goal
    MaxTurns              = 2
    StopAfterFirstCommand = $true
    AllowedRuns           = $allowedRuns
    CommandTimeoutSec     = $CommandTimeoutSec
    SeedAssistantRunCommand = $effectiveCmd
}

& "$PSScriptRoot/Drive-Ollama-Executor.ps1" @params -Verbose

# Explicit exit code for CI/CD
exit $LASTEXITCODE
