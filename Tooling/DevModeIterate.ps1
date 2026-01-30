<#
.SYNOPSIS
    Iterates local dev-mode enable/disable runs for 64-bit coverage.

.DESCRIPTION
    Runs local dev-mode enable/disable cycles without GitHub Actions by invoking
    Set_Development_Mode.ps1 and RevertDevelopmentMode.ps1. The underlying
    scripts parse g-cli output for dev-mode error codes.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

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

.EXAMPLE
    .\Tooling\DevModeIterate.ps1 -Iterations 3 -MinimumSupportedLVVersion 2021 -SupportedBitness 64

.EXAMPLE
    .\Tooling\DevModeIterate.ps1 -Iterations 1 -ModeSequence enable,enable,disable -ContinueOnDevModeFailure -CaptureTranscript
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',

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
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$logPathResolved = $LogPath
if ([string]::IsNullOrWhiteSpace($logPathResolved)) {
    $logDir = Join-Path -Path $repoRoot -ChildPath 'Tooling\logs'
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
    MinimumSupportedLVVersion = $MinimumSupportedLVVersion
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
    $MinimumSupportedLVVersion, $SupportedBitness, $Iterations, ($ModeSequence -join ','), $logPathResolved)

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
            } elseif ($result.ExitCode -ne 0 -and $result.ExitCode -ne $null) {
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
}
