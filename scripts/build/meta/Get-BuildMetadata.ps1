<#
.SYNOPSIS
    Resolve build metadata (version, commit, author/company) for packaging/build scripts.

.DESCRIPTION
    Derives MAJOR/MINOR/PATCH from the latest git tag (semantic version) when git metadata is present.
    Derives build number from commit count when available. Falls back to provided defaults when git is absent.
    Resolves commit hash (or 'manual' fallback), company/author defaults, and LabVIEW minor revision.

.PARAMETER RepoRoot
    Repository root containing git metadata (optional; when absent, defaults are used).

.PARAMETER DefaultMajor/DefaultMinor/DefaultPatch/DefaultBuild
    Defaults to use when git metadata is unavailable or resolution fails (default 0.1.0.0).

.PARAMETER CompanyName
    Company name (optional; defaults to LabVIEW-Community-CI-CD).

.PARAMETER AuthorName
    Author name (optional; defaults to git config user.name or fallback).

.PARAMETER LabVIEWMinorRevision
    LabVIEW minor revision (default: 3).
#>
param(
    [string]$RepoRoot,
    [int]$DefaultMajor = 0,
    [int]$DefaultMinor = 1,
    [int]$DefaultPatch = 0,
    [int]$DefaultBuild = 0,
    [string]$CompanyName = "LabVIEW-Community-CI-CD",
    [string]$AuthorName,
    [string]$LabVIEWMinorRevision = "3"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-SemverFromLatestTag {
    param([Parameter(Mandatory)][string]$Root)
    $tag = ''
    try {
        $tag = git -C $Root describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) { $tag = '' }
    } catch { $tag = '' }
    if ([string]::IsNullOrWhiteSpace($tag)) { throw "No git tags found for semver." }

    $match = [regex]::Match($tag.Trim(), '^(?:refs/tags/)?v?(?<maj>\d+)\.(?<min>\d+)\.(?<pat>\d+)')
    if (-not $match.Success) { throw "Latest tag '$tag' is not semantic (vMAJOR.MINOR.PATCH)." }
    return [pscustomobject]@{
        Major = [int]$match.Groups['maj'].Value
        Minor = [int]$match.Groups['min'].Value
        Patch = [int]$match.Groups['pat'].Value
        Raw   = $tag.Trim()
    }
}

function Resolve-CommitHash {
    param([string]$Root)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return "manual" }
    try {
        $hash = git -C $Root rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($hash)) {
            return $hash.Trim()
        }
    } catch { $global:LASTEXITCODE = 0 }
    return "manual"
}

function Resolve-CommitCount {
    param([string]$Root)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    try {
        $isShallow = git -C $Root rev-parse --is-shallow-repository 2>$null
        if ($LASTEXITCODE -eq 0 -and $isShallow -and $isShallow.Trim().ToLower() -eq 'true') {
            git -C $Root fetch --unshallow --no-progress 2>$null | Out-Null
        }
    } catch { $global:LASTEXITCODE = 0 }
    try {
        $count = git -C $Root rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $count) { return [int]$count }
    } catch { $global:LASTEXITCODE = 0 }
    return $null
}

function Resolve-GitUserName {
    param([string]$Root, [string]$Fallback)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $Fallback }
    try {
        $name = git -C $Root config user.name 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($name)) { return $name.Trim() }
    } catch { $global:LASTEXITCODE = 0 }
    return $Fallback
}

$hasGit = ($RepoRoot -and (Test-Path (Join-Path $RepoRoot '.git')))

$major = $DefaultMajor; $minor = $DefaultMinor; $patch = $DefaultPatch; $build = $DefaultBuild
if ($hasGit) {
    try {
        $sv = Resolve-SemverFromLatestTag -Root $RepoRoot
        $major = $sv.Major; $minor = $sv.Minor; $patch = $sv.Patch
    } catch { Write-Warning ("[meta] Falling back to defaults for version: {0}" -f $_.Exception.Message) }
    $cc = Resolve-CommitCount -Root $RepoRoot
    if ($cc -ne $null) { $build = $cc }
}

$author = if ($AuthorName) { $AuthorName } else { Resolve-GitUserName -Root $RepoRoot -Fallback $CompanyName }
$commit = Resolve-CommitHash -Root $RepoRoot

[pscustomobject]@{
    Major = $major
    Minor = $minor
    Patch = $patch
    Build = $build
    Commit = $commit
    Company = $CompanyName
    Author = $author
    LabVIEWMinorRevision = $LabVIEWMinorRevision
}
