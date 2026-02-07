<#
.SYNOPSIS
    Iterates local dev-mode enable/disable runs for 64-bit coverage.

.DESCRIPTION
    Runs local dev-mode enable/disable cycles without GitHub Actions by invoking
    Set_Development_Mode.ps1 and RevertDevelopmentMode.ps1. The underlying
    scripts parse g-cli output for dev-mode error codes.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    LabVIEW bitness to target ("32" or "64"). Defaults to "64".

.PARAMETER Iterations
    Number of cycles to run.

.PARAMETER ModeSequence
    Order of modes to run per iteration (default: enable, disable).

.PARAMETER PauseSeconds
    Optional delay between mode runs.

.PARAMETER ContinueOnDevModeFailure
    Continue iterations when a known dev-mode error (-593450/-593451) occurs.

.PARAMETER CaptureTranscript
    Capture host output to a transcript file alongside the iteration log.

.PARAMETER TranscriptPath
    Optional transcript path. If omitted and CaptureTranscript is set, a default
    transcript file is created next to the iteration log.

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.

.PARAMETER WorktreeRoot
    Optional override for the worktree root used by guardrails.

.PARAMETER SkipWorktreeRootCheck
    Skip enforcing that RepoRoot is under the worktree root.

.PARAMETER AutoWorktree
    Auto-create a short-path worktree and re-run from there when needed.

.PARAMETER RunId
    Optional run identifier used for artifact isolation.

.PARAMETER ArtifactRoot
    Optional override for the artifact output root.

.PARAMETER CleanRoom
    If set, purge known output folders before and after the run.

.EXAMPLE
    .\Tooling\DevModeIterate.ps1 -Iterations 3 -SupportedBitness 64

.EXAMPLE
    .\Tooling\DevModeIterate.ps1 -Iterations 1 -ModeSequence enable,enable,disable -ContinueOnDevModeFailure -CaptureTranscript
#>

param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness = '64',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$Iterations = 1,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('disable', 'enable', IgnoreCase = $true)]
    [string[]]$ModeSequence = @('enable', 'disable'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 3600)]
    [int]$PauseSeconds = 0,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnDevModeFailure,

    [Parameter(Mandatory = $false)]
    [switch]$CaptureTranscript,

    [Parameter(Mandatory = $false)]
    [string]$TranscriptPath,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [switch]$SkipWorktreeRootCheck,

    [switch]$AutoWorktree,

    [string]$RunId,

    [string]$ArtifactRoot,

    [switch]$CleanRoom
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$artifactRootResolved = $null
$preflight = $null
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $repoRoot `
        -WorktreeRoot $WorktreeRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $SupportedBitness `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$AutoWorktree `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs `
        -RunId $RunId `
        -ArtifactRoot $ArtifactRoot `
        -CleanRoom:$CleanRoom
    if ($preflight.Reinvoked) {
        return
    }
    $repoRoot = $preflight.RepoRoot
    $artifactRootResolved = $preflight.ArtifactRoot
}
$versionHelper = Join-Path -Path $repoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}
$logPathResolved = $LogPath
if ([string]::IsNullOrWhiteSpace($logPathResolved)) {
    $logDir = if ($artifactRootResolved) { Join-Path -Path $artifactRootResolved -ChildPath 'logs' } else { Join-Path -Path $repoRoot -ChildPath 'Tooling\logs' }
    $null = New-Item -Path $logDir -ItemType Directory -Force
    $logPathResolved = Join-Path -Path $logDir -ChildPath ("dev-mode-iterate-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
} else {
    $logDir = Split-Path -Parent -Path $logPathResolved
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        $null = New-Item -Path $logDir -ItemType Directory -Force
    }
}

$setScript = Join-Path -Path $repoRoot -ChildPath '.github\actions\set-development-mode\Set_Development_Mode.ps1'
$revertScript = Join-Path -Path $repoRoot -ChildPath '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'

if (-not (Test-Path -Path $setScript)) {
    throw "Set_Development_Mode.ps1 not found at $setScript"
}

if (-not (Test-Path -Path $revertScript)) {
    throw "RevertDevelopmentMode.ps1 not found at $revertScript"
}

$scriptArgs = @{
    LabVIEWVersion            = $labviewYear
    SupportedBitness          = $SupportedBitness
    RepoRoot              = $repoRoot
}

function Write-IterationLog {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format o
    $line = "$timestamp $Message"
    $line | Out-File -FilePath $logPathResolved -Append -Encoding ascii
    Write-Host $line
}

function Resolve-TranscriptPath {
    param(
        [string]$LogPath,
        [string]$TranscriptOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($TranscriptOverride)) {
        return $TranscriptOverride
    }

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        return $null
    }

    if ($LogPath.ToLower().EndsWith('.log')) {
        return ($LogPath.Substring(0, $LogPath.Length - 4) + '.transcript.log')
    }

    return ($LogPath + '.transcript.log')
}

