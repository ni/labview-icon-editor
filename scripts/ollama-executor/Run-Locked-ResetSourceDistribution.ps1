<#!
.SYNOPSIS
    Runs the locked Ollama executor to reset/archive the Source Distribution workspace through OrchestrationCli reset-source-dist.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [int]$CommandTimeoutSec = 600,
    [string]$SummaryRelativePath = "builds/reports/source-dist-reset.json",
    [int]$MaxExecutorAttempts = 1,
    [int]$LabVIEWVersion = 2025,
    [ValidateSet('0','3')]
    [string]$LabVIEWMinor = '3',
    [ValidateSet('32','64')]
    [string]$Bitness = '64',
    [string]$SeedAssistantRunCommand
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. "$PSScriptRoot/Resolve-OllamaHost.ps1"
. "$PSScriptRoot/CommandBuilder.ps1"
. "$PSScriptRoot/SeededWorktree.ps1"

$script:LockedResetStepIndex = 0
function Invoke-LockedResetStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    $script:LockedResetStepIndex++
    $prefix = "[locked-reset][step $($script:LockedResetStepIndex)]"
    Write-Host "$prefix $Name"
    try {
        $result = & $Action
        Write-Host "$prefix ✓ $Name"
        return $result
    }
    catch {
        Write-Error "$prefix ✗ $Name failed: $($_.Exception.Message)"
        throw
    }
}

function Test-CommandCompliance {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        throw "Command cannot be empty."
    }

    $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
    if ($Command -notmatch $allowedPattern) {
        throw "Command '$Command' does not match allowlisted prefix pattern."
    }

    if ($Command -match '\.\.[/\\]') {
        throw "Command '$Command' contains path traversal sequences."
    }

    if ($Command -match '[;&|`]' -or $Command -match '<<' -or $Command -match '@\{') {
        throw "Command '$Command' contains disallowed chaining/injection tokens."
    }
}

$resolvedHost = Invoke-LockedResetStep -Name "Resolve Ollama host" -Action {
    $hostValue = Resolve-OllamaHost -RequestedHost $Endpoint
    if ([string]::IsNullOrWhiteSpace($Endpoint)) {
        Write-Host "[locked-reset] Auto-selected OLLAMA_HOST=$hostValue"
    }
    elseif ($hostValue -ne $Endpoint) {
        Write-Warning "Requested OLLAMA_HOST '$Endpoint' was unreachable; fell back to '$hostValue'."
    }
    return $hostValue
}

if ([string]::IsNullOrWhiteSpace($Model)) {
    $Model = "llama3-8b-local:latest"
    Write-Warning "OLLAMA_MODEL_TAG missing; defaulting to '$Model'. Override with -Model or set the env var."
}

Invoke-LockedResetStep -Name "Ollama health check" -Action {
    $healthParams = @{
        Host            = $resolvedHost
        ModelTag        = $Model
        RequireModelTag = $true
    }
    & "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams
}

Write-Host "[locked-reset] Target: Source Distribution workspace cleanup"

$seededInfo = Invoke-LockedResetStep -Name "Ensure seeded worktree" -Action {
    Get-SeededWorktree -RepoPath $RepoPath -TargetLabVIEWVersion $LabVIEWVersion -TargetLabVIEWMinor $LabVIEWMinor -TargetBitness $Bitness
}
$worktreePath = $seededInfo.WorktreePath

$summaryPath = if ([string]::IsNullOrWhiteSpace($SummaryRelativePath)) { "builds/reports/source-dist-reset.json" } else { $SummaryRelativePath }
$resetCliArgs = @(
    'reset-source-dist',
    '--repo', $worktreePath,
    '--reset-archive-existing',
    '--reset-run-commit-index',
    '--reset-run-full-build',
    '--reset-emit-summary',
    '--reset-summary-json', $summaryPath,
    '--reset-additional-path', 'builds/cache'
)

$resetCmd = Invoke-LockedResetStep -Name "Build invoke-repo-cli command" -Action {
    New-InvokeRepoCliCommandString -CliName 'OrchestrationCli' -RepoRoot $worktreePath -CliArguments $resetCliArgs
}

Invoke-LockedResetStep -Name "Decompose command" -Action {
    $plan = [pscustomobject]@{
        CliName   = 'OrchestrationCli'
        RepoRoot  = '.'
        Arguments = $resetCliArgs
        Command   = $resetCmd
    }
    Write-Host ($plan | ConvertTo-Json -Depth 4)
}

$effectiveCmd = Invoke-LockedResetStep -Name "Select executor command" -Action {
    if (-not [string]::IsNullOrWhiteSpace($SeedAssistantRunCommand)) {
        Write-Host "[locked-reset] Using supplied SeedAssistantRunCommand override."
        return $SeedAssistantRunCommand.Trim()
    }
    return $resetCmd
}

Invoke-LockedResetStep -Name "Atomic command compliance verification" -Action {
    Test-CommandCompliance -Command $effectiveCmd
}

$allowedRuns = @($effectiveCmd)
$goal = "Respond ONLY with JSON: send exactly {`"run`":`"$effectiveCmd`"} and then {`"done`":true}."

$params = @{
    Host                 = $resolvedHost
    Model                = $Model
    RepoPath             = $worktreePath
    Goal                 = $goal
    MaxTurns             = 4
    StopAfterFirstCommand= $true
    AllowedRuns          = $allowedRuns
    CommandTimeoutSec    = $CommandTimeoutSec
    SeedAssistantRunCommand = $effectiveCmd
}

$attempt = 0
$exitCode = 1
while ($attempt -lt [Math]::Max(1, $MaxExecutorAttempts)) {
    $attempt++
    $attemptLabel = "Drive executor attempt #$attempt"
    $exitCode = Invoke-LockedResetStep -Name $attemptLabel -Action {
        & "$PSScriptRoot/Drive-Ollama-Executor.ps1" @params -Verbose
        return $LASTEXITCODE
    }

    if ($exitCode -eq 0) {
        break
    }

    if ($attempt -ge $MaxExecutorAttempts) {
        throw "Drive-Ollama-Executor failed after $attempt attempts (last exit code $exitCode)."
    }

    Write-Warning "[locked-reset] Executor attempt $attempt failed (exit $exitCode); retrying..."
}

exit $exitCode
