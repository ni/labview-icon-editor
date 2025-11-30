[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [switch]$ForceDryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Request file not found: $Path"
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON at ${Path}: $($_.Exception.Message)"
    }
}

$request = Read-JsonFile -Path $RequestPath

$repoRoot = if ($request.repoRoot) {
    if ([System.IO.Path]::IsPathRooted($request.repoRoot)) { $request.repoRoot } else { Join-Path (Get-Location) $request.repoRoot }
} else {
    Get-Location
}
$repoRoot = (Resolve-Path -LiteralPath $repoRoot -ErrorAction Stop).ProviderPath

$label = if ($request.PSObject.Properties['label']) { $request.label } else { "vi-compare-sample" }
$outputRoot = if ($request.outputRoot) {
    if ([System.IO.Path]::IsPathRooted($request.outputRoot)) { $request.outputRoot } else { Join-Path $repoRoot $request.outputRoot }
} else {
    Join-Path $repoRoot ".tmp-tests/vi-compare-replays/$label"
}

$captureDir = Join-Path $outputRoot "captures/pair-001"
New-Item -ItemType Directory -Path $captureDir -Force | Out-Null

$dryRun = $true
if ($null -ne $request.dryRun) { $dryRun = [bool]$request.dryRun }
if ($ForceDryRun) { $dryRun = $true }
$timestamp = Get-Date

$sessionPath = Join-Path $captureDir 'session-index.json'
$cliCapturePath = Join-Path $captureDir 'lvcompare-capture.json'
$reportPath = Join-Path $captureDir 'compare-report.html'

$session = [ordered]@{
    schema  = 'teststand-compare-session/v1'
    at      = $timestamp.ToString("o")
    status  = if ($dryRun) { 'dry-run' } else { 'failed' }
    reason  = if ($dryRun) { 'Dry-run mode: LabVIEW CLI execution skipped.' } else { 'LVCompare not invoked (placeholder wrapper).' }
}
$session | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sessionPath -Encoding utf8

$cliCapture = [ordered]@{
    schema = 'labview-cli-capture@v1'
    status = if ($dryRun) { 'dry-run' } else { 'failed' }
    reason = $session.reason
    at     = $timestamp.ToString("o")
}
$cliCapture | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cliCapturePath -Encoding utf8

"<!DOCTYPE html><html><head><meta charset='utf-8'><title>VI Compare ($($session.status))</title></head><body><p>$($session.reason)</p></body></html>" | Set-Content -LiteralPath $reportPath -Encoding utf8

$logStashScript = Join-Path $repoRoot 'scripts/log-stash/Write-LogStashEntry.ps1'
if (Test-Path -LiteralPath $logStashScript) {
    try {
        $logs = @()
        $attachments = @($sessionPath, $cliCapturePath, $reportPath)
        & $logStashScript `
            -RepositoryPath $repoRoot `
            -Category 'compare' `
            -Label $label `
            -LogPaths $logs `
            -AttachmentPaths $attachments `
            -Status $session.status `
            -ProducerScript $PSCommandPath `
            -ProducerTask 'RunViCompareReplay.ps1' `
            -ProducerArgs @{ RequestPath = $RequestPath } `
            -StartedAtUtc $timestamp.ToUniversalTime() `
            -DurationMs 0
    }
    catch {
        Write-Warning ("[compare] Failed to write log-stash bundle: {0}" -f $_.Exception.Message)
    }
}

Write-Host "[compare] Capture directory: $captureDir"
Write-Host "[compare] Status: $($session.status)"

if (-not $dryRun) {
    exit 1
}
