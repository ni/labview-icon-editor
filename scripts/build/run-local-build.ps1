param(
    [string]$RepositoryPath,
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 1,
    [string]$CompanyName = "LabVIEW-Community-CI-CD",
    [string]$AuthorName = "LabVIEW Icon Editor CI",
    [int]$LabVIEWMinorRevision = 3
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Resolve repo path (git top-level if not provided)
if (-not $RepositoryPath) {
    $top = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if (-not $top) { $top = (Get-Location).ProviderPath }
    $RepositoryPath = $top
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
if ([string]::IsNullOrWhiteSpace($RepositoryPath) -or -not (Test-Path -LiteralPath $RepositoryPath)) {
    throw "RepositoryPath is empty or does not exist."
}

# Compute commit (best effort)
$commit = git -C $RepositoryPath rev-parse HEAD 2>$null
if (-not $commit) { $commit = 'manual' }

& (Join-Path $PSScriptRoot 'Build.ps1') `
    -RepositoryPath $RepositoryPath `
    -Major $Major `
    -Minor $Minor `
    -Patch $Patch `
    -Build $Build `
    -LabVIEWMinorRevision $LabVIEWMinorRevision `
    -Commit $commit `
    -CompanyName $CompanyName `
    -AuthorName $AuthorName
