#Requires -Version 7.0
<#
.SYNOPSIS
    Toggles LabVIEW Icon Editor dev mode with snapshot and restore support.

.DESCRIPTION
    Captures a snapshot before toggling dev mode and restores it if the toggle
    fails. Uses the no-LabVIEW path by default, with an option to force the
    LabVIEW + g-cli path.

.PARAMETER Mode
    Dev mode action: enable or disable.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    One or more bitness values ("32", "64") to run (default: both).

.PARAMETER RepoRoot
    Optional path to the repository root.

.PARAMETER ConnectTimeoutMs
    g-cli connect timeout in milliseconds (0 disables the timeout).

.PARAMETER ProcessTimeoutMs
    Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).

.PARAMETER UseLabVIEW
    Use LabVIEW + g-cli to toggle development mode.

.PARAMETER AllowFallbackToNoLabVIEW
    When UseLabVIEW is set, allow fallback to the no-LabVIEW path if the
    LabVIEW toggle fails.

.PARAMETER SnapshotRoot
    Optional snapshot root to pass to DevModeSnapshot.ps1.

.PARAMETER SnapshotName
    Optional snapshot folder name when SnapshotRoot is not provided.

.PARAMETER SkipSnapshot
    Skip snapshot creation.

.PARAMETER RestoreOnFailure
    Attempt to restore snapshot when toggle fails (default: true).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('enable', 'disable', IgnoreCase = $true)]
    [string]$Mode,

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
    [string]$SnapshotRoot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSnapshot,

    [Parameter(Mandatory = $false)]
    [bool]$RestoreOnFailure = $true
)

$ErrorActionPreference = 'Stop'

$devModePolicyHelper = Join-Path $PSScriptRoot 'support\DevModePolicy.ps1'
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

