#Requires -Version 7.0
<#
.SYNOPSIS
    Repeats the local CI parity run until the selected success target is satisfied.

.DESCRIPTION
    Invokes Run-CICompositeLocal.ps1 in a retry loop with adaptive timeouts.
    Uses the existing parity script for all work and logging.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER LabVIEWBitness
    Bitness to run: both, 32, 64, or installed (auto-detect).

.PARAMETER AllowVersionMismatch
    Allow LabVIEW version mismatches against .lvversion (not recommended).

.PARAMETER DryRun
    Validate version contract and installed LabVIEW bitness without running jobs.

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
    Policy-disabled. Passing this switch throws an error because dev-mode invocation is forbidden.

.PARAMETER SkipDevModeNoLabVIEWSmoke
    Policy-disabled. Passing this switch throws an error because dev-mode invocation is forbidden.

.PARAMETER DevModeNoLabVIEWSmokeDepth
    Policy-disabled. Passing this parameter throws an error because dev-mode invocation is forbidden.

.PARAMETER VipcMode
    VIPC stage mode forwarded to Run-CICompositeLocal.ps1:
      - audit (default)
      - apply-info
      - apply-enforce

.PARAMETER SuccessTarget
    Local success contract:
      - vip: requires a fresh .vip under builds\VI Package
      - ppl: requires fresh x86 and x64 PPL outputs
      - ppl-single: requires a fresh PPL output matching the selected single bitness
      - script: requires only Run-CICompositeLocal.ps1 exit code 0

.PARAMETER SkipVerifyIEPaths
    Skip Verify IE Paths in the forwarded local parity call.

.PARAMETER SkipMissingInProject
    Skip missing-in-project in the forwarded local parity call.

.PARAMETER SkipBuildVip
    Skip VIP build in the forwarded local parity call.

.PARAMETER SkipViValidate
    Skip pylavi vi_validate checks.

.PARAMETER ViValidateConfigPath
    Path to pylavi vi_validate config file (relative to repo root).

.PARAMETER ViValidateProfile
    vi_validate profile: strict, legacy, or both (default: strict).

.PARAMETER ViValidateReportOnly
    Emit vi_validate warnings but do not fail the run.

.PARAMETER ViValidateSkipVersionGate
    Skip passing --eq to vi_validate (useful for legacy cleanup runs).

.PARAMETER ViValidateOnly
    Run only the pylavi vi_validate gate and exit.

.PARAMETER UseWorktree
    Create a worktree under the configured root and run parity from there.

.PARAMETER WorktreeRoot
    Optional override for the worktree root (defaults to C:\dev or LVIE_WORKTREE_ROOT).

.PARAMETER WorktreeName
    Optional suffix used to name the worktree directory.

.PARAMETER RepoRoot
    Optional repository root override.

.PARAMETER SkipWorktreeRootCheck
    Skip enforcing that RepoRoot is under the worktree root.

.PARAMETER RunId
    Optional run identifier used for artifact isolation.

.PARAMETER ArtifactRoot
    Optional override for the artifact output root.

.PARAMETER CleanRoom
    If set, purge known output folders before and after the run.

.PARAMETER EnableSingleBitnessRecoverySequence
    Enables single-bitness recovery sequence mode in forwarded local parity calls.

.PARAMETER AllowSequenceFaultInjection
    Allows deterministic fault injection for sequence mode (testing/proof only).

