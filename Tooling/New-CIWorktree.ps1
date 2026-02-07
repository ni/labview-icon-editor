#Requires -Version 7.0
<#
.SYNOPSIS
    Creates a worktree for local CI parity runs under a short root path.

.DESCRIPTION
    Uses Tooling/Ensure-WorktreeRoot.ps1 to validate the worktree root
    (defaults to C:\dev or LVIE_WORKTREE_ROOT). Creates a new worktree
    using git and returns the path.

.PARAMETER Ref
    Git ref to check out (branch, tag, or commit). Default: HEAD.

.PARAMETER Name
    Optional suffix used to name the worktree directory.

.PARAMETER Path
    Optional explicit path for the worktree. Must be under the worktree root.

.PARAMETER WorktreeRoot
    Optional override for the worktree root.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Ref = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [switch]$NoRepoNamePrefix,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$BasePath)

    if (-not $BasePath) {
        $BasePath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $BasePath rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $BasePath '..')).Path
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

$repoRoot = Resolve-RepoRoot -BasePath $PSScriptRoot
$repoName = Split-Path -Path $repoRoot -Leaf

$ensureScript = Join-Path $repoRoot 'Tooling/Ensure-WorktreeRoot.ps1'
if (-not (Test-Path -Path $ensureScript)) {
    throw "Ensure-WorktreeRoot.ps1 not found at $ensureScript"
}

$worktreeRoot = & $ensureScript -WorktreeRoot $WorktreeRoot

if ([string]::IsNullOrWhiteSpace($Path)) {
    $suffix = if ([string]::IsNullOrWhiteSpace($Name)) { "ci-parity-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss') } else { $Name }
    if ($NoRepoNamePrefix) {
        $targetPath = Join-Path $worktreeRoot $suffix
    } else {
        $targetPath = Join-Path $worktreeRoot ("{0}-{1}" -f $repoName, $suffix)
    }
} else {
    $targetPath = [System.IO.Path]::GetFullPath($Path)
}

$rootPrefix = if ($worktreeRoot.TrimEnd('\') -eq $worktreeRoot) { "$worktreeRoot\" } else { $worktreeRoot }
if (-not ($targetPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Worktree path must be under '$worktreeRoot'. Use -WorktreeRoot to change the root."
}

if (Test-Path -Path $targetPath) {
    throw "Target worktree path already exists: $targetPath"
}

Write-Host ("Creating worktree at {0} (ref: {1})" -f $targetPath, $Ref)
$gitOutput = & git -C $repoRoot worktree add $targetPath $Ref 2>&1
if ($gitOutput) {
    $gitOutput | ForEach-Object { Write-Host $_ }
}
if ($LASTEXITCODE -ne 0) {
    throw "git worktree add failed with exit code $LASTEXITCODE."
}

$ensureRunnerCli = Join-Path $targetPath 'Tooling\Ensure-RunnerCli.ps1'
if (Test-Path -Path $ensureRunnerCli) {
    try {
        Write-Host "Ensuring runner-cli is built in the new worktree..."
        $runtime = Get-RunnerCliRuntime
        $cliFile = Get-RunnerCliFileName -Runtime $runtime
        $preferredPath = Join-Path $targetPath "Tooling\runner-cli\publish\$runtime\$cliFile"
        $result = & $ensureRunnerCli -RepoRoot $targetPath -RunnerCliPath $preferredPath -SkipDownload
        if ($result -and $result.Path) {
            Write-Host ("runner-cli ready at {0}" -f $result.Path)
        }
    } catch {
        if ($env:LVIE_REQUIRE_RUNNER_CLI -eq '1') {
            throw
        }
        Write-Warning ("runner-cli build failed in worktree: {0}" -f $_.Exception.Message)
    }
}

Write-Output $targetPath
