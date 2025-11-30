<#
.SYNOPSIS
    Build the "Source Distribution" spec and emit a manifest/zip artifact.

.DESCRIPTION
    Invokes the LabVIEW build spec "Source Distribution" via g-cli lvbuildspec,
    then produces a manifest mapping each built file to the last git commit
    touching the corresponding source path, and zips the output folder.

.PARAMETER RepositoryPath
    Path to the repository root containing lv_icon_editor.lvproj.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to use (e.g., 2021). If omitted, resolves from VIPB.

.PARAMETER SupportedBitness
    Bitness to use (32 or 64). If omitted, resolves from VIPB and defaults
    to 64 when VIPB reports "both".
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$Package_LabVIEW_Version,

    [ValidateSet('32','64','both')]
    [string]$SupportedBitness,

    [string]$CommitIndexPath,

    [switch]$VerboseGit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:StartTime = Get-Date
$script:CurrentPhase = "init"
$script:HeartbeatTimer = $null
$script:HeartbeatSource = $null
$script:PhaseStartTime = $script:StartTime
$script:PhaseWarned = $false
$script:IdleWarnThresholdSec = 240
$tempHelper = Join-Path $PSScriptRoot '..\common\Ensure-StandardTempPath.ps1'
if (-not (Test-Path -LiteralPath $tempHelper)) {
    throw "Missing temp helper at $tempHelper"
}
. $tempHelper
try { Ensure-StandardTempPath -Label 'labview-icon-editor' | Out-Null } catch { throw }

function Get-Elapsed {
    param([datetime]$StartTime = $script:StartTime)
    $elapsed = (Get-Date) - $StartTime
    return "[T+{0:N1}s]" -f $elapsed.TotalSeconds
}
function Write-Stamp {
    param([string]$Level = "INFO", [string]$Message, [datetime]$StartTime = $script:StartTime)
    Write-Host ("[{0}] {1} {2}" -f $Level, (Get-Elapsed -StartTime $StartTime), $Message)
}

function Start-Heartbeat {
    try {
        $script:HeartbeatTimer = New-Object System.Timers.Timer
        $script:HeartbeatTimer.Interval = 60000
        $script:HeartbeatTimer.AutoReset = $true
        $action = {
            if ($script:CurrentPhase) {
                Write-Host ("[HB] {0} phase={1}" -f (Get-Elapsed), $script:CurrentPhase)
                $phaseElapsed = (Get-Date) - $script:PhaseStartTime
                if (-not $script:PhaseWarned -and $phaseElapsed.TotalSeconds -ge $script:IdleWarnThresholdSec) {
                    Write-Host ("[WARN] {0} phase={1} idle for ~{2:N0}s. If LabVIEW/g-cli is showing a dialog or prompt, please close it." -f (Get-Elapsed), $script:CurrentPhase, $phaseElapsed.TotalSeconds)
                    $script:PhaseWarned = $true
                }
            }
        }
        $script:HeartbeatSource = Register-ObjectEvent -InputObject $script:HeartbeatTimer -EventName Elapsed -Action $action
        $script:HeartbeatTimer.Start() | Out-Null
    }
    catch {
        # best-effort; ignore heartbeat failures
    }
}

function Stop-Heartbeat {
    try {
        if ($script:HeartbeatTimer) {
            $script:HeartbeatTimer.Stop()
            $script:HeartbeatTimer.Dispose()
        }
        if ($script:HeartbeatSource) {
            Unregister-Event -SourceIdentifier $script:HeartbeatSource.Name -ErrorAction SilentlyContinue
        }
    }
    catch { }
}

function Set-Phase {
    param([string]$Name)
    $script:CurrentPhase = $Name
    $script:PhaseStartTime = Get-Date
    $script:PhaseWarned = $false
}

function Resolve-VipbVersion {
    param([string]$Repo)
    $script = Join-Path $Repo 'scripts/get-package-lv-version.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Missing get-package-lv-version.ps1 at $script"
    }
    return & $script -RepositoryPath $Repo
}

function Resolve-VipbBitness {
    param([string]$Repo)
    $script = Join-Path $Repo 'scripts/get-package-lv-bitness.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Missing get-package-lv-bitness.ps1 at $script"
    }
    $b = & $script -RepositoryPath $Repo
    if ($b -eq 'both') { return '64' }
    return $b
}