.PARAMETER SequenceFaultProfile
    Sequence fault profile:
      - none
      - force-pass1-fail
      - force-unit-fail
      - force-pass2-fail
      - force-both-fail
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('both', '32', '64', 'installed')]
    [string]$LabVIEWBitness = 'both',

    [switch]$AllowVersionMismatch,

    [switch]$DryRun,

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

    [switch]$SkipDevModeNoLabVIEWSmoke,

    [Parameter(Mandatory = $false)]
    [ValidateSet('minimal', 'balanced', 'full')]
    [string]$DevModeNoLabVIEWSmokeDepth = 'balanced',

    [Parameter(Mandatory = $false)]
    [ValidateSet('audit', 'apply-info', 'apply-enforce')]
    [string]$VipcMode = 'audit',

    [Parameter(Mandatory = $false)]
    [ValidateSet('vip', 'ppl', 'ppl-single', 'script')]
    [string]$SuccessTarget = 'vip',

    [switch]$SkipVerifyIEPaths,

    [switch]$SkipMissingInProject,

    [switch]$SkipBuildVip,

    [switch]$SkipViValidate,

    [Parameter(Mandatory = $false)]
    [string]$ViValidateConfigPath = 'Tooling/pylavi/vi-validate.yml',

    [Parameter(Mandatory = $false)]
    [ValidateSet('strict', 'legacy', 'both')]
    [string]$ViValidateProfile = 'strict',

    [switch]$ViValidateReportOnly,

    [switch]$ViValidateSkipVersionGate,

    [switch]$ViValidateOnly,

    [Parameter(Mandatory = $false)]
    [bool]$UseWorktree = $true,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [switch]$SkipWorktreeRootCheck,

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRoot,

    [switch]$CleanRoom
    ,

    [switch]$EnableSingleBitnessRecoverySequence,

    [switch]$AllowSequenceFaultInjection,

    [Parameter(Mandatory = $false)]
    [ValidateSet('none', 'force-pass1-fail', 'force-unit-fail', 'force-pass2-fail', 'force-both-fail')]
    [string]$SequenceFaultProfile = 'none'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}

