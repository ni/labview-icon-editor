#Requires -Version 7.0
<#
.SYNOPSIS
    Orchestrates local CI parity runs with worktree creation and status logging.

.DESCRIPTION
    Creates a short-path worktree (optional), records pre/post process snapshots,
    and runs Run-CICompositeLocal.ps1 or Run-CICompositeLocal-Auto.ps1 with
    consistent status output.
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

    [switch]$EnsureCleanState,
    [switch]$SkipVerifyIEPaths,
    [switch]$SkipVipc,
    [switch]$SkipMissingInProject,
    [switch]$SkipUnitTests,
    [switch]$SkipBuildPpl,
    [switch]$SkipBuildVip,

    [Parameter(Mandatory = $false)]
    [ValidateSet('major', 'minor', 'patch', 'none')]
    [string]$BumpType = 'patch',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 180000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$StatusFileTimeoutMs = 60000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3600)]
    [int]$VipmTimeoutSeconds = 900,

    [Parameter(Mandatory = $false)]
    [ValidateSet('always', 'if-running')]
    [string]$CloseLabVIEWMode = 'if-running',

    [Parameter(Mandatory = $false)]
    [string]$VipcPath,

    [Parameter(Mandatory = $false)]
    [string]$VipbPath,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotesPath,

    [Parameter(Mandatory = $false)]
    [bool]$UseWorktree = $true,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$Ref = 'HEAD',

    [Parameter(Mandatory = $false)]
    [switch]$AutoLoop,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$MaxAttempts = 5,

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRoot,

    [Parameter(Mandatory = $false)]
    [switch]$CleanRoom,

    [Parameter(Mandatory = $false)]
    [int]$Major,

    [Parameter(Mandatory = $false)]
    [int]$Minor,

    [Parameter(Mandatory = $false)]
    [int]$Patch,

    [Parameter(Mandatory = $false)]
    [int]$Build,

    [Parameter(Mandatory = $false)]
    [string]$Commit,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [switch]$SkipWorktreeRootCheck
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

function Get-DefaultWorktreeName {
    param(
        [string]$Timestamp,
        [string]$Prefix = 'ci-parity-run'
    )

    if ([string]::IsNullOrWhiteSpace($Timestamp)) {
        $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    }

    return "$Prefix-$Timestamp"
}

function Resolve-WorktreeName {
    param(
        [string]$Name,
        [string]$Timestamp,
        [string]$DefaultPrefix
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return Get-DefaultWorktreeName -Timestamp $Timestamp -Prefix $DefaultPrefix
    }

    $trimmed = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return Get-DefaultWorktreeName -Timestamp $Timestamp -Prefix $DefaultPrefix
    }

    switch -Regex ($trimmed.ToLowerInvariant()) {
        '^(auto|default|generated)$' { return Get-DefaultWorktreeName -Timestamp $Timestamp -Prefix $DefaultPrefix }
        '^\(auto\)$' { return Get-DefaultWorktreeName -Timestamp $Timestamp -Prefix $DefaultPrefix }
        '^<auto>$' { return Get-DefaultWorktreeName -Timestamp $Timestamp -Prefix $DefaultPrefix }
        default { return $trimmed }
    }
}

function Get-WorktreePathList {
    param([string]$RepoRoot)

    $paths = @()
    $lines = & git -C $RepoRoot worktree list --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        $global:LASTEXITCODE = 0
        return $paths
    }

    foreach ($line in $lines) {
        if ($line -like 'worktree *') {
            $paths += $line.Substring(9).Trim()
        }
    }

    return $paths
}

function Test-IsGitWorktree {
    param([string]$RepoRoot)

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return $false
    }

    $gitPath = Join-Path $RepoRoot '.git'
    return (Test-Path -Path $gitPath -PathType Leaf)
}

function Test-IsUnderRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Root)) {
        return $false
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not $fullRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fullRoot += [System.IO.Path]::DirectorySeparatorChar
    }

    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $Value | ConvertTo-Json -Depth 6 | Out-File -FilePath $Path -Encoding ascii
}

function Write-ProcessSnapshot {
    param(
        [string]$Path,
        [string]$Label
    )

    $processes = Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue
    if ($processes) {
        $table = $processes | Sort-Object -Property Name, Id | Format-Table -AutoSize | Out-String
        Write-Host $table
    } else {
        Write-Host "No g-cli/LabVIEW processes running."
    }

    $payload = [pscustomobject]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        label         = $Label
        processes     = $processes | Select-Object -Property Name, Id
    }

    Write-JsonFile -Path $Path -Value $payload
}

