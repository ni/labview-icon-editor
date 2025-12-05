<#
.SYNOPSIS
    Lists all seeded branches in the repository.

.DESCRIPTION
    Scans for branches matching the seed/lv* pattern and displays their
    target LabVIEW versions. Useful for managing multiple build branches.

    Supports both legacy format (seed/lv2025q3-64bit) and new format with
    timestamps (seed/lv2025q3-64bit-20251203-210500).

.PARAMETER RepositoryPath
    Path to the repository root. Default: current directory.

.PARAMETER Remote
    If specified, lists remote branches instead of local.

.PARAMETER GroupByVersion
    If specified, groups branches by LabVIEW version.

.EXAMPLE
    ./list-seeded-branches.ps1

.EXAMPLE
    ./list-seeded-branches.ps1 -Remote -GroupByVersion
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = ".",
    [switch]$Remote,
    [switch]$GroupByVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath

Write-Host "=== Seeded Branches ===" -ForegroundColor Cyan
Write-Host ""

# Fetch latest
if ($Remote) {
    git -C $repo fetch origin --prune 2>$null | Out-Null
}

# Get branches matching pattern
$pattern = if ($Remote) { 'refs/remotes/origin/seed/lv*' } else { 'refs/heads/seed/lv*' }
$branches = git -C $repo for-each-ref --format='%(refname:short)' $pattern 2>$null

if (-not $branches) {
    Write-Host "No seeded branches found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create a seeded branch, run:" -ForegroundColor Gray
    Write-Host "  ./scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64" -ForegroundColor Gray
    return
}

$results = @()

foreach ($branch in $branches) {
    $branchName = $branch -replace '^origin/', ''
    
    # Parse branch name: seed/lv<year>q<quarter>-<bitness>bit[-timestamp]
    # Supports both legacy (no timestamp) and new format (with timestamp)
    if ($branchName -match '^seed/lv(\d{4})q([13])-(\d{2})bit(?:-(.+))?$') {
        $year = $Matches[1]
        $quarter = "Q$($Matches[2])"
        $bitness = $Matches[3]
        $uniqueId = if ($Matches[4]) { $Matches[4] } else { $null }
        
        $result = [PSCustomObject]@{
            Branch = $branchName
            LabVIEWVersion = $year
            Quarter = $quarter
            Bitness = "${bitness}-bit"
            VersionString = "$([int]$year - 2000).$($Matches[2]) ($bitness-bit)"
            UniqueId = $uniqueId
        }
        
        $results += $result
    }
}

if ($results.Count -eq 0) {
    Write-Host "No valid seeded branches found." -ForegroundColor Yellow
    return
}

# Display results
$results | Sort-Object LabVIEWVersion, Quarter, Bitness -Descending | ForEach-Object {
    $color = if ($_.Quarter -eq 'Q3') { 'Green' } else { 'Cyan' }
    Write-Host "  $($_.Branch)" -ForegroundColor $color
    Write-Host "    Target: LabVIEW $($_.LabVIEWVersion) $($_.Quarter) $($_.Bitness)" -ForegroundColor Gray
    Write-Host "    Version: $($_.VersionString)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Found $($results.Count) seeded branch(es)." -ForegroundColor Cyan
Write-Host ""

# Summary table
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "--------" -ForegroundColor Yellow
$results | Group-Object LabVIEWVersion | ForEach-Object {
    $versions = $_.Group | ForEach-Object { "$($_.Quarter) $($_.Bitness)" }
    Write-Host "  LabVIEW $($_.Name): $($versions -join ', ')"
}

return $results
