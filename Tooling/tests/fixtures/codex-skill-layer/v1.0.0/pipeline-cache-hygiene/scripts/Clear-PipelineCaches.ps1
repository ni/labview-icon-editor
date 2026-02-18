#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDotNetGlobalCaches,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath = 'builds/status/pipeline-cache-cleanup.json'
)

$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param([Parameter(Mandatory = $true)][string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $PathValue))
}

function Test-IsSubPath {
    param(
        [Parameter(Mandatory = $true)][string]$ChildPath,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $child = [System.IO.Path]::GetFullPath($ChildPath).TrimEnd('\')
    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\')
    return $child.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

$repoRootResolved = Resolve-AbsolutePath -PathValue $RepoRoot
if (-not (Test-Path -Path $repoRootResolved -PathType Container)) {
    throw "RepoRoot does not exist: $repoRootResolved"
}

if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $WorktreeRoot = $env:LVIE_WORKTREE_ROOT
}
$worktreeRootResolved = $null
if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot) -and (Test-Path -Path $WorktreeRoot -PathType Container)) {
    $worktreeRootResolved = Resolve-AbsolutePath -PathValue $WorktreeRoot
}

$targets = New-Object System.Collections.Generic.List[object]
foreach ($relative in @('builds/status', 'builds/vi-analyzer', 'TestResults', 'obj', 'bin')) {
    $candidate = Join-Path $repoRootResolved $relative
    $targets.Add([pscustomobject]@{
            scope = 'repo'
            path = $candidate
        }) | Out-Null
}

if ($worktreeRootResolved) {
    $ciWorktrees = @(Get-ChildItem -Path $worktreeRootResolved -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'ci-*' })
    foreach ($item in $ciWorktrees) {
        $targets.Add([pscustomobject]@{
                scope = 'worktree'
                path = $item.FullName
            }) | Out-Null
    }
}

$removed = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]
$failed = New-Object System.Collections.Generic.List[object]

foreach ($target in $targets) {
    $path = [string]$target.path
    if (-not (Test-Path -Path $path)) {
        $skipped.Add([pscustomobject]@{ path = $path; reason = 'missing' }) | Out-Null
        continue
    }

    $allowDelete = (Test-IsSubPath -ChildPath $path -RootPath $repoRootResolved)
    if (-not $allowDelete -and $worktreeRootResolved) {
        $allowDelete = (Test-IsSubPath -ChildPath $path -RootPath $worktreeRootResolved)
    }
    if (-not $allowDelete) {
        $failed.Add([pscustomobject]@{ path = $path; reason = 'outside-allowed-roots' }) | Out-Null
        continue
    }

    if ($PSCmdlet.ShouldProcess($path, 'Remove cache directory')) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            $removed.Add([pscustomobject]@{ path = $path; scope = [string]$target.scope }) | Out-Null
        } catch {
            $failed.Add([pscustomobject]@{
                    path = $path
                    reason = $_.Exception.Message
                }) | Out-Null
        }
    }
}

$dotnetSummary = [ordered]@{
    attempted = $false
    commands = @()
}
if ($IncludeDotNetGlobalCaches) {
    $dotnetSummary.attempted = $true
    $commands = @(
        @('dotnet', 'build-server', 'shutdown'),
        @('dotnet', 'nuget', 'locals', 'all', '--clear')
    )

    foreach ($commandParts in $commands) {
        $exe = $commandParts[0]
        $commandArgs = @($commandParts[1..($commandParts.Count - 1)])
        try {
            & $exe @commandArgs | Out-Host
            $dotnetSummary.commands += [pscustomobject]@{
                command = ($commandParts -join ' ')
                exit_code = $LASTEXITCODE
            }
        } catch {
            $dotnetSummary.commands += [pscustomobject]@{
                command = ($commandParts -join ' ')
                exit_code = -1
                error = $_.Exception.Message
            }
        }
    }
}

$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    repo_root = $repoRootResolved
    worktree_root = $worktreeRootResolved
    removed = @($removed)
    skipped = @($skipped)
    failed = @($failed)
    dotnet = $dotnetSummary
}

$summaryTarget = $SummaryPath
if (-not [System.IO.Path]::IsPathRooted($summaryTarget)) {
    $summaryTarget = Join-Path $repoRootResolved $summaryTarget
}
$summaryDir = Split-Path -Parent $summaryTarget
if (-not (Test-Path -Path $summaryDir -PathType Container)) {
    New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryTarget -Encoding utf8
Write-Host ("Wrote cache-cleanup summary: {0}" -f $summaryTarget)

if ($failed.Count -gt 0) {
    throw ("Pipeline cache cleanup completed with {0} failures." -f $failed.Count)
}
