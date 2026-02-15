#Requires -Version 7.0
<#
.SYNOPSIS
    Creates a short-path worktree for a CI job and exports canonical path contract variables.

.DESCRIPTION
    Centralizes CI worktree creation so workflows only need to pass a bitness and
    (optionally) a variant label. The script resolves the worktree root, creates
    a deterministic folder name, calls New-CIWorktree.ps1, and exports:
      - LVIE_WORKTREE_ROOT
      - LVIE_REPO_ROOT
      - LVIE_PROJECT_RELATIVE_PATH
      - LVIE_PROJECT_PATH
      - REPO_ROOT
      - PROJECT_PATH

.PARAMETER Bitness
    LabVIEW bitness (32 or 64). Required.

.PARAMETER Variant
    Optional additional label included in the worktree folder name (e.g. 2021).

.PARAMETER Ref
    Git ref to check out. Defaults to GITHUB_SHA or HEAD.

.PARAMETER JobName
    Job name used to compute the job hash. Defaults to GITHUB_JOB.

.PARAMETER WorkflowIdentity
    Workflow identity used to compute the workflow hash. Defaults to
    GITHUB_WORKFLOW_REF, then GITHUB_WORKFLOW, then 'local'.

.PARAMETER RunId
    Run ID. Defaults to GITHUB_RUN_ID.

.PARAMETER RunAttempt
    Run attempt. Defaults to GITHUB_RUN_ATTEMPT.

.PARAMETER ProjectFile
    Project file relative path to export as LVIE_PROJECT_PATH/PROJECT_PATH.
    Defaults to lv_icon_editor.lvproj.

.PARAMETER WorktreeRoot
    Optional explicit worktree root. If omitted, LVIE_WORKTREE_ROOT or a
    runner-scoped default is used.

.PARAMETER RepoRoot
    Optional explicit repo root. If omitted, GITHUB_WORKSPACE or the script
    location is used.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('32', '64')]
    [string]$Bitness,

    [Parameter(Mandatory = $false)]
    [string]$Variant,

    [Parameter(Mandatory = $false)]
    [string]$Ref,

    [Parameter(Mandatory = $false)]
    [string]$JobName,

    [Parameter(Mandatory = $false)]
    [string]$WorkflowIdentity,

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$RunAttempt,

    [Parameter(Mandatory = $false)]
    [string]$ProjectFile = 'lv_icon_editor.lvproj',

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}
function Resolve-RepoRoot {
    param([string]$BasePath)

    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return [System.IO.Path]::GetFullPath($BasePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        return [System.IO.Path]::GetFullPath($env:GITHUB_WORKSPACE)
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

function Resolve-NormalizedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }

    return $full
}

function Get-ShortSha1Token {
    param([string]$Value)

    $valueToHash = if ([string]::IsNullOrWhiteSpace($Value)) { 'local' } else { $Value }
    $hashBytes = [System.Text.Encoding]::UTF8.GetBytes($valueToHash)
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $hash = $sha1.ComputeHash($hashBytes)
    }
    finally {
        $sha1.Dispose()
    }

    return [System.BitConverter]::ToString($hash).Replace('-', '').Substring(0, 8).ToUpperInvariant()
}

function ConvertTo-SafePathToken {
    param(
        [string]$Value,
        [string]$Default = 'token'
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Default
    }

    $token = ($Value -replace '[^A-Za-z0-9._-]', '-')
    $token = ($token -replace '-{2,}', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($token)) {
        return $Default
    }

    return $token
}

function Resolve-WorkflowIdentity {
    param([string]$Candidate)

    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        return $Candidate
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKFLOW_REF)) {
        return $env:GITHUB_WORKFLOW_REF
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKFLOW)) {
        return $env:GITHUB_WORKFLOW
    }

    return 'local'
}

function Get-RunnerCliRuntime {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($IsWindows) { return 'win-x64' }
    if ($IsLinux) {
        if ($arch -eq 'Arm64') { return 'linux-arm64' }
        return 'linux-x64'
    }
    if ($IsMacOS) {
        if ($arch -eq 'Arm64') { return 'osx-arm64' }
        return 'osx-x64'
    }
    return 'win-x64'
}

