<#
.SYNOPSIS
    Map Source Distribution files back to repo-relative paths (no git).

.DESCRIPTION
    Walks the built "Source Distribution" folder, normalizes paths, applies
    prefix rewrites (e.g., Program Files\National Instruments\LabVIEW 2021\resource
    -> resource), and emits a mapping report to mapping.json with a best-effort
    repo candidate for each file.

.PARAMETER RepositoryPath
    Path to the repository root (contains lv_icon_editor.lvproj).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-DistRoot {
    param([string]$Repo)
    $default = Join-Path $Repo 'builds/Source Distribution'
    if (Test-Path -LiteralPath $default -PathType Container) { return $default }
    $candidates = Get-ChildItem -Path (Join-Path $Repo 'builds') -Directory -Filter '*Source Distribution*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($candidates) { return $candidates[0].FullName }
    throw "Could not locate Source Distribution output folder under $(Join-Path $Repo 'builds')"
}

function Map-RelativePath {
    param([string]$RelativePath, [string]$RepoName)
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

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$distRoot = Get-DistRoot -Repo $repoRoot
$repoName = Split-Path -Leaf $repoRoot
Write-Host ("Using Source Distribution folder: {0}" -f $distRoot)

$files = Get-ChildItem -Path $distRoot -File -Recurse
$repoRootResolved = (Resolve-Path -LiteralPath $repoRoot).Path
$mapping = @()

foreach ($f in $files) {
    $relDist = [IO.Path]::GetRelativePath($distRoot, $f.FullName)
    $mappedRel = Map-RelativePath -RelativePath $relDist -RepoName $repoName
    $candidate = Join-Path $repoRootResolved $mappedRel
    $exists = Test-Path -LiteralPath $candidate
    $mapping += [pscustomobject]@{
        dist_path    = $relDist.Replace('\','/')
        repo_path    = if ($exists) { $candidate } else { $candidate }
        status       = if ($exists) { 'mapped' } else { 'unmapped' }
    }
}

$outPath = Join-Path $distRoot 'mapping.json'
$mapping | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding utf8

$mappedCount   = @($mapping | Where-Object { $_.status -eq 'mapped' }).Count
$unmappedCount = @($mapping | Where-Object { $_.status -eq 'unmapped' }).Count
Write-Host ("Mapping complete. mapped={0} unmapped={1}" -f $mappedCount, $unmappedCount)
Write-Host ("Mapping file: {0}" -f $outPath)
