[CmdletBinding()]
param(
    [string]$SourceRepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$Ref = 'HEAD',
    [string]$WorktreePath,
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [ValidateSet('both','64')]
    [string]$LvlibpBitness = 'both',
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [int]$LabVIEWMinorRevision = 3,
    [string]$Commit,
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,
    [Parameter(Mandatory = $true)]
    [string]$AuthorName,
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

# Guard: the VIP packaging step expects both x86 and x64 PPLs to be staged.
if ($LvlibpBitness -ne 'both') {
    throw "Worktree builds require LvlibpBitness=both so the build-vip step can find both x86/x64 PPLs. Rerun with LvlibpBitness=both (see VS Code task input)."
}

$SourceRepoPath = (Resolve-Path -LiteralPath $SourceRepoPath).Path

if (-not $WorktreePath) {
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $WorktreePath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "lv-ie-worktree-$suffix"
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path -Path $SourceRepoPath -ChildPath 'builds-isolated'
}

if (Test-Path -LiteralPath $WorktreePath) {
    throw "Worktree path already exists: $WorktreePath. Remove it or pass a different -WorktreePath."
}

Write-Host "Source repo:     $SourceRepoPath"
Write-Host "Ref to checkout: $Ref"
Write-Host "Worktree path:   $WorktreePath"
Write-Host "Output dir:      $OutputDirectory"

$worktreeAdded = $false
$devModeConfigured = $false

try {
    git -C $SourceRepoPath rev-parse --verify $Ref | Out-Null

    Write-Host "Adding worktree..."
    git -C $SourceRepoPath worktree add --detach --no-checkout "$WorktreePath" $Ref | Out-Null
    git -C $WorktreePath checkout $Ref | Out-Null
    $worktreeAdded = $true

    $setDevScript = Join-Path -Path $WorktreePath -ChildPath '.github/actions/set-development-mode/Set_Development_Mode.ps1'
    $revertDevScript = Join-Path -Path $WorktreePath -ChildPath '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1'
    $buildScript = Join-Path -Path $WorktreePath -ChildPath '.github/actions/build/Build.ps1'

    foreach ($path in @($setDevScript, $revertDevScript, $buildScript)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Expected script not found: $path"
        }
    }

    Write-Host "Setting development mode ($SupportedBitness-bit)..."
    & $setDevScript -RepositoryPath $WorktreePath -SupportedBitness $SupportedBitness
    $devModeConfigured = $true

    if (-not $Commit) {
        $Commit = (git -C $WorktreePath rev-parse --short HEAD).Trim()
    }

    $buildArgs = @{
        RepositoryPath       = $WorktreePath
        Major                = $Major
        Minor                = $Minor
        Patch                = $Patch
        Build                = $Build
        Commit               = $Commit
        LabVIEWMinorRevision = $LabVIEWMinorRevision
        LvlibpBitness        = $LvlibpBitness
        CompanyName          = $CompanyName
        AuthorName           = $AuthorName
    }

    Write-Host "Running full build (bitness: $LvlibpBitness)..."
    & $buildScript @buildArgs

    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

    foreach ($candidate in @('builds', 'reports')) {
        $path = Join-Path -Path $WorktreePath -ChildPath $candidate
        if (Test-Path -LiteralPath $path) {
            Write-Host "Copying $candidate to output directory..."
            Copy-Item -LiteralPath $path -Destination (Join-Path $OutputDirectory $candidate) -Recurse -Force
        }
    }

    Write-Host "Build completed. Artifacts staged in: $OutputDirectory"
}
finally {
    if ($devModeConfigured) {
        try {
            Write-Host "Reverting development mode..."
            & $revertDevScript -RepositoryPath $WorktreePath -SupportedBitness $SupportedBitness
        }
        catch {
            Write-Warning "Failed to revert development mode: $($_.Exception.Message)"
        }
    }

    if ($worktreeAdded -and -not $KeepWorktree) {
        try {
            Write-Host "Removing worktree..."
            git -C $SourceRepoPath worktree remove --force "$WorktreePath" | Out-Null
        }
        catch {
            Write-Warning "git worktree remove failed; attempting filesystem cleanup. $_"
            if (Test-Path -LiteralPath $WorktreePath) {
                Remove-Item -LiteralPath $WorktreePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    elseif ($worktreeAdded) {
        Write-Host "Keeping worktree at $WorktreePath (per -KeepWorktree)."
    }
}
