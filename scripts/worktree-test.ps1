[CmdletBinding()]
param(
    [string]$SourceRepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$Ref = 'HEAD',
    [ValidateSet('both','64','32')]
    [string]$SupportedBitness = 'both',
    [string]$WorktreePath,
    [string]$OutputDirectory,
    [switch]$KeepWorktree
)

$ErrorActionPreference = 'Stop'

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

Ensure-Command -Name git
Ensure-Command -Name dotnet

$SourceRepoPath = (Resolve-Path -LiteralPath $SourceRepoPath).Path

if (-not $WorktreePath) {
    $baseRoot = if ($env:LVIE_WORKTREE_BASE) { $env:LVIE_WORKTREE_BASE } else { [System.IO.Path]::GetTempPath() }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $suffix = $null
    try { $suffix = (git -C $SourceRepoPath rev-parse --short $Ref).Trim() } catch { $suffix = $null }
    if (-not $suffix) {
        $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
        Write-Host "Commit hash unavailable for ref '$Ref'; using random suffix $suffix for worktree name."
    } else {
        Write-Host "Using ref '$Ref' short hash $suffix for worktree name."
    }
    $WorktreePath = Join-Path -Path $baseRoot -ChildPath ("lv-ie-test-worktree-{0}-{1}" -f $timestamp, $suffix)
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path -Path $SourceRepoPath -ChildPath 'builds-isolated-tests'
}

if (Test-Path -LiteralPath $WorktreePath) {
    throw "Worktree path already exists: $WorktreePath. Remove it or pass a different -WorktreePath."
}

Write-Host "Source repo:     $SourceRepoPath"
Write-Host "Ref to checkout: $Ref"
Write-Host "Worktree path:   $WorktreePath"
Write-Host "Output dir:      $OutputDirectory"

$worktreeAdded = $false
try {
    git -C $SourceRepoPath rev-parse --verify $Ref | Out-Null

    Write-Host "Adding worktree..."
    git -C $SourceRepoPath worktree add --detach --no-checkout "$WorktreePath" $Ref | Out-Null
    git -C $WorktreePath checkout $Ref | Out-Null
    $worktreeAdded = $true

    # Ensure the worktree uses local test runner changes, if present
    $sourceTest = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/test/Test.ps1'
    $worktreeTest = Join-Path -Path $WorktreePath -ChildPath 'scripts/test/Test.ps1'
    if (Test-Path -LiteralPath $sourceTest) {
        Copy-Item -LiteralPath $sourceTest -Destination $worktreeTest -Force
    }
    # Ensure the worktree uses the latest restore script (guarded)
    $sourceRestoreDir = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/restore-setup-lv-source'
    $worktreeRestoreDir = Join-Path -Path $WorktreePath -ChildPath 'scripts/restore-setup-lv-source'
    if (Test-Path -LiteralPath $sourceRestoreDir -PathType Container) {
        Copy-Item -LiteralPath $sourceRestoreDir -Destination $worktreeRestoreDir -Recurse -Force
    }
    # Ensure the worktree uses the latest revert script (with token guard)
    $sourceRevertDir = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/revert-development-mode'
    $worktreeRevertDir = Join-Path -Path $WorktreePath -ChildPath 'scripts/revert-development-mode'
    if (Test-Path -LiteralPath $sourceRevertDir -PathType Container) {
        Copy-Item -LiteralPath $sourceRevertDir -Destination $worktreeRevertDir -Recurse -Force
    }

    $testsCliProj = Join-Path -Path $WorktreePath -ChildPath 'Tooling/dotnet/TestsCli/TestsCli.csproj'
    if (-not (Test-Path -LiteralPath $testsCliProj -PathType Leaf)) {
        throw "TestsCli project not found at $testsCliProj"
    }

    Write-Host "Running TestsCli in isolated worktree..."
    dotnet run --project $testsCliProj -- --repo $WorktreePath --bitness $SupportedBitness
    $code = $LASTEXITCODE

    if ($OutputDirectory) {
        if (Test-Path -LiteralPath $OutputDirectory) {
            Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
        }
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        foreach ($candidate in @('builds','reports')) {
            $path = Join-Path -Path $WorktreePath -ChildPath $candidate
            if (Test-Path -LiteralPath $path) {
                $dest = Join-Path -Path $OutputDirectory -ChildPath $candidate
                Write-Host "Copying $candidate to $dest ..."
                Copy-Item -LiteralPath $path -Destination $dest -Recurse -Force
            }
        }
    }

    exit $code
}
finally {
    if ($worktreeAdded -and -not $KeepWorktree) {
        Write-Host "Removing worktree..."
        try { git -C $SourceRepoPath worktree remove --force "$WorktreePath" | Out-Null } catch { Write-Warning ("Worktree remove failed: {0}" -f $_.Exception.Message) }
        try { Remove-Item -LiteralPath $WorktreePath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}