function Test-IsDevModeFailure {
    param(
        [string[]]$OutputLines,
        [string]$Message
    )

    $combined = ''
    if ($OutputLines) {
        $combined += ($OutputLines -join "`n")
        $combined += "`n"
    }
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $combined += $Message
    }

    return ($combined -match '-593450' -or $combined -match '-593451')
}

function Invoke-DevModeScript {
    param(
        [string]$ScriptPath,
        [hashtable]$Arguments
    )

    $outputLines = @()
    $exitCode = $null
    $exceptionMessage = $null

    try {
        $rawOutput = & $ScriptPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        foreach ($entry in $rawOutput) {
            if ($null -ne $entry) {
                $outputLines += [string]$entry
            }
        }
    } catch {
        $exceptionMessage = $_.Exception.Message
    }

    return [pscustomobject]@{
        OutputLines      = $outputLines
        ExitCode         = $exitCode
        ExceptionMessage = $exceptionMessage
    }
}

Write-IterationLog ("start version={0} bitness={1} iterations={2} sequence={3} log={4}" -f `
    $labviewYear, $SupportedBitness, $Iterations, ($ModeSequence -join ','), $logPathResolved)

$transcriptActive = $false
$transcriptPathResolved = $null
if ($CaptureTranscript -or -not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
    $transcriptPathResolved = Resolve-TranscriptPath -LogPath $logPathResolved -TranscriptOverride $TranscriptPath
    if ($transcriptPathResolved) {
        try {
            Start-Transcript -Path $transcriptPathResolved -Append | Out-Null
            $transcriptActive = $true
            Write-IterationLog ("transcript started path={0}" -f $transcriptPathResolved)
        } catch {
            Write-IterationLog ("transcript_start_failed message={0}" -f $($_.Exception.Message))
        }
    }
}

try {
    for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
        foreach ($mode in $ModeSequence) {
            Write-IterationLog ("iteration={0} mode={1} event=start" -f $iteration, $mode)

            $scriptPath = if ($mode -eq 'enable') { $setScript } else { $revertScript }
            $result = Invoke-DevModeScript -ScriptPath $scriptPath -Arguments $scriptArgs
            $exitCodeValue = if ($null -eq $result.ExitCode) { 'null' } else { [string]$result.ExitCode }

            $hasFailure = $false
            $failureMessage = $null
            if (-not [string]::IsNullOrWhiteSpace($result.ExceptionMessage)) {
                $hasFailure = $true
                $failureMessage = $result.ExceptionMessage
            } elseif ($result.ExitCode -ne 0 -and $null -ne $result.ExitCode) {
                $hasFailure = $true
                $failureMessage = "Dev mode $mode failed with exit code $exitCodeValue."
            }

            if ($hasFailure) {
                $isKnown = Test-IsDevModeFailure -OutputLines $result.OutputLines -Message $failureMessage
                if ($ContinueOnDevModeFailure -and $isKnown) {
                    Write-IterationLog ("iteration={0} mode={1} event=known_failure message={2}" -f $iteration, $mode, $failureMessage)
                    if ($result.OutputLines -and $result.OutputLines.Count -gt 0) {
                        $outputJoined = $result.OutputLines -join ' | '
                        Write-IterationLog ("iteration={0} mode={1} event=output message={2}" -f $iteration, $mode, $outputJoined)
                    }
                } else {
                    Write-IterationLog ("iteration={0} mode={1} event=error message={2}" -f $iteration, $mode, $failureMessage)
                    if ($result.OutputLines -and $result.OutputLines.Count -gt 0) {
                        $outputJoined = $result.OutputLines -join ' | '
                        Write-IterationLog ("iteration={0} mode={1} event=output message={2}" -f $iteration, $mode, $outputJoined)
                    }
                    throw "Iteration $iteration failed while running mode '$mode': $failureMessage"
                }
            } else {
                Write-IterationLog ("iteration={0} mode={1} event=finish exit_code={2}" -f $iteration, $mode, $exitCodeValue)
            }

            if ($PauseSeconds -gt 0) {
                Start-Sleep -Seconds $PauseSeconds
            }
        }

        Write-IterationLog ("iteration={0} event=cycle_complete" -f $iteration)
    }

    Write-IterationLog ("completed iterations={0}" -f $Iterations)
} finally {
    if ($transcriptActive) {
        try {
            Stop-Transcript | Out-Null
            Write-IterationLog ("transcript stopped path={0}" -f $transcriptPathResolved)
        } catch {
            Write-IterationLog ("transcript_stop_failed message={0}" -f $($_.Exception.Message))
        }
    }
    if ($preflight -and $preflight.CleanRoomAfter) {
        Invoke-PreflightCleanup -RepoRoot $preflight.RepoRoot -Phase 'after'
    }
}


