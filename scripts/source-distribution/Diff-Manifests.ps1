[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineManifest,
    [Parameter(Mandatory = $true)]
    [string]$CandidateManifest,
    [int]$MaxSample = 20
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-ManifestData {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest not found: $Path"
    }
    $json = Get-Content -LiteralPath $Path -Raw
    $data = $json | ConvertFrom-Json
    if (-not $data) { throw "Manifest empty or invalid JSON: $Path" }
    return ,$data
}

function Compare-ManifestPaths {
    param(
        [array]$Baseline,
        [array]$Candidate,
        [int]$MaxSample
    )
    $basePaths = $Baseline.path
    $candPaths = $Candidate.path
    $missing = @($basePaths | Where-Object { $_ -notin $candPaths })
    $extra   = @($candPaths | Where-Object { $_ -notin $basePaths })
    $dupeBase = ($basePaths | Group-Object | Where-Object Count -gt 1)
    $dupeCand = ($candPaths | Group-Object | Where-Object Count -gt 1)

    Write-Host ("Baseline count: {0}" -f $basePaths.Count)
    Write-Host ("Candidate count: {0}" -f $candPaths.Count)

    Write-Host ("Missing in candidate: {0}" -f $missing.Count)
    if ($missing.Count -gt 0) { $missing | Select-Object -First $MaxSample | ForEach-Object { Write-Host "  $_" } }

    Write-Host ("Extra in candidate: {0}" -f $extra.Count)
    if ($extra.Count -gt 0) { $extra | Select-Object -First $MaxSample | ForEach-Object { Write-Host "  $_" } }

    if ($dupeBase) {
        Write-Host "Duplicates in baseline:"; $dupeBase | ForEach-Object { Write-Host "  $($_.Name) (count=$($_.Count))" }
    }
    if ($dupeCand) {
        Write-Host "Duplicates in candidate:"; $dupeCand | ForEach-Object { Write-Host "  $($_.Name) (count=$($_.Count))" }
    }
}

$baseline = Get-ManifestData -Path $BaselineManifest
$candidate = Get-ManifestData -Path $CandidateManifest

Compare-ManifestPaths -Baseline $baseline -Candidate $candidate -MaxSample $MaxSample
