[CmdletBinding()]
param(
    [string]$SourceRepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$Ref = 'HEAD',
    [string]$WorktreePath,
    [ValidateSet('both','64','32')]
    [string]$SupportedBitness = 'both',
    [ValidateSet('both','64','32')]
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
    [switch]$AnalyzeVIP,
    [switch]$RunBothBitnessSeparately,
    [int]$GcliLockTimeoutSeconds = 300,
    [string]$GcliMutexName = 'Global\LabVIEW-IconEditor-gcli',
    [string]$GcliLockFilePath,
    [switch]$PrepDevMode  # optional: prepare dev mode before build; defaults to on for worktree runs
)

$ErrorActionPreference = 'Stop'

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Resolve-GCliLockPath {
    param([string]$OverridePath)
    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return $OverridePath
    }

    $commonDocs = $null
    try { $commonDocs = [Environment]::GetFolderPath('CommonDocuments') } catch { $commonDocs = $null }
    if (-not [string]::IsNullOrWhiteSpace($commonDocs)) {
        return Join-Path $commonDocs 'labview-icon-editor-gcli.lock'
    }

    $tempRoot = if ($env:WINDIR) { Join-Path $env:WINDIR 'Temp' } else { [System.IO.Path]::GetTempPath() }
    return Join-Path $tempRoot 'labview-icon-editor-gcli.lock'
}

