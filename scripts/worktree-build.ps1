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
    [switch]$KeepWorktree,
    [switch]$AnalyzeVIP
)

$ErrorActionPreference = 'Stop'

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

Ensure-Command -Name git

function Normalize-ScriptPath {
    param([string]$Path)
    if (-not $Path) { return $Path }
    $p = $Path.Trim()
    if ($p.StartsWith(':')) { $p = $p.TrimStart(':') }
    try {
        return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
    }
    catch {
        return $p
    }
}

$devBindJsonRel = 'reports/dev-mode-bind.json'
function Assert-DevModeBindOk {
    param(
        [string]$RepoPath,
        [string]$Arch
    )

    $jsonPath = Join-Path $RepoPath $devBindJsonRel
    if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) {
        throw "Dev-mode bind JSON not found at $jsonPath after bind ($Arch-bit). Resolve and rerun dev-mode bind."
    }

    try {
        $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Unable to read dev-mode bind JSON at ${jsonPath}: $($_.Exception.Message)"
    }

    $entry = $data | Where-Object { $_.bitness -eq $Arch } | Select-Object -First 1
    if (-not $entry) {
        throw "Dev-mode bind JSON at $jsonPath does not contain an entry for bitness $Arch. Rerun dev-mode bind."
    }

    if ($entry.status -ne 'success') {
        $msg = if ($entry.message) { $entry.message } else { 'Unknown bind failure' }
        throw ("Dev-mode bind failed for {0}-bit: {1}. JSON: {2}. Run 'Dev Mode (interactive bind/unbind)' task with Force for {0}-bit, then rerun the build task." -f $Arch, $msg, $jsonPath)
    }
}

$hasStyle = ($PSStyle -ne $null)
$bitnessPalette = @{
    '32' = if ($hasStyle) { $PSStyle.Foreground.BrightCyan } else { '' }
    '64' = if ($hasStyle) { $PSStyle.Foreground.BrightMagenta } else { '' }
}
$resetColor = if ($hasStyle) { $PSStyle.Reset } else { '' }
function Write-BitnessBanner {
    param([string]$Arch)
    $color = $bitnessPalette[$Arch]
    Write-Host ("{0}==== {1}-bit phase ===={2}" -f $color, $Arch, $resetColor)
}

function Write-Separator {
    param(
        [string]$Label = ''
    )
    $line = ('-' * 80)
    if ([string]::IsNullOrWhiteSpace($Label)) {
        Write-Host $line
    } else {
        Write-Host "$line"
        Write-Host ("-- {0}" -f $Label)
        Write-Host "$line"
    }
}

# Guard: the VIP packaging step expects both x86 and x64 PPLs to be staged.
if ($LvlibpBitness -ne 'both') {
    throw "Worktree builds require LvlibpBitness=both so the build-vip step can find both x86/x64 PPLs. Rerun with LvlibpBitness=both (see VS Code task input)."
}

$SourceRepoPath = (Resolve-Path -LiteralPath $SourceRepoPath).Path

if (-not $WorktreePath) {
    $suffix = $null
    try {
        $suffix = (git -C $SourceRepoPath rev-parse --short $Ref).Trim()
    }
    catch {
        $suffix = $null
    }
    if (-not $suffix) {
        $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
        Write-Host "Commit hash unavailable for ref '$Ref'; using random suffix $suffix for worktree name."
    }
    else {
        Write-Host "Using ref '$Ref' short hash $suffix for worktree name."
    }
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
Write-Separator "Initialize worktree"

$worktreeAdded = $false
$devModeConfigured = @()

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    git -C $SourceRepoPath rev-parse --verify $Ref | Out-Null

    Write-Host "Adding worktree..."
    git -C $SourceRepoPath worktree add --detach --no-checkout "$WorktreePath" $Ref | Out-Null
    git -C $WorktreePath checkout $Ref | Out-Null
    $worktreeAdded = $true

    $setDevScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath '.github/actions/set-development-mode/Set_Development_Mode.ps1')
    $revertDevScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1')
    $bindDevScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath '.github/actions/bind-development-mode/BindDevelopmentMode.ps1')
    $analyzeVipScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath '.github/actions/analyze-vi-package/run-local.ps1')
    $buildScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath '.github/actions/build/Build.ps1')

    foreach ($path in @($setDevScript, $revertDevScript, $bindDevScript, $buildScript, $analyzeVipScript)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Expected script not found: $path"
        }
    }

    # Make runner_dependencies.vipc available at the worktree root (preferred path for downstream tools).
    $vipcSource = Join-Path -Path $WorktreePath -ChildPath 'scripts/apply-vipc/runner_dependencies.vipc'
    $vipcTarget = Join-Path -Path $WorktreePath -ChildPath 'runner_dependencies.vipc'
    if ((Test-Path -LiteralPath $vipcSource) -and (-not (Test-Path -LiteralPath $vipcTarget))) {
        Copy-Item -LiteralPath $vipcSource -Destination $vipcTarget -Force
        Write-Host "Copied runner_dependencies.vipc to worktree root: $vipcTarget"
    }

    $bitnessList = if ($LvlibpBitness -eq 'both') { @('32','64') } else { @($SupportedBitness) }
    Write-Host ("Dev-mode preparation for bitness(es): {0}" -f ($bitnessList -join ', '))
    foreach ($arch in ($bitnessList | Select-Object -Unique)) {
        Write-Separator ("Dev-mode bind {0}-bit" -f $arch)
        Write-BitnessBanner -Arch $arch
        Write-Host "Setting development mode ($arch-bit)..."
        & $setDevScript -RepositoryPath $WorktreePath -SupportedBitness $arch
        $devModeConfigured += $arch

        Write-Host "Binding dev mode (Force) to worktree ($arch-bit)..."
        & $bindDevScript -RepositoryPath $WorktreePath -Mode bind -Bitness $arch -Force
        Assert-DevModeBindOk -RepoPath $WorktreePath -Arch $arch
    }

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
    Write-Separator "Build start"
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

    $shouldAnalyze = $AnalyzeVIP.IsPresent -or -not $PSBoundParameters.ContainsKey('AnalyzeVIP')
    if ($shouldAnalyze) {
        Write-Host "Analyzing built VIP package..."
        $vipDir = Join-Path $WorktreePath 'builds\VI Package'
        & $analyzeVipScript -VipArtifactPath $vipDir -MinLabVIEW '21.0'
    }
    else {
        Write-Host "Skipping VIP analyze (AnalyzeVIP not requested)."
    }
}
finally {
    if ($devModeConfigured.Count -gt 0) {
        foreach ($arch in ($devModeConfigured | Select-Object -Unique)) {
            try {
                Write-Host "Reverting development mode ($arch-bit)..."
                & $revertDevScript -RepositoryPath $WorktreePath -SupportedBitness $arch
            }
            catch {
                Write-Warning "Failed to revert development mode ($arch-bit): $($_.Exception.Message)"
            }
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

$stopwatch.Stop()
Write-Host ("Total duration: {0:N1} seconds" -f ($stopwatch.Elapsed.TotalSeconds))