function Get-DistRoot {
    param([string]$Repo)
    $default = Join-Path $Repo 'builds/Source Distribution'
    if (Test-Path -LiteralPath $default -PathType Container) { return $default }
    $candidates = Get-ChildItem -Path (Join-Path $Repo 'builds') -Directory -Filter '*Source Distribution*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($candidates) { return $candidates[0].FullName }
    throw "Could not locate Source Distribution output folder under $(Join-Path $Repo 'builds')"
}

function Get-LastCommitForPath {
    param(
        [string]$Repo,
        [string]$RelativePath
    )
    # Normalize to POSIX-style separators for git
    $normalized = $RelativePath.Replace('\','/')
    try {
        $res = git -C $Repo log -1 --format=%H --full-history --all -- $normalized 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) { return $res.Trim() }
    }
    catch { }
    return $null
}

function Get-LastCommitInfo {
    param(
        [string]$Repo,
        [string]$RelativePath
    )
    $normalized = $RelativePath.Replace('\','/')
    try {
        $res = git -C $Repo log -1 --format='%H|%an|%ai' --full-history --all -- $normalized 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) {
            $parts = $res.Trim().Split('|')
            if ($parts.Count -ge 3) {
                return [pscustomobject]@{
                    Commit = $parts[0]
                    Author = $parts[1]
                    Date   = $parts[2]
                }
            }
        }
    }
    catch { }
    return $null
}

function Get-HeadCommitInfo {
    param([string]$Repo)
    try {
        $res = git -C $Repo log -1 --format='%H|%an|%ai' 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) {
            $parts = $res.Trim().Split('|')
            if ($parts.Count -ge 3) {
                return [pscustomobject]@{
                    Commit = $parts[0]
                    Author = $parts[1]
                    Date   = $parts[2]
                }
            }
        }
    }
    catch { }
    return $null
}

function Get-LlbContainerPath {
    param([string]$RelativePath)
    $p = $RelativePath.Replace('\','/')
    $idx = $p.IndexOf('.llb/')
    if ($idx -ge 0) {
        return $p.Substring(0, $idx + 4) # include ".llb"
    }
    return $null
}

function Map-RelativePath {
    param(
        [string]$RelativePath,
        [string]$RepoName
    )
    $p = $RelativePath.Replace('\','/')
    $rewrites = @(
        @{ from = ("repos/{0}/" -f $RepoName); to = '' },
        @{ from = 'Program Files/National Instruments/LabVIEW 2021/resource/'; to = 'resource/' }
    )
    foreach ($rule in $rewrites) {
        if ($p.StartsWith($rule.from, [StringComparison]::OrdinalIgnoreCase)) {
            $p = $rule.to + $p.Substring($rule.from.Length)
            break
        }
    }
    return $p.TrimStart('/')
}

function Get-RelativePathSafe {
    param([string]$Base,[string]$Target)
    try {
        return [System.IO.Path]::GetRelativePath($Base, $Target)
    }
    catch {
        return $Target
    }
}

function Load-CommitIndex {
    param([string]$Path, [datetime]$StartTime)
    if (-not $Path) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Stamp -Level "WARN" -Message ("Commit index not found at {0}; will fall back to repo head for missing entries." -f $Path) -Start $StartTime
        return $null
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $entries = $raw
        if ($raw.PSObject.Properties.Name -contains 'entries') {
            $entries = $raw.entries
        }
        $map = @{}
        $llbMap = @{}
        foreach ($e in $entries) {
            if (-not $e.path) { continue }
            $key = $e.path.ToString().ToLowerInvariant()
            $map[$key] = $e
            if ($e.isContainer) {
                $llbMap[$key] = $e
            }
        }
        Write-Stamp -Level "INFO" -Message ("Loaded commit index with {0} entries from {1}" -f $map.Count, $Path) -Start $StartTime
        return @{ map = $map; llb = $llbMap; metadata = $raw.metadata }
    }
    catch {
        Write-Stamp -Level "WARN" -Message ("Failed to load commit index at {0}: {1}. Falling back to repo head." -f $Path, $_.Exception.Message) -Start $StartTime
        return $null
    }
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not $Package_LabVIEW_Version) {
    $Package_LabVIEW_Version = Resolve-VipbVersion -Repo $repoRoot
}
if (-not $SupportedBitness) {
    $SupportedBitness = Resolve-VipbBitness -Repo $repoRoot
}
if (-not $CommitIndexPath) {
    $defaultCommitIndex = Join-Path $repoRoot 'builds/cache/commit-index.json'
    if (Test-Path -LiteralPath $defaultCommitIndex -PathType Leaf) {
        $CommitIndexPath = $defaultCommitIndex
        Write-Stamp -Level "INFO" -Message ("Using default commit index: {0}" -f $CommitIndexPath)
    }
}

$projectPath = Join-Path $repoRoot 'lv_icon_editor.lvproj'
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Project not found: $projectPath"
}