function Resolve-LogPath {
    param(
        [string]$ResolvedRepoRoot,
        [string]$SnapshotRootResolved
    )

    if (-not [string]::IsNullOrWhiteSpace($SnapshotRootResolved)) {
        return (Join-Path -Path $SnapshotRootResolved -ChildPath 'dev-mode-toggle.json')
    }

    $logDir = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\logs'
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    return (Join-Path -Path $logDir -ChildPath ("dev-mode-toggle-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
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
}

$bitnesses = $SupportedBitness | Select-Object -Unique
$snapshotRootResolved = $null
if (-not $SkipSnapshot) {
    $snapshotScript = Join-Path $resolvedRepoRoot 'Tooling\DevModeSnapshot.ps1'
    if (-not (Test-Path -Path $snapshotScript)) {
        throw "DevModeSnapshot.ps1 not found at $snapshotScript"
    }

    $snapshotParams = @{
        LabVIEWVersion            = $labviewYear
        SupportedBitness          = $bitnesses
        RepoRoot                  = $resolvedRepoRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotRoot)) {
        $snapshotParams.SnapshotRoot = $SnapshotRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($SnapshotName)) {
        $snapshotParams.SnapshotName = $SnapshotName
    }

    $snapshotOutput = & $snapshotScript @snapshotParams
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "DevModeSnapshot.ps1 failed with exit code $LASTEXITCODE."
    }

    if ($snapshotOutput) {
        $snapshotRootResolved = ($snapshotOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
    }
    if ([string]::IsNullOrWhiteSpace($snapshotRootResolved)) {
        $snapshotRootResolved = $SnapshotRoot
    }
}

$toggleRecord = [ordered]@{
    Mode             = $Mode
    UseLabVIEW       = [bool]$UseLabVIEW
    AllowFallback    = [bool]$AllowFallbackToNoLabVIEW
    LabVIEWYear      = $labviewYear
    SupportedBitness = $bitnesses
    RepoRoot         = $resolvedRepoRoot
    SnapshotRoot     = $snapshotRootResolved
    StartUtc         = (Get-Date).ToUniversalTime().ToString('o')
}

$toggleSuccess = $false
$restoreAttempted = $false
$restoreSucceeded = $false
$labviewAttempted = $false
$labviewSucceeded = $false
$labviewError = $null
$fallbackAttempted = $false
$fallbackSucceeded = $false
$fallbackError = $null

try {
    if ($UseLabVIEW) {
        $labviewAttempted = $true
        $scriptPath = if ($Mode -eq 'enable') {
            Join-Path $resolvedRepoRoot '.github\actions\set-development-mode\Set_Development_Mode.ps1'
        } else {
            Join-Path $resolvedRepoRoot '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
        }
        if (-not (Test-Path -Path $scriptPath)) {
            throw "Dev mode script not found at $scriptPath"
        }
        $scriptArgs = @(
            '-NoProfile',
            '-File', $scriptPath,
            '-LabVIEWVersion', $labviewYear,
            '-SupportedBitness'
        ) + $bitnesses + @(
            '-RepoRoot', $resolvedRepoRoot,
            '-ConnectTimeoutMs', $ConnectTimeoutMs,
            '-ProcessTimeoutMs', $ProcessTimeoutMs,
            '-UseLabVIEW',
            '-SkipToggle'
        )
        try {
            & pwsh @scriptArgs
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "Dev mode $Mode (LabVIEW) failed with exit code $LASTEXITCODE."
            }
            $labviewSucceeded = $true
        } catch {
            $labviewError = $_
        }

        if ($labviewError) {
            if ($AllowFallbackToNoLabVIEW) {
                $fallbackAttempted = $true
                Write-Warning ("Dev mode {0} failed via LabVIEW; attempting no-LabVIEW fallback." -f $Mode)
                $fallbackScript = if ($Mode -eq 'enable') {
                    Join-Path $resolvedRepoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
                } else {
                    Join-Path $resolvedRepoRoot 'Tooling\Revert-DevelopmentMode-NoLabVIEW.ps1'
                }
                if (-not (Test-Path -Path $fallbackScript)) {
                    throw "Dev mode fallback script not found at $fallbackScript"
                }
                $fallbackArgs = @(
                    '-NoProfile',
                    '-File', $fallbackScript,
                    '-LabVIEWVersion', $labviewYear,
                    '-SupportedBitness'
                ) + $bitnesses + @(
                    '-RepoRoot', $resolvedRepoRoot
                )
                try {
                    & pwsh @fallbackArgs
                    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                        throw "Dev mode $Mode (no LabVIEW fallback) failed with exit code $LASTEXITCODE."
                    }
                    $fallbackSucceeded = $true
                    $toggleSuccess = $true
                } catch {
                    $fallbackError = $_
                    throw
                }
            } else {
                throw $labviewError
            }
        } else {
            $toggleSuccess = $true
        }
    } else {
        $scriptPath = if ($Mode -eq 'enable') {
            Join-Path $resolvedRepoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
        } else {
            Join-Path $resolvedRepoRoot 'Tooling\Revert-DevelopmentMode-NoLabVIEW.ps1'
        }
        if (-not (Test-Path -Path $scriptPath)) {
            throw "Dev mode script not found at $scriptPath"
        }
        $scriptArgs = @(
            '-NoProfile',
            '-File', $scriptPath,
            '-LabVIEWVersion', $labviewYear,
            '-SupportedBitness'
        ) + $bitnesses + @(
            '-RepoRoot', $resolvedRepoRoot
        )
        & pwsh @scriptArgs
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Dev mode $Mode (no LabVIEW) failed with exit code $LASTEXITCODE."
        }
        $toggleSuccess = $true
    }
} catch {
    $toggleRecord.Error = $_.Exception.Message
    if ($RestoreOnFailure -and -not [string]::IsNullOrWhiteSpace($snapshotRootResolved)) {
        $restoreAttempted = $true
        try {
            $restoreScript = Join-Path $resolvedRepoRoot 'Tooling\DevModeRestore.ps1'
            if (-not (Test-Path -Path $restoreScript)) {
                throw "DevModeRestore.ps1 not found at $restoreScript"
            }
            & $restoreScript -SnapshotRoot $snapshotRootResolved
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "DevModeRestore.ps1 failed with exit code $LASTEXITCODE."
            }
            $restoreSucceeded = $true
        } catch {
            $toggleRecord.RestoreError = $_.Exception.Message
        }
    }
    throw
} finally {
    $toggleRecord.Success = $toggleSuccess
    $toggleRecord.RestoreAttempted = $restoreAttempted
    $toggleRecord.RestoreSucceeded = $restoreSucceeded
    $toggleRecord.LabVIEWAttempted = $labviewAttempted
    $toggleRecord.LabVIEWSucceeded = $labviewSucceeded
    if ($labviewError) {
        $toggleRecord.LabVIEWError = $labviewError.Exception.Message
    }
    $toggleRecord.FallbackAttempted = $fallbackAttempted
    $toggleRecord.FallbackSucceeded = $fallbackSucceeded
    if ($fallbackError) {
        $toggleRecord.FallbackError = $fallbackError.Exception.Message
    }
    $toggleRecord.EndUtc = (Get-Date).ToUniversalTime().ToString('o')
    $logPath = Resolve-LogPath -ResolvedRepoRoot $resolvedRepoRoot -SnapshotRootResolved $snapshotRootResolved
    $toggleRecord | ConvertTo-Json -Depth 7 | Set-Content -Path $logPath -Encoding utf8
}