function Acquire-GCliMutex {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [string]$LockFilePath
    )

    $lockPath = Resolve-GCliLockPath -OverridePath $LockFilePath
    $lockDir = Split-Path -Parent $lockPath
    if (-not (Test-Path -LiteralPath $lockDir)) {
        try { New-Item -ItemType Directory -Path $lockDir -Force | Out-Null } catch {
            throw ("Unable to create g-cli/VIPM lock directory '{0}': {1}. Set -GcliLockFilePath to a writable location." -f $lockDir, $_.Exception.Message)
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lock = [pscustomobject]@{
        Kind       = 'File'
        Mutex      = $null
        FileStream = $null
        Path       = $lockPath
    }

    while ($true) {
        try {
            $lock.FileStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            break
        }
        catch [System.UnauthorizedAccessException] {
            throw ("Access denied creating or locking '{0}' for g-cli/VIPM synchronization. Set -GcliLockFilePath to a writable location." -f $lockPath)
        }
        catch {
            if ([DateTime]::UtcNow -ge $deadline) {
                throw ("Another LabVIEW/g-cli/VIPM job is already running (lock '{0}' held; key '{1}'). Wait for it to finish or rerun with a longer -GcliLockTimeoutSeconds." -f $lockPath, $Name)
            }
            Start-Sleep -Seconds 1
        }
    }

    try {
        $mutex = [System.Threading.Mutex]::new($false, $Name)
        if ($mutex.WaitOne([TimeSpan]::Zero)) {
            $lock.Kind = 'File+Mutex'
            $lock.Mutex = $mutex
        }
        else {
            $mutex.Dispose()
        }
    }
    catch {
        # Best-effort; file lock still enforces exclusivity across users.
    }

    return $lock
}

function Release-GCliMutex {
    param([psobject]$Lock)
    if (-not $Lock) { return }

    if ($Lock.Mutex) {
        try { $Lock.Mutex.ReleaseMutex() } catch { }
        try { $Lock.Mutex.Dispose() } catch { }
    }

    if ($Lock.FileStream) {
        try { $Lock.FileStream.Dispose() } catch { }
    }

    if ($Lock.Path) {
        Remove-Item -LiteralPath $Lock.Path -ErrorAction SilentlyContinue
    }
}

Ensure-Command -Name git
if (-not $PSBoundParameters.ContainsKey('PrepDevMode')) { $PrepDevMode = $true }

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

    # Normalize to a PSObject to reliably check properties
    if ($entry -isnot [psobject]) {
        $entry = [pscustomobject]$entry
    }

    $render = $entry | ConvertTo-Json -Depth 5
    $status = $null
    $message = $null
    try { $status = $entry.status } catch {}
    try { $message = $entry.message } catch {}

    if (-not $status) {
        throw ("Dev-mode bind JSON at {0} is missing 'status' for bitness {1}. JSON entry: {2}" -f $jsonPath, $Arch, $render)
    }

    if ($status -ne 'success') {
        $msg = if ($message) { $message } else { 'Unknown bind failure' }
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
    $baseRoot = if ($env:LVIE_WORKTREE_BASE) { $env:LVIE_WORKTREE_BASE } else { [System.IO.Path]::GetTempPath() }
    $nameOverride = $env:LVIE_WORKTREE_NAME

    if (-not $nameOverride) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
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
        $nameOverride = "lv-ie-worktree-$timestamp-$suffix"
    }
    else {
        Write-Host ("Using LVIE_WORKTREE_NAME override: {0}" -f $nameOverride)
    }

    $WorktreePath = Join-Path -Path $baseRoot -ChildPath $nameOverride
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
$gcliMutex = $null
$gcliLockPath = Resolve-GCliLockPath -OverridePath $GcliLockFilePath

Write-Host ("Waiting for LabVIEW g-cli/VIPM lock '{0}' (timeout: {1}s; file: {2})..." -f $GcliMutexName, $GcliLockTimeoutSeconds, $gcliLockPath)
$gcliMutex = Acquire-GCliMutex -Name $GcliMutexName -TimeoutSeconds $GcliLockTimeoutSeconds -LockFilePath $gcliLockPath
Write-Host ("CLI lock acquired: {0}" -f $GcliMutexName)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    git -C $SourceRepoPath rev-parse --verify $Ref | Out-Null

    Write-Host "Adding worktree..."
    git -C $SourceRepoPath worktree add --detach --no-checkout "$WorktreePath" $Ref | Out-Null
    git -C $WorktreePath checkout $Ref | Out-Null
    $worktreeAdded = $true

    $setDevScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath 'scripts/set-development-mode/Set_Development_Mode.ps1')
    $bindDevScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath 'scripts/bind-development-mode/BindDevelopmentMode.ps1')
    $analyzeVipScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath 'scripts/analyze-vi-package/run-local.ps1')
    $buildScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath 'scripts/build/Build.ps1')
    $sourceDistScript = Normalize-ScriptPath (Join-Path -Path $WorktreePath -ChildPath 'scripts/build-source-distribution/Build_Source_Distribution.ps1')

    # Ensure the worktree uses the latest local binder (pick up uncommitted fixes)
    $sourceBinder = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/bind-development-mode/BindDevelopmentMode.ps1'
    if (Test-Path -LiteralPath $sourceBinder) {
        Copy-Item -LiteralPath $sourceBinder -Destination $bindDevScript -Force
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
    # Ensure the worktree uses the local Build.ps1 (pick up uncommitted fixes)
    $sourceBuild = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/build/Build.ps1'
    if (Test-Path -LiteralPath $sourceBuild) {
        Copy-Item -LiteralPath $sourceBuild -Destination $buildScript -Force
    }
    $sourceLvsdDir = Join-Path -Path $SourceRepoPath -ChildPath 'scripts/build-source-distribution'
    $worktreeLvsdDir = Join-Path -Path $WorktreePath -ChildPath 'scripts/build-source-distribution'
    if (Test-Path -LiteralPath $sourceLvsdDir -PathType Container) {
        Copy-Item -LiteralPath $sourceLvsdDir -Destination $worktreeLvsdDir -Recurse -Force
    }

    foreach ($path in @($setDevScript, $bindDevScript, $buildScript, $analyzeVipScript, $sourceDistScript)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Expected script not found: $path"
        }
    }

    $lvVersion = & (Join-Path $WorktreePath 'scripts/get-package-lv-version.ps1') -RepositoryPath $WorktreePath

    if ($PrepDevMode) {
        $bitnessList = if ($LvlibpBitness -eq 'both') { @('32','64') } else { @($SupportedBitness) }
        Write-Host ("Dev-mode preparation for bitness(es): {0}" -f ($bitnessList -join ', '))

        foreach ($arch in ($bitnessList | Select-Object -Unique)) {
            Write-Separator ("Dev-mode bind {0}-bit" -f $arch)
            Write-BitnessBanner -Arch $arch
            Write-Host "Setting development mode ($arch-bit)..."
            & $setDevScript -RepositoryPath $WorktreePath -SupportedBitness $arch

            Write-Host "Binding dev mode (Force) to worktree ($arch-bit)..."
            & $bindDevScript -RepositoryPath $WorktreePath -Mode bind -Bitness $arch -Force

            Assert-DevModeBindOk -RepoPath $WorktreePath -Arch $arch
        }
    }

    # Dev mode tooling can touch the .lvproj; reset it to the repo version before building.
    $lvprojPath = Join-Path $WorktreePath 'lv_icon_editor.lvproj'
    if (Test-Path -LiteralPath $lvprojPath) {
        try {
            Write-Host "Restoring lv_icon_editor.lvproj to clean state before build..."
            git -C $WorktreePath checkout -- lv_icon_editor.lvproj | Out-Null
        }
        catch {
            Write-Warning ("Unable to restore lv_icon_editor.lvproj before build: {0}" -f $_.Exception.Message)
        }
    }

    if (-not $Commit) {
        $Commit = (git -C $WorktreePath rev-parse --short HEAD).Trim()
    }

    $baseBuildArgs = @{
        RepositoryPath       = $WorktreePath
        Major                = $Major
        Minor                = $Minor
        Patch                = $Patch
        Build                = $Build
        Commit               = $Commit
        LabVIEWMinorRevision = $LabVIEWMinorRevision
        CompanyName          = $CompanyName
        AuthorName           = $AuthorName
    }

    $buildSucceeded = $false
    try {
        if ($RunBothBitnessSeparately -and $LvlibpBitness -eq 'both') {
            foreach ($lane in @('64','32')) {
                $laneArgs = $baseBuildArgs.Clone()
                $laneArgs.LvlibpBitness = $lane
                Write-Host "Running isolated build lane for bitness: $lane"
                Write-Separator ("Build start ({0}-bit lane)" -f $lane)
                & $buildScript @laneArgs
            }
        }
        else {
            $buildArgs = $baseBuildArgs.Clone()
            $buildArgs.LvlibpBitness = $LvlibpBitness
            Write-Host "Running full build (bitness: $LvlibpBitness)..."
            Write-Separator "Build start"
            & $buildScript @buildArgs
        }
        $buildSucceeded = $true
    }
    catch {
        Write-Warning ("Native Build.ps1 failed inside worktree; falling back to Orchestration CLI. Error: {0}" -f $_.Exception.Message)
        $resolver = Join-Path $PSScriptRoot 'common/resolve-repo-cli.ps1'
        if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
            throw "CLI resolver not found at $resolver; cannot run fallback orchestrator build. Original error: $($_.Exception.Message)"
        }
        $prov = & $resolver -CliName 'OrchestrationCli' -RepoPath $WorktreePath -SourceRepoPath $SourceRepoPath -PrintProvenance:$false
        $fallbackArgs = @(
            "package-build",
            "--repo", $WorktreePath,
            "--ref", $Ref,
            "--bitness", $SupportedBitness,
            "--lvlibp-bitness", $LvlibpBitness,
            "--major", $Major,
            "--minor", $Minor,
            "--patch", $Patch,
            "--build", $Build,
            "--company", $CompanyName,
            "--author", $AuthorName,
            "--labview-minor", $LabVIEWMinorRevision
        )
        if ($IsWindows) { $fallbackArgs += "--managed" }

        Write-Separator "Build fallback (Orchestration CLI)"
        Write-Host ("{0} {1}" -f $prov.Command[0], ($prov.Command[1..($prov.Command.Count-1)] + $fallbackArgs -join ' '))
        $proc = & $prov.Command[0] @($prov.Command[1..($prov.Command.Count-1)]) @fallbackArgs
        if ($LASTEXITCODE -ne 0) {
            throw ("Fallback orchestrator build failed with exit code {0}. Original error: {1}" -f $LASTEXITCODE, $_.Exception.Message)
        }
        $buildSucceeded = $true
    }

    if ($buildSucceeded) {
        Write-Separator "Source Distribution build"
        Write-Host "Running Source Distribution build..."
        & $sourceDistScript -RepositoryPath $WorktreePath
        if ($LASTEXITCODE -ne 0) {
            throw ("Source Distribution build failed with exit code {0}" -f $LASTEXITCODE)
        }
    }

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
        $vipDir = Join-Path $WorktreePath 'builds\vip-stash'
        $vipCandidates = Get-ChildItem -Path $vipDir -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if (-not $vipCandidates -or $vipCandidates.Count -eq 0) {
            $vipmLog = Join-Path $WorktreePath 'builds\logs\vipm-build-attempt-1.log'
            Write-Error ("VIP not produced; analyzer skipped. Expected a .vip under {0}. Review VIPM log at {1} for details." -f $vipDir, $vipmLog)
            exit 1
        }

        $vipTarget = $vipCandidates | Select-Object -First 1
        Write-Host ("Analyzing built VIP package: {0}" -f $vipTarget.FullName)
        & $analyzeVipScript -VipArtifactPath $vipTarget.FullName -MinLabVIEW '21.0'
    }
    else {
        Write-Host "Skipping VIP analyze (AnalyzeVIP not requested)."
    }
}
finally {
    if ($worktreeAdded -and -not $KeepWorktree) {
        try {
            Write-Host "Removing worktree..."
            $prevAsk = $env:GIT_ASK_YESNO
            $prevPrompt = $env:GIT_TERMINAL_PROMPT
            $env:GIT_ASK_YESNO = 'false'
            $env:GIT_TERMINAL_PROMPT = '0'
            try {
                git -C $SourceRepoPath worktree remove --force "$WorktreePath" | Out-Null
            }
            finally {
                $env:GIT_ASK_YESNO = $prevAsk
                $env:GIT_TERMINAL_PROMPT = $prevPrompt
            }
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

    if ($gcliMutex) {
        Write-Host ("Releasing LabVIEW g-cli/VIPM lock '{0}'" -f $GcliMutexName)
        Release-GCliMutex -Lock $gcliMutex
    }
}

$stopwatch.Stop()
Write-Host ("Total duration: {0:N1} seconds" -f ($stopwatch.Elapsed.TotalSeconds))