$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli) { throw "g-cli is required but was not found on PATH." }

Start-Heartbeat
Write-Stamp -Level "INFO" -Message "Expected durations: build ~60-120s depending on LabVIEW startup; manifest/zip ~10-30s."

# Build the Source Distribution
Set-Phase -Name "g-cli build"
$buildStart = Get-Date
$buildArgs = @(
    '--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    'lvbuildspec',
    '--',
    '-p', $projectPath,
    '-b', 'Source Distribution'
)
Write-Stamp -Level "STEP" -Message ("Building Source Distribution via g-cli: {0}" -f ($buildArgs -join ' '))
$buildArgsEscaped = $buildArgs | ForEach-Object {
    if ($_ -match '\s') { '"' + $_.Replace('"','\"') + '"' } else { $_ }
}
$buildProc = Start-Process -FilePath "g-cli" -ArgumentList $buildArgsEscaped -PassThru -NoNewWindow
if (-not $buildProc) {
    throw "Failed to start g-cli process."
}
Write-Stamp -Level "INFO" -Message ("g-cli pid={0} started; waiting for completion..." -f $buildProc.Id)
Wait-Process -Id $buildProc.Id
$buildExit = 0
try { $buildExit = $buildProc.ExitCode } catch { $buildExit = $LASTEXITCODE }
if ($buildExit -ne 0) {
    throw "lvbuildspec failed with exit code $buildExit"
}
$buildEnd = Get-Elapsed
$buildDuration = ((Get-Date) - $buildStart).TotalSeconds
Write-Stamp -Level "INFO" -Message ("g-cli build completed (duration={0:N1}s)" -f $buildDuration)
Write-Stamp -Level "STEP" -Message "Source Distribution built; generating manifest and zip next..."
Write-Stamp -Level "INFO" -Message "Build spec succeeded (pre-manifest/zip); locating distribution folder..."

$distRoot = Get-DistRoot -Repo $repoRoot
Write-Stamp -Level "INFO" -Message ("Using Source Distribution folder: {0}" -f $distRoot)

# Create manifest
$manifestPath = Join-Path $distRoot 'manifest.json'
$manifestStartTime = Get-Date
$files = Get-ChildItem -Path $distRoot -File -Recurse
$totalFiles = $files.Count
$processed = 0
$repoRootResolved = (Resolve-Path -LiteralPath $repoRoot).Path
$repoName = Split-Path -Leaf $repoRootResolved
$manifest = @()
$pathsForIndex = New-Object System.Collections.Generic.List[string]
$headCommitInfo = Get-HeadCommitInfo -Repo $repoRootResolved

# Build a commit index based on the actual built files (post-build).
$commitIndexMap = @{}
$commitIndexLlbMap = @{}
$commitIndexScript = Join-Path $repoRoot 'scripts/build-source-distribution/New-CommitIndex.ps1'
if ($CommitIndexPath -and (Test-Path -LiteralPath $commitIndexScript -PathType Leaf)) {
    $script:CurrentPhase = "commit-index"
    foreach ($f in $files) {
        $relDist = [IO.Path]::GetRelativePath($distRoot, $f.FullName)
        $mappedRel = Map-RelativePath -RelativePath $relDist -RepoName $repoName
        if ($mappedRel) { $pathsForIndex.Add($mappedRel) | Out-Null }
    }
    $uniquePaths = $pathsForIndex | Where-Object { $_ } | Sort-Object -Unique
    if ($uniquePaths.Count -gt 0) {
        Write-Stamp -Level "STEP" -Message ("Generating commit index from built files ({0} paths)..." -f $uniquePaths.Count)
        try {
            & pwsh -NoProfile -File $commitIndexScript -RepositoryPath $repoRoot -OutputPath $CommitIndexPath -InputPaths $uniquePaths -AllowDirty | Out-Null
            Write-Stamp -Level "INFO" -Message ("Commit index generated at {0}" -f $CommitIndexPath)
        }
        catch {
            Write-Stamp -Level "WARN" -Message ("Commit index generation failed: {0}. Falling back to repo head for missing entries." -f $_.Exception.Message)
        }
    }
}
elseif (-not $CommitIndexPath) {
    Write-Stamp -Level "WARN" -Message "Commit index path not supplied; using repo head for unmatched files." -Start $script:StartTime
}

