<#
.SYNOPSIS
    Forces dev mode to disabled state locally for the specified bitness.

.DESCRIPTION
    Invokes RevertDevelopmentMode.ps1 to restore packaged sources. Intended
    to leave the system in a disabled state after iteration runs.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    LabVIEW bitness to target ("32" or "64"). Defaults to "64".

.PARAMETER LogPath
    Optional log file path. If omitted, a log file is created under Tooling\logs.

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
    [string]$LogPath,

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

function Write-DevModeLog {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format o
    $line = "$timestamp $Message"
    $line | Out-File -FilePath $logPathResolved -Append -Encoding ascii
    Write-Host $line
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
    $logPathResolved = Join-Path -Path $logDir -ChildPath ("dev-mode-final-disable-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
} else {
    $logDir = Split-Path -Parent -Path $logPathResolved
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        $null = New-Item -Path $logDir -ItemType Directory -Force
    }
}

$revertScript = Join-Path -Path $repoRoot -ChildPath '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
if (-not (Test-Path -Path $revertScript)) {
    throw "RevertDevelopmentMode.ps1 not found at $revertScript"
}

$scriptArgs = @{
    LabVIEWVersion            = $labviewYear
    SupportedBitness          = $SupportedBitness
    RepoRoot              = $repoRoot
}

Write-DevModeLog ("start version={0} bitness={1} log={2}" -f $labviewYear, $SupportedBitness, $logPathResolved)

try {
    & $revertScript @scriptArgs
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Dev mode disable failed with exit code $LASTEXITCODE."
    }
    $exitCodeValue = if ($LASTEXITCODE -eq $null) { 'null' } else { [string]$LASTEXITCODE }
    Write-DevModeLog ("finish exit_code={0}" -f $exitCodeValue)
} catch {
    Write-DevModeLog ("error message={0}" -f $($_.Exception.Message))
    throw
} finally {
    if ($preflight -and $preflight.CleanRoomAfter) {
        Invoke-PreflightCleanup -RepoRoot $preflight.RepoRoot -Phase 'after'
    }
}



