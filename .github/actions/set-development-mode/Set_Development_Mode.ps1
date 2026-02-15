<#
#    .SYNOPSIS
#        Configures the repository for development mode.
#
#    .DESCRIPTION
#        Configures the repository for development mode by invoking
#        PrepareIESource.vi for each LabVIEW bitness. LabVIEW is closed after
#        each run by the helper so downstream steps load the changes.
#
#    .PARAMETER LabVIEWVersion
#        LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).
#
#    .PARAMETER SupportedBitness
#        One or more bitness values ("32", "64") to run (default: both).
#
#    .PARAMETER RepoRoot
#        Optional path to the repository root.
#
#    .PARAMETER ConnectTimeoutMs
#        g-cli connect timeout in milliseconds (0 disables the timeout).
#
#    .PARAMETER ProcessTimeoutMs
#        Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).
#
#    .PARAMETER UseLabVIEW
#        Use LabVIEW + g-cli to toggle development mode. Defaults to using the
#        no-LabVIEW path when omitted.
#
#    .PARAMETER AllowFallbackToNoLabVIEW
#        When UseLabVIEW is set, allow fallback to the no-LabVIEW path if the
#        LabVIEW toggle fails.
#
#    .PARAMETER SkipToggle
#        Skip the snapshot-enabled Toggle-DevMode entrypoint.
#
#    .PARAMETER SnapshotRoot
#        Optional snapshot root for Toggle-DevMode.
#
#    .PARAMETER SnapshotName
#        Optional snapshot folder name when SnapshotRoot is not provided.
#
#    .PARAMETER SkipSnapshot
#        Skip snapshot creation in Toggle-DevMode.
#
#    .PARAMETER RestoreOnFailure
#        Attempt restore when Toggle-DevMode fails (default: true).
#
#    .EXAMPLE
#        .\Set_Development_Mode.ps1  # Uses .lvversion by default
#
#>

param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string[]]$SupportedBitness = @('32', '64'),

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [Parameter(Mandatory = $false)]
    [switch]$UseLabVIEW,

    [Parameter(Mandatory = $false)]
    [switch]$AllowFallbackToNoLabVIEW,

    [Parameter(Mandatory = $false)]
    [switch]$SkipToggle,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotRoot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSnapshot,

    [Parameter(Mandatory = $false)]
    [bool]$RestoreOnFailure = $true
)

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Host "Script Directory: $ScriptDirectory"

# Build paths to the helper scripts
$PrepareScript = Join-Path -Path $ScriptDirectory -ChildPath '..\prepare-labview-source\Prepare_LabVIEW_source.ps1'
$CloseScript = Join-Path -Path $ScriptDirectory -ChildPath '..\close-labview\Close_LabVIEW.ps1'

Write-Host "Prepare_LabVIEW_source script: $PrepareScript"
Write-Host "Close_LabVIEW script: $CloseScript"

$ErrorActionPreference = 'Stop'

$devModePolicyHelper = Join-Path $PSScriptRoot '..\..\..\Tooling\support\DevModePolicy.ps1'
if (-not (Test-Path -LiteralPath $devModePolicyHelper -PathType Leaf)) {
    throw "Dev mode policy helper not found: $devModePolicyHelper"
}
. $devModePolicyHelper
Assert-DevModeInvocationBlocked -EntryPoint $PSCommandPath

function Test-ForceNoLabVIEWDevMode {
    $value = $env:LVIE_FORCE_NO_LABVIEW_DEVMODE
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }
    $normalized = $value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function Resolve-BoolFromEnv {
    param(
        [string]$Name,
        [bool]$Fallback = $false
    )

    if (-not (Test-Path "Env:$Name")) {
        return $Fallback
    }

    $raw = (Get-Item "Env:$Name").Value
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Fallback
    }

    $normalized = $raw.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

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

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

$resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$versionHelper = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

if (Test-ForceNoLabVIEWDevMode) {
    if ($UseLabVIEW) {
        Write-Host 'LVIE_FORCE_NO_LABVIEW_DEVMODE=1; ignoring UseLabVIEW.'
    }
    $UseLabVIEW = $false
    if (-not $SkipToggle) {
        Write-Host 'LVIE_FORCE_NO_LABVIEW_DEVMODE=1; forcing direct no-LabVIEW path (SkipToggle).'
        $SkipToggle = $true
    }
}

if (-not $SkipToggle) {
    $toggleScript = Join-Path $resolvedRepoRoot 'Tooling\Toggle-DevMode.ps1'
    if (-not (Test-Path -Path $toggleScript)) {
        throw "Toggle-DevMode.ps1 not found at $toggleScript"
    }

    $toggleParams = @{
        Mode             = 'enable'
        LabVIEWVersion   = $labviewYear
        SupportedBitness = $SupportedBitness
        RepoRoot         = $resolvedRepoRoot
        ConnectTimeoutMs = $ConnectTimeoutMs
        ProcessTimeoutMs = $ProcessTimeoutMs
        RestoreOnFailure = $RestoreOnFailure
    }
    if ($UseLabVIEW) {
        $toggleParams.UseLabVIEW = $true
    }
    if ($AllowFallbackToNoLabVIEW) {
        $toggleParams.AllowFallbackToNoLabVIEW = $true
    }
    if ($SkipSnapshot) {
        $toggleParams.SkipSnapshot = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotRoot)) {
        $toggleParams.SnapshotRoot = $SnapshotRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotName)) {
        $toggleParams.SnapshotName = $SnapshotName
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_DEBUG_TOGGLE_ARGS)) {
        $paramSummary = ($toggleParams.GetEnumerator() | Sort-Object Key | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '; '
        Write-Host ("Toggle-DevMode params: {0}" -f $paramSummary)
    }
    try {
        & $toggleScript @toggleParams
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Toggle-DevMode.ps1 failed with exit code $LASTEXITCODE."
        }
    } catch {
        Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
        exit 1
    }
    return
}

