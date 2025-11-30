<#
.SYNOPSIS
    Generate a deterministic commit index (path -> last commit/author/date) for the repo.

.DESCRIPTION
    Walks the repository (excluding builds/.git), records the last git commit for each
    repo-relative path, and writes JSON/CSV indexes under builds/cache. Container commits
    for .llb files are also recorded so children can inherit deterministically.

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER OutputPath
    Path to write the JSON index (default: builds/cache/commit-index.json).

.PARAMETER CsvOutputPath
    Optional path to write a CSV copy (default: alongside JSON).

.PARAMETER AllowDirty
    Allow running on a dirty working tree; otherwise abort with guidance.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$OutputPath,
    [string]$CsvOutputPath,

    [string[]]$IncludePaths,
    [string[]]$InputPaths,
    [switch]$UseLvproj = $true,

    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Elapsed {
    param([datetime]$Start)
    $elapsed = (Get-Date) - $Start
    return "[T+{0:N1}s]" -f $elapsed.TotalSeconds
}
function Write-Stamp {
    param([string]$Level = "INFO", [string]$Message, [datetime]$Start)
    Write-Host ("[{0}] {1} {2}" -f $Level, (Get-Elapsed -Start $Start), $Message)
}

function Ensure-Git {
    $g = Get-Command git -ErrorAction SilentlyContinue
    if (-not $g) { throw "git is required to build the commit index but was not found on PATH." }
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

function Get-CommitInfoForPath {
    param([string]$Repo, [string]$RelativePath)
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

function Get-IsDirty {
    param([string]$Repo)
    try {
        $res = git -C $Repo status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return -not [string]::IsNullOrWhiteSpace($res)
    }
    catch {
        return $null
    }
}

function Get-LvprojPaths {
    param([string]$Repo, [datetime]$Start)
    $lvproj = Join-Path $Repo 'lv_icon_editor.lvproj'
    if (-not (Test-Path -LiteralPath $lvproj -PathType Leaf)) { return @() }
    try {
        [xml]$xml = Get-Content -LiteralPath $lvproj
    }
    catch {
        Write-Stamp -Level "WARN" -Message ("Failed to parse lvproj at {0}: {1}" -f $lvproj, $_.Exception.Message) -Start $Start
        return @()
    }
    $paths = @()
    $nodes = $xml.SelectNodes('//Item[@URL]')
    $repoPrefix = ($Repo.TrimEnd('\') + '\')
    foreach ($item in $nodes) {
        $url = $item.URL
        # Skip NI tokens or absolute non-repo locations
        if ($url.StartsWith('/<')) { continue }
        if ($url.StartsWith('<')) { continue }
        $normalized = $url.Replace('/', '\')
        $candidate = $null
        if ([System.IO.Path]::IsPathRooted($normalized)) {
            $candidate = $normalized
        }
        else {
            $candidate = Join-Path $Repo $normalized
        }
        if ($candidate -and $candidate.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $candidate)) {
            $paths += (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $paths
}

$start = Get-Date
$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
Ensure-Git

$dirty = Get-IsDirty -Repo $repoRoot
if ($dirty -and -not $AllowDirty) {
    throw "Working tree is dirty. Clean or rerun with -AllowDirty."
} elseif ($dirty -eq $null) {
    Write-Stamp -Level "WARN" -Message "Could not determine working tree cleanliness (git status failed); continuing." -Start $start
} elseif ($dirty) {
    Write-Stamp -Level "WARN" -Message "Working tree has local changes/untracked files; proceeding due to -AllowDirty." -Start $start
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'builds/cache/commit-index.json'
}
if (-not $CsvOutputPath) {
    $CsvOutputPath = [IO.Path]::ChangeExtension($OutputPath, '.csv')
}
$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$headInfo = Get-HeadCommitInfo -Repo $repoRoot
if (-not $headInfo) {
    Write-Stamp -Level "WARN" -Message "HEAD commit not found; commit index will lack head metadata." -Start $start
}

$repoPrefix = ($repoRoot.TrimEnd('\') + '\')
$includeList = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

if ($InputPaths -and @($InputPaths).Count -gt 0) {
    foreach ($p in $InputPaths) {
        if (-not $p) { continue }
        $candidate = $p
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path $repoRoot $candidate
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $includeList.Add((Resolve-Path -LiteralPath $candidate).Path) | Out-Null
        }
    }
}
else {
    if (-not $IncludePaths -or $IncludePaths.Count -eq 0) {
        $IncludePaths = @(
            'lv_icon_editor.lvproj',
            'Tooling',
            'scripts',
            'resource'
        )
    }

    if ($UseLvproj) {
        foreach ($p in Get-LvprojPaths -Repo $repoRoot -Start $start) {
            $includeList.Add($p) | Out-Null
        }
    }

    foreach ($inc in $IncludePaths) {
        $candidate = Join-Path $repoRoot $inc
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $includeList.Add((Resolve-Path -LiteralPath $candidate).Path) | Out-Null
        }
        else {
            Get-ChildItem -Path $candidate -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notlike ($repoPrefix + '.git*') -and
                    $_.FullName -notlike ($repoPrefix + 'builds*')
                } | ForEach-Object {
                    $includeList.Add($_.FullName) | Out-Null
                }
        }
    }
}

$files = $includeList | Sort-Object | ForEach-Object { Get-Item -LiteralPath $_ -ErrorAction SilentlyContinue } | Where-Object { $_ -and -not $_.PSIsContainer }
$files = @($files)
$total = $files.Count
Write-Stamp -Level "INFO" -Message ("Preparing commit index for {0} files" -f $total) -Start $start

$entries = @()
$count = 0
foreach ($f in $files) {
    $count++
    $rel = [IO.Path]::GetRelativePath($repoRoot, $f.FullName).Replace('\','/')
    $info = Get-CommitInfoForPath -Repo $repoRoot -RelativePath $rel
    if (-not $info) { $info = $headInfo }

    $entries += [pscustomobject]@{
        path        = $rel
        commit      = if ($info) { $info.Commit } else { $null }
        author      = if ($info) { $info.Author } else { $null }
        date        = if ($info) { $info.Date } else { $null }
        isContainer = [bool]([IO.Path]::GetExtension($rel).Equals('.llb',[StringComparison]::OrdinalIgnoreCase))
    }

    if ($count % 200 -eq 0) {
        Write-Stamp -Level "INFO" -Message ("Indexed {0} files..." -f $count) -Start $start
    }
}

$index = [pscustomobject]@{
    metadata = @{
        generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        repo_root        = $repoRoot
        head_commit      = if ($headInfo) { $headInfo.Commit } else { $null }
    }
    entries = $entries
}

$index | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
$entries |
    Select-Object path, commit, author, date, isContainer |
    ConvertTo-Csv -NoTypeInformation |
    Set-Content -LiteralPath $CsvOutputPath -Encoding utf8

Write-Stamp -Level "INFO" -Message ("Commit index written: {0}" -f $OutputPath) -Start $start
Write-Stamp -Level "INFO" -Message ("CSV copy: {0}" -f $CsvOutputPath) -Start $start
Write-Stamp -Level "INFO" -Message ("Entries: {0}" -f $entries.Count) -Start $start