# Load commit index if available
$commitIndex = $null
if ($CommitIndexPath) {
    $commitIndex = Load-CommitIndex -Path $CommitIndexPath -StartTime $script:StartTime
    if ($commitIndex) {
        $commitIndexMap = $commitIndex.map
        $commitIndexLlbMap = $commitIndex.llb
    }
}

$script:CurrentPhase = "manifest"
Write-Stamp -Level "STEP" -Message ("Creating manifest for {0} files..." -f $totalFiles)
foreach ($f in $files) {
    $processed++
    $relDist = [IO.Path]::GetRelativePath($distRoot, $f.FullName)
    $sourceRel = $relDist.Replace('\','/')
    $mappedRel = Map-RelativePath -RelativePath $relDist -RepoName $repoName
    $sourceCandidate = if ($mappedRel) { Join-Path $repoRootResolved $mappedRel } else { $null }
    $commitInfo = $headCommitInfo
    $commitSource = 'repo_head'
    $indexKey = ($mappedRel ? $mappedRel : $relDist).Replace('\','/').ToLowerInvariant()
    if ($commitIndexMap.Count -gt 0 -and $indexKey) {
        if ($commitIndexMap.ContainsKey($indexKey)) {
            $entry = $commitIndexMap[$indexKey]
            if ($entry.commit) {
                $commitInfo = [pscustomobject]@{
                    Commit = $entry.commit
                    Author = $entry.author
                    Date   = $entry.date
                }
                $commitSource = 'index'
            }
        }
        if ($commitSource -eq 'repo_head') {
            $llbPath = Get-LlbContainerPath -RelativePath ($mappedRel ? $mappedRel : $relDist)
            if ($llbPath) {
                $llbKey = $llbPath.ToLowerInvariant()
                if ($commitIndexLlbMap.ContainsKey($llbKey)) {
                    $entry = $commitIndexLlbMap[$llbKey]
                    $commitInfo = [pscustomobject]@{
                        Commit = $entry.commit
                        Author = $entry.author
                        Date   = $entry.date
                    }
                    $commitSource = 'llb_container'
                }
            }
        }
    }
    $manifest += [pscustomobject]@{
        path        = $sourceRel
        last_commit = if ($commitInfo) { $commitInfo.Commit } else { $null }
        commit_author = if ($commitInfo) { $commitInfo.Author } else { $null }
        commit_date   = if ($commitInfo) { $commitInfo.Date } else { $null }
        size_bytes  = $f.Length
        commit_source = $commitSource
    }

    if ($VerboseGit) {
        Write-Stamp -Level "INFO" -Message ("[git] {0}/{1} {2} -> {3}" -f $processed, $totalFiles, ($mappedRel ? $mappedRel : $relDist), ($manifest[-1].last_commit ?? 'null'))
    } elseif ($processed % 50 -eq 0) {
        Write-Stamp -Level "INFO" -Message ("Processed {0}/{1} files for manifest..." -f $processed, $totalFiles)
    }
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
# Also emit CSV for spreadsheet/requirements ingestion.
$manifestCsvPath = Join-Path $distRoot 'manifest.csv'
$manifest | Select-Object path,last_commit,commit_author,commit_date,commit_source,size_bytes |
    ConvertTo-Csv -NoTypeInformation |
    Set-Content -LiteralPath $manifestCsvPath -Encoding utf8
Write-Host ("Manifest written: {0}" -f $manifestPath)
$manifestEndTime = Get-Date
$manifestDuration = ($manifestEndTime - $manifestStartTime).TotalSeconds
Write-Stamp -Level "INFO" -Message ("Manifest complete (files={0}, duration={1:N1}s)" -f $totalFiles, $manifestDuration)

# Zip the distribution (including manifest)
Set-Phase -Name "zip"
$zipStartTime = Get-Date
$artifactDir = Join-Path $repoRoot 'builds/artifacts'
if (-not (Test-Path -LiteralPath $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}
$zipPath = Join-Path $artifactDir 'source-distribution.zip'
Write-Stamp -Level "STEP" -Message "Zipping Source Distribution..."
Compress-Archive -Path (Join-Path $distRoot '*') -DestinationPath $zipPath -Force
$zipEndTime = Get-Date
$zipDuration = ($zipEndTime - $zipStartTime).TotalSeconds
Write-Stamp -Level "INFO" -Message ("Zipped Source Distribution: {0}" -f $zipPath)

$relJson = Get-RelativePathSafe -Base $repoRoot -Target $manifestPath
$relCsv = Get-RelativePathSafe -Base $repoRoot -Target $manifestCsvPath
$relZip = Get-RelativePathSafe -Base $repoRoot -Target $zipPath
Write-Host ("[artifact][source-distribution] manifest.json: {0}" -f $relJson)
Write-Host ("[artifact][source-distribution] manifest.csv: {0}" -f $relCsv)
Write-Host ("[artifact][source-distribution] zip: {0}" -f $relZip)
Write-Host ("[info] Built with LabVIEW {0} ({1}-bit) based on VIPB." -f $Package_LabVIEW_Version, $SupportedBitness)
Write-Host ("[info] Next steps: run task 21 (Verify: Source Distribution) to validate the manifest; or task 22 (Build PPL from Source Distribution) to produce the PPL from this zip.")
Write-Host ("[info] Extracted contents: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target $distRoot))
Write-Host ("[info] Log-stash bundles (if enabled) are under builds/log-stash/.")
Write-Host ("[info] Re-run will overwrite artifacts; delete the dist folder for a clean extract if needed.")
Write-Stamp -Level "INFO" -Message ("Phase summary: build {0:N1}s, manifest {1:N1}s, zip {2:N1}s" -f $buildDuration, $manifestDuration, $zipDuration)

# Best-effort: close LabVIEW used for this build to avoid leaving it running.
$closeScript = Join-Path $repoRoot 'scripts\close-labview\Close_LabVIEW.ps1'
if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
    try {
        Write-Host ("[info] Closing LabVIEW {0} ({1}-bit) after build..." -f $Package_LabVIEW_Version, $SupportedBitness)
        & pwsh -NoProfile -File $closeScript -Package_LabVIEW_Version $Package_LabVIEW_Version -SupportedBitness $SupportedBitness | Out-Null
    }
    catch {
        Write-Warning ("[info] Failed to close LabVIEW after build: {0}" -f $_.Exception.Message)
    }
}

$logStashScript = Join-Path $repoRoot 'scripts/log-stash/Write-LogStashEntry.ps1'
if (Test-Path -LiteralPath $logStashScript -PathType Leaf) {
    try {
        $durationMs = [int][Math]::Round(((Get-Date) - $script:StartTime).TotalMilliseconds,0)
        $attachments = @($manifestPath, $manifestCsvPath, $zipPath) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        & $logStashScript `
            -RepositoryPath $repoRoot `
            -Category 'source-distribution' `
            -Label 'Build_Source_Distribution' `
            -LogPaths @() `
            -AttachmentPaths $attachments `
            -Status 'success' `
            -ProducerScript $PSCommandPath `
            -ProducerTask 'Build_Source_Distribution' `
            -ProducerArgs @{ RepositoryPath = $repoRoot; Package_LabVIEW_Version = $Package_LabVIEW_Version; SupportedBitness = $SupportedBitness } `
            -StartedAtUtc $script:StartTime.ToUniversalTime() `
            -DurationMs $durationMs | Out-Null
    }
    catch {
        Write-Warning ("[lvsd] Failed to write log-stash bundle: {0}" -f $_.Exception.Message)
    }
}

Stop-Heartbeat