$devModePolicyHelper = Join-Path $PSScriptRoot 'support\DevModePolicy.ps1'
if (-not (Test-Path -Path $devModePolicyHelper -PathType Leaf)) {
    throw "Dev mode policy helper not found at $devModePolicyHelper"
}
. $devModePolicyHelper
Assert-DevModePolicyParameterNotBound `
    -BoundParameters $PSBoundParameters `
    -BlockedParameters @('EnsureCleanState', 'SkipDevModeNoLabVIEWSmoke', 'DevModeNoLabVIEWSmokeDepth') `
    -EntryPoint $PSCommandPath

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if ($PathOverride) {
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

function Initialize-CsvHeader {
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
        [int]$ProcessTimeoutMs,
        [string]$HeuristicCode,
        [string]$DiagnosticsPath
    )

    if (-not $Path) {
        return
    }

    $safeStatus = $Status -replace ',', ' '
    $safeHeuristicCode = if ([string]::IsNullOrWhiteSpace($HeuristicCode)) { '' } else { $HeuristicCode -replace ',', ' ' }
    $safeDiagnosticsPath = if ([string]::IsNullOrWhiteSpace($DiagnosticsPath)) { '' } else { $DiagnosticsPath -replace ',', ' ' }
    "{0},{1},{2},{3},{4},{5},{6},{7}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $AttemptLabel, $safeStatus, $DurationSeconds, $ConnectTimeoutMs, $ProcessTimeoutMs, $safeHeuristicCode, $safeDiagnosticsPath |
        Add-Content -Path $Path
}

function Test-FreshFileSince {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [datetime]$Since
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $false
    }

    $item = Get-Item -Path $Path -ErrorAction Stop
    return $item.LastWriteTimeUtc -ge $Since.ToUniversalTime()
}

function Test-SuccessTargetSatisfied {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('vip', 'ppl', 'ppl-single', 'script')]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [datetime]$AttemptStartUtc,
        [string]$LabVIEWBitness
    )

    switch ($Target) {
        'script' {
            return [pscustomobject]@{
                Satisfied = $true
                Detail = 'script exit code contract satisfied'
            }
        }
        'vip' {
            $vipDir = Join-Path $RepoRoot 'builds\VI Package'
            if (-not (Test-Path -Path $vipDir -PathType Container)) {
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = "VIP output folder not found: $vipDir"
                }
            }

            $latestVip = Get-ChildItem -Path $vipDir -Filter '*.vip' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTimeUtc -Descending |
                Select-Object -First 1

            if (-not $latestVip) {
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = "No .vip file found under $vipDir"
                }
            }

            if ($latestVip.LastWriteTimeUtc -lt $AttemptStartUtc.ToUniversalTime()) {
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = ("Latest .vip is stale: {0}" -f $latestVip.FullName)
                }
            }

            return [pscustomobject]@{
                Satisfied = $true
                Detail = ("Fresh .vip found: {0}" -f $latestVip.FullName)
            }
        }
        'ppl' {
            $x86Path = Join-Path $RepoRoot 'resource\plugins\lv_icon_x86.lvlibp'
            $x64Path = Join-Path $RepoRoot 'resource\plugins\lv_icon_x64.lvlibp'

            $x86Fresh = Test-FreshFileSince -Path $x86Path -Since $AttemptStartUtc
            $x64Fresh = Test-FreshFileSince -Path $x64Path -Since $AttemptStartUtc
            if (-not $x86Fresh -or -not $x64Fresh) {
                $detail = @()
                if (-not $x86Fresh) { $detail += "x86 missing/stale: $x86Path" }
                if (-not $x64Fresh) { $detail += "x64 missing/stale: $x64Path" }
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = ($detail -join '; ')
                }
            }

            return [pscustomobject]@{
                Satisfied = $true
                Detail = 'Fresh x86/x64 PPL outputs found.'
            }
        }
        'ppl-single' {
            if ($LabVIEWBitness -notin @('32', '64')) {
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = ("SuccessTarget 'ppl-single' requires LabVIEWBitness 32 or 64 (received: {0})." -f $LabVIEWBitness)
                }
            }

            $targetPath = if ($LabVIEWBitness -eq '32') {
                Join-Path $RepoRoot 'resource\plugins\lv_icon_x86.lvlibp'
            } else {
                Join-Path $RepoRoot 'resource\plugins\lv_icon_x64.lvlibp'
            }

            $singleFresh = Test-FreshFileSince -Path $targetPath -Since $AttemptStartUtc
            if (-not $singleFresh) {
                return [pscustomobject]@{
                    Satisfied = $false
                    Detail = ("Selected bitness output missing/stale: {0}" -f $targetPath)
                }
            }

            return [pscustomobject]@{
                Satisfied = $true
                Detail = ("Fresh single-bitness PPL found: {0}" -f $targetPath)
            }
        }
    }
}

function Get-AttemptStatusFromRunResult {
    param(
        [Parameter(Mandatory = $true)]
        [int]$RunExitCode,
        [AllowNull()]
        [string]$ErrorMessage
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorMessage)) {
        return ("error:{0}" -f $ErrorMessage)
    }

    if ($RunExitCode -ne 0) {
        return ("exit:{0}" -f $RunExitCode)
    }

    return 'success'
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
}
$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewInfo = $null
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $labviewInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $LabVIEWVersion = $labviewInfo.Year
}
if ([string]::IsNullOrWhiteSpace($LabVIEWVersion)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}
$runScript = Join-Path $repoRoot 'Tooling/Run-CICompositeLocal.ps1'
if (-not (Test-Path -Path $runScript)) {
    throw "Run-CICompositeLocal.ps1 not found at $runScript"
}

$resolvedWorktreeRoot = $null
$ensureWorktreeScript = Join-Path $repoRoot 'Tooling/Ensure-WorktreeRoot.ps1'
if ($UseWorktree) {
    if (-not (Test-Path -Path $ensureWorktreeScript)) {
        throw "Ensure-WorktreeRoot.ps1 not found at $ensureWorktreeScript"
    }

    $resolvedWorktreeRoot = & $ensureWorktreeScript -WorktreeRoot $WorktreeRoot
    $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot
}

$runRepoRoot = $repoRoot
if ($UseWorktree) {
    $worktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
    if (-not (Test-Path -Path $worktreeScript)) {
        throw "New-CIWorktree.ps1 not found at $worktreeScript"
    }

    $suffix = if ([string]::IsNullOrWhiteSpace($WorktreeName)) { "ci-parity-auto-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss') } else { $WorktreeName }
    $runRepoRoot = & $worktreeScript -Ref HEAD -Name $suffix -WorktreeRoot $resolvedWorktreeRoot
    Write-Host ("Using worktree: {0}" -f $runRepoRoot)
}

$assertScript = Join-Path $runRepoRoot 'Tooling\Assert-LabVIEWVersion.ps1'
if (Test-Path -Path $assertScript) {
    & $assertScript -RepoRoot $runRepoRoot -ExpectedVersion $LabVIEWVersion -AllowMismatch:$AllowVersionMismatch -Context 'ci-local-auto'
}

$preflight = $null
$artifactRootResolved = $null
if (Get-Command Invoke-Preflight -ErrorAction SilentlyContinue) {
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $runRepoRoot `
        -WorktreeRoot $resolvedWorktreeRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $LabVIEWBitness `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$false `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs `
        -RunId $RunId `
        -ArtifactRoot $ArtifactRoot `
        -CleanRoom:$CleanRoom `
        -RequireViValidate:$(-not $SkipViValidate)
    if ($preflight.Reinvoked) {
        return
    }
    $artifactRootResolved = $preflight.ArtifactRoot
} elseif ($resolvedWorktreeRoot) {
    $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot
}