function Get-RunnerCliFileName {
    param([string]$Runtime)
    if ($Runtime -like 'win-*') { return 'runner-cli.exe' }
    return 'runner-cli'
}

function Get-RegisteredWorktreePathList {
    param([string]$RepoRoot)

    $paths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $lines = & git -C $RepoRoot worktree list --porcelain 2>$null
        foreach ($line in $lines) {
            if ($line -like 'worktree *') {
                $path = $line.Substring(9).Trim()
                if (-not [string]::IsNullOrWhiteSpace($path)) {
                    try {
                        $normalized = Resolve-NormalizedPath -Path $path
                        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
                            $paths.Add($normalized) | Out-Null
                        }
                    }
                    catch {
                        $paths.Add($path) | Out-Null
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose ("Failed to enumerate git worktrees. {0}" -f $_.Exception.Message)
    }

    return $paths
}

function Invoke-WorktreePrune {
    param([string]$RepoRoot)

    $pruneOutput = & git -C $RepoRoot worktree prune 2>&1
    if ($pruneOutput) {
        $pruneOutput | ForEach-Object { Write-Verbose ("git worktree prune: {0}" -f $_) }
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning ("git worktree prune returned exit code {0}." -f $LASTEXITCODE)
    }
}

function Invoke-WorktreeRetentionCleanup {
    param(
        [string]$Root,
        [string]$RepoRoot,
        [string]$TargetPath,
        [int]$RetentionDays
    )

    if ($RetentionDays -le 0) {
        return
    }

    if (-not (Test-Path -Path $Root -PathType Container)) {
        return
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $registered = Get-RegisteredWorktreePathList -RepoRoot $RepoRoot

    Get-ChildItem -Path $Root -Directory -Force | Where-Object {
        $_.Name -like 'ci-*' -and
        $_.LastWriteTime -lt $cutoff -and
        (-not $registered.Contains($_.FullName)) -and
        ($_.FullName -ne $TargetPath)
    } | ForEach-Object {
        try {
            Write-Host ("Removing stale worktree folder: {0}" -f $_.FullName)
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning ("Failed to remove stale worktree folder: {0}. {1}" -f $_.FullName, $_.Exception.Message)
        }
    }
}

function Resolve-LabVIEWVersionInfo {
    param([string]$VersionPath)

    if (-not (Test-Path -Path $VersionPath)) {
        throw ".lvversion not found at $VersionPath"
    }

    $raw = (Get-Content -Raw -Path $VersionPath).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw ".lvversion is empty at $VersionPath"
    }

    if (-not ($raw -match '^(?<major>\d{2,4})(?:\.(?<minor>\d+))?$')) {
        throw ".lvversion value '$raw' is invalid. Expected formats like '21.0' or '2021.0'."
    }

    $majorRaw = [int]$Matches['major']
    $minor = if ($Matches['minor']) { [int]$Matches['minor'] } else { 0 }

    if ($majorRaw -ge 2000) {
        $year = $majorRaw
        $numericMajor = $majorRaw - 2000
    } else {
        $numericMajor = $majorRaw
        $year = 2000 + $majorRaw
    }

    if ($numericMajor -lt 0) {
        throw ".lvversion value '$raw' produced an invalid LabVIEW numeric major."
    }

    [pscustomobject]@{
        Raw            = $raw
        Year           = $year
        MinorRevision  = $minor
        NumericVersion = "$numericMajor.$minor"
    }
}

$repoRoot = Resolve-RepoRoot -BasePath $RepoRoot

$assertScript = Join-Path $repoRoot 'Tooling/Assert-LabVIEWVersion.ps1'
if (Test-Path -Path $assertScript) {
    & $assertScript -RepoRoot $repoRoot -Context 'ci-worktree'
}

$jobName = $JobName
if ([string]::IsNullOrWhiteSpace($jobName)) {
    $jobName = $env:GITHUB_JOB
}
if ([string]::IsNullOrWhiteSpace($jobName)) {
    throw "JobName is required to compute the worktree name."
}
$workflowIdentity = Resolve-WorkflowIdentity -Candidate $WorkflowIdentity
$resolvedRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { $env:GITHUB_RUN_ID } else { $RunId }
if ([string]::IsNullOrWhiteSpace($resolvedRunId)) {
    $resolvedRunId = 'local'
}
$resolvedRunAttempt = if ([string]::IsNullOrWhiteSpace($RunAttempt)) { $env:GITHUB_RUN_ATTEMPT } else { $RunAttempt }
if ([string]::IsNullOrWhiteSpace($resolvedRunAttempt)) {
    $resolvedRunAttempt = '1'
}

$ref = $Ref
if ([string]::IsNullOrWhiteSpace($ref)) {
    $ref = $env:GITHUB_SHA
}
if ([string]::IsNullOrWhiteSpace($ref)) {
    $ref = 'HEAD'
}

$root = $WorktreeRoot
$rootIsExplicit = $false
if ([string]::IsNullOrWhiteSpace($root)) {
    $root = $env:LVIE_WORKTREE_ROOT
}
if (-not [string]::IsNullOrWhiteSpace($root)) {
    $rootIsExplicit = $true
}

if ([string]::IsNullOrWhiteSpace($root)) {
    $rootBase = $env:RUNNER_WORKSPACE
    if ([string]::IsNullOrWhiteSpace($rootBase) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        $rootBase = Split-Path -Parent (Split-Path -Parent $env:GITHUB_WORKSPACE)
    }
    if ([string]::IsNullOrWhiteSpace($rootBase) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        $rootBase = Split-Path -Parent $env:GITHUB_WORKSPACE
    }
    if ([string]::IsNullOrWhiteSpace($rootBase)) {
        throw "Worktree root could not be resolved. Set LVIE_WORKTREE_ROOT or pass -WorktreeRoot."
    }
    $root = Join-Path $rootBase 'w'
}

$root = [System.IO.Path]::GetFullPath($root)
if (-not $rootIsExplicit) {
    New-Item -Path $root -ItemType Directory -Force | Out-Null
}
$root = Resolve-NormalizedPath -Path $root

$workflowHash = Get-ShortSha1Token -Value $workflowIdentity
$jobHash = Get-ShortSha1Token -Value $jobName
$runIdToken = ConvertTo-SafePathToken -Value $resolvedRunId -Default 'local'
$runAttemptToken = ConvertTo-SafePathToken -Value $resolvedRunAttempt -Default '1'

$variantToken = if ([string]::IsNullOrWhiteSpace($Variant)) { $null } else { ConvertTo-SafePathToken -Value $Variant -Default 'variant' }
$name = if ($variantToken) {
    "ci-$workflowHash-$jobHash-$variantToken-$Bitness-$runIdToken-$runAttemptToken"
} else {
    "ci-$workflowHash-$jobHash-$Bitness-$runIdToken-$runAttemptToken"
}

$targetPath = Join-Path $root $name
$targetPath = Resolve-NormalizedPath -Path $targetPath

$ensureScript = Join-Path $repoRoot 'Tooling/Ensure-WorktreeRoot.ps1'
if (-not (Test-Path -Path $ensureScript)) {
    throw "Ensure-WorktreeRoot.ps1 not found at $ensureScript"
}

$worktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
if (-not (Test-Path -Path $worktreeScript)) {
    throw "New-CIWorktree.ps1 not found at $worktreeScript"
}

Invoke-WorktreePrune -RepoRoot $repoRoot

$registeredBeforeCreate = Get-RegisteredWorktreePathList -RepoRoot $repoRoot
if ($registeredBeforeCreate.Contains($targetPath)) {
    Write-Host ("Target worktree path is registered; removing stale registration: {0}" -f $targetPath)
    $removeOutput = & git -C $repoRoot worktree remove --force $targetPath 2>&1
    if ($removeOutput) {
        $removeOutput | ForEach-Object { Write-Host $_ }
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning ("git worktree remove returned exit code {0} for {1}" -f $LASTEXITCODE, $targetPath)
    }

    Invoke-WorktreePrune -RepoRoot $repoRoot
    $registeredAfterCleanup = Get-RegisteredWorktreePathList -RepoRoot $repoRoot
    if ($registeredAfterCleanup.Contains($targetPath)) {
        throw ("Unable to clear stale worktree registration for '{0}'. The path is still registered after remove/prune. Verify '.git/worktrees' metadata and rerun." -f $targetPath)
    }
}

$retentionDays = $null
if (-not [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_RETENTION_DAYS)) {
    if (-not [int]::TryParse($env:LVIE_WORKTREE_RETENTION_DAYS, [ref]$retentionDays)) {
        throw "LVIE_WORKTREE_RETENTION_DAYS must be an integer (got '$env:LVIE_WORKTREE_RETENTION_DAYS')."
    }
} elseif ($env:GITHUB_ACTIONS -eq 'true') {
    $retentionDays = 7
}

if ($null -ne $retentionDays) {
    Invoke-WorktreeRetentionCleanup -Root $root -RepoRoot $repoRoot -TargetPath $targetPath -RetentionDays $retentionDays
}

# The worktree path is deterministic for workflow+job+run.
# If a previous attempt left on-disk content at that path, clear it.
if (Test-Path -Path $targetPath) {
    Write-Host ("Cleaning existing worktree at {0}" -f $targetPath)

    try {
        git -C $repoRoot worktree remove --force $targetPath 2>$null | Out-Null
    }
    catch {
        Write-Verbose ("Worktree removal failed for {0}. {1}" -f $targetPath, $_.Exception.Message)
    }

    try {
        git -C $repoRoot worktree prune 2>$null | Out-Null
    }
    catch {
        Write-Verbose ("Worktree prune failed for {0}. {1}" -f $repoRoot, $_.Exception.Message)
    }

    if (Test-Path -Path $targetPath) {
        Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$worktree = & $worktreeScript -Ref $ref -Path $targetPath -WorktreeRoot $root
$worktree = Resolve-NormalizedPath -Path $worktree

if (-not (Test-Path -Path $worktree)) {
    throw "Worktree path does not exist after creation: $worktree"
}

$projectPath = Join-Path $worktree $ProjectFile
$projectPath = Resolve-NormalizedPath -Path $projectPath

if (-not (Test-Path -Path $projectPath)) {
    throw "Project file not found at $projectPath"
}

$lvInfo = Resolve-LabVIEWVersionInfo -VersionPath (Join-Path $worktree '.lvversion')

$runnerCliPath = $null
$ensureRunnerCli = Join-Path $worktree 'Tooling\Ensure-RunnerCli.ps1'
if (Test-Path -Path $ensureRunnerCli) {
    try {
        Write-Host "Ensuring runner-cli is built in the new worktree..."
        $runtime = Get-RunnerCliRuntime
        $cliFile = Get-RunnerCliFileName -Runtime $runtime
        $preferredPath = Join-Path $worktree "Tooling\runner-cli\publish\$runtime\$cliFile"
        $ensureResult = & $ensureRunnerCli -RepoRoot $worktree -RunnerCliPath $preferredPath -SkipDownload
        if ($ensureResult -and $ensureResult.Path) {
            $runnerCliPath = $ensureResult.Path
            Write-Host ("runner-cli ready at {0}" -f $runnerCliPath)
        }
    } catch {
        if ($env:LVIE_REQUIRE_RUNNER_CLI -eq '1') {
            throw
        }
        Write-Warning ("runner-cli build failed in worktree: {0}" -f $_.Exception.Message)
    }
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
    "LVIE_WORKTREE_ROOT=$root" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LVIE_REPO_ROOT=$worktree" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LVIE_PROJECT_RELATIVE_PATH=$ProjectFile" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LVIE_PROJECT_PATH=$projectPath" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "REPO_ROOT=$worktree" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "PROJECT_PATH=$projectPath" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LABVIEW_VERSION_RAW=$($lvInfo.Raw)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LABVIEW_VERSION_YEAR=$($lvInfo.Year)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LABVIEW_MINOR_REVISION=$($lvInfo.MinorRevision)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    "LABVIEW_NUMERIC_VERSION=$($lvInfo.NumericVersion)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    if (-not [string]::IsNullOrWhiteSpace($runnerCliPath)) {
        "LVIE_RUNNER_CLI_PATH=$runnerCliPath" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding ascii
    }
}

Write-Host ("Worktree created: {0}" -f $worktree)
Write-Host ("LabVIEW version: {0} (year {1}, minor {2})" -f $lvInfo.Raw, $lvInfo.Year, $lvInfo.MinorRevision)
Write-Output $worktree