function New-StatusPayload {
    param(
        [string]$Status,
        [string]$Message,
        [string]$ErrorMessage,
        [Nullable[datetime]]$RunStart,
        [Nullable[datetime]]$RunEnd,
        [string]$RepoRoot,
        [string]$RunRepoRoot,
        [string]$WorktreeRoot,
        [string]$WorktreeName,
        [string]$WorktreePath,
        [string[]]$NewWorktrees,
        [string]$RunScript,
        [bool]$AutoLoop,
        [int]$MaxAttempts,
        [string]$LabVIEWBitness
    )

    $duration = $null
    $startValue = if ($RunStart.HasValue) { $RunStart.Value } else { $null }
    $endValue = if ($RunEnd.HasValue) { $RunEnd.Value } else { $null }
    if ($startValue -and $endValue) {
        $duration = [Math]::Round(($endValue - $startValue).TotalSeconds, 2)
    }

    $resolvedRunId = if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUN_ID)) { $env:LVIE_RUN_ID } else { $RunId }
    $resolvedArtifactRoot = if (-not [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) { $env:LVIE_ARTIFACT_ROOT } else { $ArtifactRoot }

    return [pscustomobject]@{
        timestamp_utc       = (Get-Date).ToUniversalTime().ToString('o')
        status              = $Status
        message             = $Message
        error               = $ErrorMessage
        run_started_utc     = if ($startValue) { $startValue.ToUniversalTime().ToString('o') } else { $null }
        run_finished_utc    = if ($endValue) { $endValue.ToUniversalTime().ToString('o') } else { $null }
        duration_seconds    = $duration
        repo_root           = $RepoRoot
        run_repo_root       = $RunRepoRoot
        worktree_root       = $WorktreeRoot
        worktree_name       = $WorktreeName
        worktree_path       = $WorktreePath
        worktrees_added     = $NewWorktrees
        run_id              = $resolvedRunId
        artifact_root       = $resolvedArtifactRoot
        run_script          = $RunScript
        auto_loop           = $AutoLoop
        max_attempts        = if ($AutoLoop) { $MaxAttempts } else { $null }
        labview_version     = $LabVIEWVersion
        labview_bitness     = $LabVIEWBitness
    }
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$statusRoot = Join-Path $repoRoot 'TestResults/agent-logs'
New-Item -Path $statusRoot -ItemType Directory -Force | Out-Null
$statusPath = Join-Path $statusRoot ("ci-parity-status-{0}.json" -f $timestamp)
$statusLatestPath = Join-Path $statusRoot 'ci-parity-latest.json'
$snapshotBeforePath = Join-Path $statusRoot ("ci-parity-process-before-{0}.json" -f $timestamp)
$snapshotAfterPath = Join-Path $statusRoot ("ci-parity-process-after-{0}.json" -f $timestamp)

if ($AutoLoop -and ($SkipVerifyIEPaths -or $SkipVipc -or $SkipMissingInProject -or $SkipUnitTests -or $SkipBuildPpl -or $SkipBuildVip)) {
    Write-Warning "Skip flags are ignored in AutoLoop mode."
}

$runScriptPath = if ($AutoLoop) {
    Join-Path $repoRoot 'Tooling/Run-CICompositeLocal-Auto.ps1'
} else {
    Join-Path $repoRoot 'Tooling/Run-CICompositeLocal.ps1'
}
if (-not (Test-Path -Path $runScriptPath)) {
    throw "Run script not found at $runScriptPath"
}

$resolvedWorktreeRoot = $null
$resolvedWorktreeName = $null
if ($UseWorktree) {
    $ensureWorktreeScript = Join-Path $repoRoot 'Tooling/Ensure-WorktreeRoot.ps1'
    if (-not (Test-Path -Path $ensureWorktreeScript)) {
        throw "Ensure-WorktreeRoot.ps1 not found at $ensureWorktreeScript"
    }

    $resolvedWorktreeRoot = & $ensureWorktreeScript -WorktreeRoot $WorktreeRoot
    $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot
    $defaultPrefix = if ($AutoLoop) { 'ci-parity-auto' } else { 'ci-parity-run' }
    $resolvedWorktreeName = Resolve-WorktreeName -Name $WorktreeName -Timestamp $timestamp -DefaultPrefix $defaultPrefix
} elseif (-not $SkipWorktreeRootCheck) {
    Write-Warning 'UseWorktree is disabled; skipping worktree root guard.'
}

$worktreesBefore = if ($UseWorktree) { Get-WorktreePathList -RepoRoot $repoRoot } else { @() }
$worktreePath = $null
$runRepoRoot = $repoRoot

if ($UseWorktree -and -not $AutoLoop) {
    # If we're already running from a short-path worktree under the configured root,
    # reuse it instead of nesting worktrees.
    if ((Test-IsGitWorktree -RepoRoot $repoRoot) -and (Test-IsUnderRoot -Path $repoRoot -Root $resolvedWorktreeRoot)) {
        $worktreePath = $repoRoot
        $runRepoRoot = $repoRoot
        $resolvedWorktreeName = Split-Path -Leaf $repoRoot
        Write-Host ("RepoRoot is already a worktree under {0}; reusing {1}" -f $resolvedWorktreeRoot, $repoRoot)
    } else {
        $newWorktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
        if (-not (Test-Path -Path $newWorktreeScript)) {
            throw "New-CIWorktree.ps1 not found at $newWorktreeScript"
        }

        $worktreePath = & $newWorktreeScript -Ref $Ref -Name $resolvedWorktreeName -WorktreeRoot $resolvedWorktreeRoot
        $runRepoRoot = $worktreePath
        Write-Host ("Using worktree: {0}" -f $worktreePath)
    }
}

Write-ProcessSnapshot -Path $snapshotBeforePath -Label 'before'

$runStart = Get-Date
$runEnd = $null
$runError = $null
$runSucceeded = $false

    Write-JsonFile -Path $statusPath -Value (New-StatusPayload `
        -Status 'running' `
        -Message 'CI parity run started.' `
        -ErrorMessage $null `
        -RunStart $runStart `
        -RunEnd $null `
        -RepoRoot $repoRoot `
        -RunRepoRoot $runRepoRoot `
        -WorktreeRoot $resolvedWorktreeRoot `
        -WorktreeName $resolvedWorktreeName `
        -WorktreePath $worktreePath `
        -NewWorktrees $null `
        -RunScript $runScriptPath `
        -AutoLoop:$AutoLoop `
        -MaxAttempts $MaxAttempts `
        -LabVIEWBitness $LabVIEWBitness)
Copy-Item -Path $statusPath -Destination $statusLatestPath -Force

try {
    if ($AutoLoop) {
        $autoParams = @{}
        if ($PSBoundParameters.ContainsKey('LabVIEWVersion')) { $autoParams.LabVIEWVersion = $LabVIEWVersion }
        $autoParams.LabVIEWBitness = $LabVIEWBitness
        if ($PSBoundParameters.ContainsKey('MaxAttempts')) { $autoParams.MaxAttempts = $MaxAttempts }
        if ($PSBoundParameters.ContainsKey('ConnectTimeoutMs')) { $autoParams.ConnectTimeoutMs = $ConnectTimeoutMs }
        if ($PSBoundParameters.ContainsKey('ProcessTimeoutMs')) { $autoParams.ProcessTimeoutMs = $ProcessTimeoutMs }
        if ($EnsureCleanState) { $autoParams.EnsureCleanState = $true }
        if ($PSBoundParameters.ContainsKey('RunId')) { $autoParams.RunId = $RunId }
        if ($PSBoundParameters.ContainsKey('ArtifactRoot')) { $autoParams.ArtifactRoot = $ArtifactRoot }
        if ($CleanRoom) { $autoParams.CleanRoom = $true }

        $autoParams.RepoRoot = $repoRoot
        $autoParams.UseWorktree = $UseWorktree
        if ($UseWorktree) {
            $autoParams.WorktreeRoot = $resolvedWorktreeRoot
            $autoParams.WorktreeName = $resolvedWorktreeName
        }

        $skipGuard = $SkipWorktreeRootCheck -or (-not $UseWorktree)
        if ($skipGuard) {
            $autoParams.SkipWorktreeRootCheck = $true
        }

        & $runScriptPath @autoParams
    } else {
        $runParams = @{}
        if ($PSBoundParameters.ContainsKey('LabVIEWVersion')) { $runParams.LabVIEWVersion = $LabVIEWVersion }
        $runParams.LabVIEWBitness = $LabVIEWBitness
        if ($EnsureCleanState) { $runParams.EnsureCleanState = $true }
        if ($SkipVerifyIEPaths) { $runParams.SkipVerifyIEPaths = $true }
        if ($SkipVipc) { $runParams.SkipVipc = $true }
        if ($SkipMissingInProject) { $runParams.SkipMissingInProject = $true }
        if ($SkipUnitTests) { $runParams.SkipUnitTests = $true }
        if ($SkipBuildPpl) { $runParams.SkipBuildPpl = $true }
        if ($SkipBuildVip) { $runParams.SkipBuildVip = $true }
        if ($PSBoundParameters.ContainsKey('BumpType')) { $runParams.BumpType = $BumpType }
        if ($PSBoundParameters.ContainsKey('ConnectTimeoutMs')) { $runParams.ConnectTimeoutMs = $ConnectTimeoutMs }
        if ($PSBoundParameters.ContainsKey('ProcessTimeoutMs')) { $runParams.ProcessTimeoutMs = $ProcessTimeoutMs }
        if ($PSBoundParameters.ContainsKey('StatusFileTimeoutMs')) { $runParams.StatusFileTimeoutMs = $StatusFileTimeoutMs }
        if ($PSBoundParameters.ContainsKey('VipmTimeoutSeconds')) { $runParams.VipmTimeoutSeconds = $VipmTimeoutSeconds }
        if ($PSBoundParameters.ContainsKey('CloseLabVIEWMode')) { $runParams.CloseLabVIEWMode = $CloseLabVIEWMode }
        if ($PSBoundParameters.ContainsKey('VipcPath')) { $runParams.VipcPath = $VipcPath }
        if ($PSBoundParameters.ContainsKey('VipbPath')) { $runParams.VipbPath = $VipbPath }
        if ($PSBoundParameters.ContainsKey('ReleaseNotesPath')) { $runParams.ReleaseNotesPath = $ReleaseNotesPath }
        if ($PSBoundParameters.ContainsKey('RunId')) { $runParams.RunId = $RunId }
        if ($PSBoundParameters.ContainsKey('ArtifactRoot')) { $runParams.ArtifactRoot = $ArtifactRoot }
        if ($CleanRoom) { $runParams.CleanRoom = $true }

        if ($PSBoundParameters.ContainsKey('Major')) { $runParams.Major = $Major }
        if ($PSBoundParameters.ContainsKey('Minor')) { $runParams.Minor = $Minor }
        if ($PSBoundParameters.ContainsKey('Patch')) { $runParams.Patch = $Patch }
        if ($PSBoundParameters.ContainsKey('Build')) { $runParams.Build = $Build }
        if ($PSBoundParameters.ContainsKey('Commit')) { $runParams.Commit = $Commit }

        $runParams.RepoRoot = $runRepoRoot
        if ($UseWorktree) {
            $runParams.WorktreeRoot = $resolvedWorktreeRoot
        }

        $skipGuard = $SkipWorktreeRootCheck -or (-not $UseWorktree)
        if ($skipGuard) {
            $runParams.SkipWorktreeRootCheck = $true
        }

        & $runScriptPath @runParams
    }

    $runSucceeded = $true
} catch {
    $runError = $_
    throw
} finally {
    $runEnd = Get-Date
    Write-ProcessSnapshot -Path $snapshotAfterPath -Label 'after'
    $worktreesAfter = if ($UseWorktree) { Get-WorktreePathList -RepoRoot $repoRoot } else { @() }
    $newWorktrees = if ($UseWorktree) { $worktreesAfter | Where-Object { $worktreesBefore -notcontains $_ } } else { @() }
    if (-not $worktreePath -and $newWorktrees.Count -gt 0) {
        $worktreePath = $newWorktrees[0]
    }

    $status = if ($runSucceeded) { 'success' } else { 'error' }
    $errorMessage = if ($runError) { $runError.Exception.Message } else { $null }
    $message = if ($runSucceeded) { 'CI parity run completed.' } else { 'CI parity run failed.' }

    Write-JsonFile -Path $statusPath -Value (New-StatusPayload `
            -Status $status `
            -Message $message `
            -ErrorMessage $errorMessage `
            -RunStart $runStart `
            -RunEnd $runEnd `
            -RepoRoot $repoRoot `
            -RunRepoRoot $runRepoRoot `
            -WorktreeRoot $resolvedWorktreeRoot `
            -WorktreeName $resolvedWorktreeName `
            -WorktreePath $worktreePath `
            -NewWorktrees $newWorktrees `
            -RunScript $runScriptPath `
            -AutoLoop:$AutoLoop `
            -MaxAttempts $MaxAttempts `
            -LabVIEWBitness $LabVIEWBitness)
    Copy-Item -Path $statusPath -Destination $statusLatestPath -Force
}