if ($DryRun) {
    & $runScript `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $LabVIEWBitness `
        -AllowVersionMismatch:$AllowVersionMismatch `
        -DryRun `
        -VipcMode $VipcMode `
        -SkipVerifyIEPaths:$SkipVerifyIEPaths `
        -SkipMissingInProject:$SkipMissingInProject `
        -SkipBuildVip:$SkipBuildVip `
        -SkipViValidate:$SkipViValidate `
        -ViValidateConfigPath $ViValidateConfigPath `
        -ViValidateProfile $ViValidateProfile `
        -ViValidateReportOnly:$ViValidateReportOnly `
        -ViValidateSkipVersionGate:$ViValidateSkipVersionGate `
        -ViValidateOnly:$ViValidateOnly `
        -RepoRoot $runRepoRoot `
        -WorktreeRoot $resolvedWorktreeRoot `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -RunId $RunId `
        -ArtifactRoot $ArtifactRoot `
        -CleanRoom:$CleanRoom `
        -EnableSingleBitnessRecoverySequence:$EnableSingleBitnessRecoverySequence `
        -AllowSequenceFaultInjection:$AllowSequenceFaultInjection `
        -SequenceFaultProfile $SequenceFaultProfile `
        -Orchestrated
    return
}

$logRoot = if ($artifactRootResolved) { Join-Path $artifactRootResolved 'agent-logs' } else { Join-Path $repoRoot 'TestResults/agent-logs' }
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$historyPath = Join-Path $logRoot 'auto-run-history.csv'
Initialize-CsvHeader -Path $historyPath -Header 'timestamp,attempt,status,duration_seconds,connect_timeout_ms,process_timeout_ms,heuristic_code,diagnostics_path'