if (-not $UseLabVIEW) {
    $noLabviewScript = Join-Path $resolvedRepoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
    if (-not (Test-Path -Path $noLabviewScript)) {
        throw "Set-DevelopmentMode-NoLabVIEW.ps1 not found at $noLabviewScript"
    }

    Write-Host ("Using no-LabVIEW dev mode path (LV{0})..." -f $labviewYear)
    try {
        & $noLabviewScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness $SupportedBitness `
            -RepoRoot $resolvedRepoRoot

        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Set-DevelopmentMode-NoLabVIEW.ps1 failed with exit code $LASTEXITCODE."
        }
    } catch {
        $allowAccessDenied = Resolve-BoolFromEnv -Name 'LVIE_ALLOW_NO_LABVIEW_ACCESS_DENIED' -Fallback (Resolve-BoolFromEnv -Name 'LVIE_RUNNER_ACL_WARN_ONLY' -Fallback $false)
        $message = $_.Exception.Message
        $accessDenied = $message -match '(?i)\baccess\b.*\bdenied\b'
        if ($allowAccessDenied -and $accessDenied) {
            Write-Warning ("No-LabVIEW dev mode enable failed with access denied; continuing due policy. Details: {0}" -f $message)
            return
        }
        throw
    }

    return
}

function Write-CloseMetricsHint {
    param(
        [string]$Bitness,
        [string]$Context,
        [string]$ExpectedVersion
    )

    $metricsPath = $env:LABVIEW_CLOSE_METRICS_PATH
    if ([string]::IsNullOrWhiteSpace($metricsPath)) {
        return
    }

    if (Test-Path -Path $metricsPath) {
        $lines = @()
        try {
            $lines = Get-Content -Path $metricsPath -Tail 50 | Where-Object { $_ -and $_ -notmatch '^timestamp,' }
        } catch {
            Write-Warning ("Failed to read close metrics at {0}: {1}" -f $metricsPath, $_.Exception.Message)
            return
        }

        if (-not $lines -or $lines.Count -eq 0) {
            Write-Host ("Close metrics file is empty: {0}" -f $metricsPath)
            return
        }

        $entries = foreach ($line in $lines) {
            $parts = $line -split ',', 6
            if ($parts.Length -ge 6) {
                [pscustomobject]@{
                    Line      = $line
                    Timestamp = $parts[0]
                    Version   = $parts[1]
                    Bitness   = $parts[2]
                    HadProc   = $parts[3]
                    Outcome   = $parts[4]
                    Duration  = $parts[5]
                }
            }
        }

        $match = $entries | Where-Object { $_.Version -eq $ExpectedVersion -and $_.Bitness -eq $Bitness } | Select-Object -Last 1
        if ($match) {
            Write-Host ("Close metrics ({0}) {1}-bit: version={2} outcome={3} duration_s={4} had_process={5} timestamp={6}" -f `
                    $Context, $Bitness, $match.Version, $match.Outcome, $match.Duration, $match.HadProc, $match.Timestamp)
            return
        }

        $lastEntry = $entries | Select-Object -Last 1
        if ($lastEntry) {
            Write-Warning ("Close metrics ({0}) {1}-bit: no matching entry for version {2}; last entry: {3}" -f `
                    $Context, $Bitness, $ExpectedVersion, $lastEntry.Line)
        } else {
            Write-Warning ("Close metrics ({0}) {1}-bit: no parsable entries found in {2}" -f $Context, $Bitness, $metricsPath)
        }

        return
    }

    Write-Host ("Close metrics path set but file not found: {0}" -f $metricsPath)
}

function Invoke-PrepareLabviewSource {
    param(
        [string]$Bitness
    )

    Write-Host "Preparing LabVIEW sources for $Bitness-bit."
    # Prepare_LabVIEW_source.ps1 closes LabVIEW after the VI runs.
    $scriptArgs = @{
        LabVIEWVersion            = $labviewYear
        SupportedBitness          = $Bitness
        ConnectTimeoutMs          = $ConnectTimeoutMs
        ProcessTimeoutMs          = $ProcessTimeoutMs
    }

    if ($resolvedRepoRoot) {
        $scriptArgs.RepoRoot = $resolvedRepoRoot
    }

    & $PrepareScript @scriptArgs

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Prepare_LabVIEW_source.ps1 failed for $Bitness-bit with exit code $LASTEXITCODE."
    }

    Write-CloseMetricsHint -Bitness $Bitness -Context 'set-dev-mode' -ExpectedVersion $labviewYear
}

try {
    $bitnesses = $SupportedBitness | Select-Object -Unique
    foreach ($bitness in $bitnesses) {
        Invoke-PrepareLabviewSource -Bitness $bitness
    }
}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

