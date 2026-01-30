#Requires -Version 7.0
<#
.SYNOPSIS
    Repeats the local CI parity run until a VIP build succeeds.

.DESCRIPTION
    Invokes Run-CICompositeLocal.ps1 in a retry loop with adaptive timeouts.
    Uses the existing parity script for all work and logging.

.PARAMETER LabVIEWVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER MaxAttempts
    Maximum number of attempts.

.PARAMETER ConnectTimeoutMs
    Initial g-cli connect timeout passed to the parity script.

.PARAMETER ProcessTimeoutMs
    Initial g-cli process timeout passed to the parity script.

.PARAMETER ConnectTimeoutGrowth
    Growth multiplier applied after a failed attempt.

.PARAMETER ProcessTimeoutGrowth
    Growth multiplier applied after a failed attempt.

.PARAMETER MaxConnectTimeoutMs
    Upper bound for connect timeout.

.PARAMETER MaxProcessTimeoutMs
    Upper bound for process timeout.

.PARAMETER EnsureCleanState
    Revert dev mode before Verify IE Paths.

.PARAMETER UseWorktree
    Create a worktree under the configured root and run parity from there.

.PARAMETER WorktreeRoot
    Optional override for the worktree root (defaults to C:\dev or LVIE_WORKTREE_ROOT).

.PARAMETER WorktreeName
    Optional suffix used to name the worktree directory.

.PARAMETER RepoRoot
    Optional repository root override.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$LabVIEWVersion = '2021',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$MaxAttempts = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 180000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1.0, 5.0)]
    [double]$ConnectTimeoutGrowth = 1.5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1.0, 5.0)]
    [double]$ProcessTimeoutGrowth = 1.5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$MaxConnectTimeoutMs = 600000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 2400000)]
    [int]$MaxProcessTimeoutMs = 1200000,

    [Parameter(Mandatory = $false)]
    [switch]$EnsureCleanState,

    [Parameter(Mandatory = $false)]
    [bool]$UseWorktree = $true,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

function Ensure-CsvHeader {
    param(
        [string]$Path,
        [string]$Header
    )

    if (-not (Test-Path -Path $Path)) {
        $Header | Set-Content -Path $Path
    }
}

function Write-AutoHistoryEntry {
    param(
        [string]$Path,
        [string]$AttemptLabel,
        [string]$Status,
        [double]$DurationSeconds,
        [int]$ConnectTimeoutMs,
        [int]$ProcessTimeoutMs
    )

    if (-not $Path) {
        return
    }

    $safeStatus = $Status -replace ',', ' '
    "{0},{1},{2},{3},{4},{5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $AttemptLabel, $safeStatus, $DurationSeconds, $ConnectTimeoutMs, $ProcessTimeoutMs |
        Add-Content -Path $Path
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$runScript = Join-Path $repoRoot 'Tooling/Run-CICompositeLocal.ps1'
if (-not (Test-Path -Path $runScript)) {
    throw "Run-CICompositeLocal.ps1 not found at $runScript"
}

$runRepoRoot = $repoRoot
if ($UseWorktree) {
    $worktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
    if (-not (Test-Path -Path $worktreeScript)) {
        throw "New-CIWorktree.ps1 not found at $worktreeScript"
    }

    $suffix = if ([string]::IsNullOrWhiteSpace($WorktreeName)) { "ci-parity-auto-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss') } else { $WorktreeName }
    $runRepoRoot = & $worktreeScript -Ref HEAD -Name $suffix -WorktreeRoot $WorktreeRoot
    Write-Host ("Using worktree: {0}" -f $runRepoRoot)
}

$logRoot = Join-Path $repoRoot 'TestResults/agent-logs'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$historyPath = Join-Path $logRoot 'auto-run-history.csv'
Ensure-CsvHeader -Path $historyPath -Header 'timestamp,attempt,status,duration_seconds,connect_timeout_ms,process_timeout_ms'

$attemptConnectTimeout = $ConnectTimeoutMs
$attemptProcessTimeout = $ProcessTimeoutMs

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $attemptLabel = "attempt-$attempt"
    Write-Host ""
    Write-Host ("=== {0} of {1} ===" -f $attempt, $MaxAttempts)
    Write-Host ("ConnectTimeoutMs={0} ProcessTimeoutMs={1}" -f $attemptConnectTimeout, $attemptProcessTimeout)

    $status = 'success'
    $startTime = Get-Date
    try {
        & $runScript `
            -LabVIEWVersion $LabVIEWVersion `
            -EnsureCleanState:$EnsureCleanState `
            -ConnectTimeoutMs $attemptConnectTimeout `
            -ProcessTimeoutMs $attemptProcessTimeout `
            -RepoRoot $runRepoRoot
    } catch {
        $status = "error:{0}" -f $_.Exception.Message
    }

    $durationSeconds = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    Write-AutoHistoryEntry -Path $historyPath -AttemptLabel $attemptLabel -Status $status -DurationSeconds $durationSeconds -ConnectTimeoutMs $attemptConnectTimeout -ProcessTimeoutMs $attemptProcessTimeout

    if ($status -eq 'success') {
        Write-Host ("Completed successfully on {0}." -f $attemptLabel)
        break
    }

    if ($attempt -ge $MaxAttempts) {
        throw "Run failed after $MaxAttempts attempts. Check $historyPath for details."
    }

    $attemptConnectTimeout = [Math]::Min([int]([Math]::Ceiling($attemptConnectTimeout * $ConnectTimeoutGrowth)), $MaxConnectTimeoutMs)
    $attemptProcessTimeout = [Math]::Min([int]([Math]::Ceiling($attemptProcessTimeout * $ProcessTimeoutGrowth)), $MaxProcessTimeoutMs)
}