$attemptConnectTimeout = $ConnectTimeoutMs
$attemptProcessTimeout = $ProcessTimeoutMs

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $attemptLabel = "attempt-$attempt"
    Write-Host ""
    Write-Host ("=== {0} of {1} ===" -f $attempt, $MaxAttempts)
    Write-Host ("ConnectTimeoutMs={0} ProcessTimeoutMs={1}" -f $attemptConnectTimeout, $attemptProcessTimeout)

    $status = 'success'
    $attemptStartUtc = (Get-Date).ToUniversalTime()
    $runExitCode = 0
    $attemptError = $null
    $heuristicCode = $null
    $diagnosticsPath = $null
    $startTime = Get-Date
    try {
        $attemptRunId = if ($preflight -and $preflight.RunId) { "{0}-{1}" -f $preflight.RunId, $attemptLabel } else { $null }
        Remove-Item -Path Env:LVIE_SEQUENCE_HEURISTIC_CODE -ErrorAction SilentlyContinue
        Remove-Item -Path Env:LVIE_SEQUENCE_DIAGNOSTICS_PATH -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = 0
        & $runScript `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $LabVIEWBitness `
            -AllowVersionMismatch:$AllowVersionMismatch `
            -VipcMode $VipcMode `
            -SkipVerifyIEPaths:$SkipVerifyIEPaths `
            -SkipMissingInProject:$SkipMissingInProject `
            -SkipBuildVip:$SkipBuildVip `
            -SkipViValidate:$SkipViValidate `
            -ViValidateConfigPath $ViValidateConfigPath `
            -ViValidateProfile $ViValidateProfile `
            -ViValidateReportOnly:$ViValidateReportOnly `
            -ViValidateSkipVersionGate:$ViValidateSkipVersionGate `
            -ViValidateOnly:$ViValidateOnly `
            -ConnectTimeoutMs $attemptConnectTimeout `
            -ProcessTimeoutMs $attemptProcessTimeout `
            -RepoRoot $runRepoRoot `
            -WorktreeRoot $resolvedWorktreeRoot `
            -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
            -RunId $attemptRunId `
            -ArtifactRoot $ArtifactRoot `
            -CleanRoom:$CleanRoom `
            -EnableSingleBitnessRecoverySequence:$EnableSingleBitnessRecoverySequence `
            -AllowSequenceFaultInjection:$AllowSequenceFaultInjection `
            -SequenceFaultProfile $SequenceFaultProfile `
            -Orchestrated
        $runExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } catch {
        $attemptError = $_.Exception.Message
        if ($null -ne $LASTEXITCODE) {
            $runExitCode = [int]$LASTEXITCODE
        } else {
            $runExitCode = 1
        }
    }
    $heuristicCode = $env:LVIE_SEQUENCE_HEURISTIC_CODE
    $diagnosticsPath = $env:LVIE_SEQUENCE_DIAGNOSTICS_PATH

    $status = Get-AttemptStatusFromRunResult -RunExitCode $runExitCode -ErrorMessage $attemptError

    if ($status -eq 'success') {
        $successCheck = Test-SuccessTargetSatisfied -Target $SuccessTarget -RepoRoot $runRepoRoot -AttemptStartUtc $attemptStartUtc -LabVIEWBitness $LabVIEWBitness
        if (-not $successCheck.Satisfied) {
            $status = "target-miss:{0}" -f $successCheck.Detail
            Write-Warning ("Attempt {0} did not satisfy SuccessTarget '{1}': {2}" -f $attemptLabel, $SuccessTarget, $successCheck.Detail)
        } else {
            Write-Host ("SuccessTarget '{0}' satisfied: {1}" -f $SuccessTarget, $successCheck.Detail)
        }
    }

    $durationSeconds = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    Write-AutoHistoryEntry -Path $historyPath -AttemptLabel $attemptLabel -Status $status -DurationSeconds $durationSeconds -ConnectTimeoutMs $attemptConnectTimeout -ProcessTimeoutMs $attemptProcessTimeout -HeuristicCode $heuristicCode -DiagnosticsPath $diagnosticsPath

    if ($status -eq 'success') {
        Write-Host ("Completed successfully on {0} (SuccessTarget={1})." -f $attemptLabel, $SuccessTarget)
        break
    }

    if ($attempt -ge $MaxAttempts) {
        throw "Run failed after $MaxAttempts attempts. Check $historyPath for details."
    }

    $attemptConnectTimeout = [Math]::Min([int]([Math]::Ceiling($attemptConnectTimeout * $ConnectTimeoutGrowth)), $MaxConnectTimeoutMs)
    $attemptProcessTimeout = [Math]::Min([int]([Math]::Ceiling($attemptProcessTimeout * $ProcessTimeoutGrowth)), $MaxProcessTimeoutMs)
}

if ($preflight -and $preflight.CleanRoomAfter) {
    Invoke-PreflightCleanup -RepoRoot $preflight.RepoRoot -Phase 'after'
}



