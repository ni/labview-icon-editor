[CmdletBinding()]
param(
    [string]$RepoPath = '.',
    [string]$OutputRoot = 'builds/LabVIEWIconAPI',
    [string]$CommitIndexPath = 'builds/cache/mock-source-dist-index.json',
    [int]$TimeoutSec = 180
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$outputRoot = if ([IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else { Join-Path $repo $OutputRoot }
$commitIndexPath = if ([IO.Path]::IsPathRooted($CommitIndexPath)) { $CommitIndexPath } else { Join-Path $repo $CommitIndexPath }

$mockGcli = Join-Path $repo 'scripts/smoke/mock-g-cli.cmd'
if (-not (Test-Path -LiteralPath $mockGcli)) {
    throw "mock g-cli shim not found at $mockGcli"
}

$artifactZip = Join-Path $repo 'builds/artifacts/source-distribution.zip'
$cacheRoot = Split-Path -Parent $commitIndexPath
$manifestJson = Join-Path $outputRoot 'manifest.json'
$manifestCsv = Join-Path $outputRoot 'manifest.csv'
$payloads = @(
    (Join-Path -Path $outputRoot -ChildPath 'mock.txt'),
    (Join-Path -Path $outputRoot -ChildPath 'data/mock-data.txt')
)

foreach ($path in @($outputRoot, (Split-Path -Parent $artifactZip), $cacheRoot)) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

if (Test-Path -LiteralPath $outputRoot) { Remove-Item -LiteralPath $outputRoot -Recurse -Force }
if (Test-Path -LiteralPath $artifactZip) { Remove-Item -LiteralPath $artifactZip -Force }
if (Test-Path -LiteralPath $manifestJson) { Remove-Item -LiteralPath $manifestJson -Force }
if (Test-Path -LiteralPath $manifestCsv) { Remove-Item -LiteralPath $manifestCsv -Force }
if (Test-Path -LiteralPath $commitIndexPath) { Remove-Item -LiteralPath $commitIndexPath -Force }

# Create a tiny commit index that matches the mock g-cli payload
$now = Get-Date
$commitIndex = @{
    entries = @(
        @{ path = 'mock.txt'; commit = 'smoke-sha'; author = 'smoke'; date = $now.ToString('o') },
        @{ path = 'data/mock-data.txt'; commit = 'smoke-sha'; author = 'smoke'; date = $now.ToString('o') }
    )
}
$commitIndex | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $commitIndexPath -Encoding UTF8

$invokeCli = Join-Path $repo 'scripts/common/invoke-repo-cli.ps1'
$cliArgs = @(
    'source-dist-build',
    '--repo', $repo,
    '--source-dist-output', $outputRoot,
    '--source-dist-commit-index', $commitIndexPath,
    '--gcli-path', $mockGcli,
    '--timeout-sec', $TimeoutSec
)

$cliArgsJson = $cliArgs | ConvertTo-Json -Depth 4 -Compress
& pwsh -NoProfile -File $invokeCli -CliName 'OrchestrationCli' -RepoRoot $repo -CliArgsJson $cliArgsJson
if ($LASTEXITCODE -ne 0) {
    throw "source-dist-build failed with exit $LASTEXITCODE"
}

$missing = @()
foreach ($path in @($artifactZip, $manifestJson, $manifestCsv) + $payloads) {
    if (-not (Test-Path -LiteralPath $path)) { $missing += $path }
}
if ($missing.Count -gt 0) {
    throw "Missing expected artifacts: $($missing -join ', ')"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipEntries = 0
if (Test-Path -LiteralPath $artifactZip) {
    $zip = [IO.Compression.ZipFile]::OpenRead($artifactZip)
    $zipEntries = $zip.Entries.Count
    $zip.Dispose()
}

$manifest = Get-Content -LiteralPath $manifestJson -Raw | ConvertFrom-Json -Depth 5
$entryCount = @($manifest).Count

$distFileCount = (Get-ChildItem -LiteralPath $outputRoot -Recurse -File | Measure-Object).Count

$result = [pscustomobject]@{
    repo = $repo
    outputRoot = $outputRoot
    artifactZip = $artifactZip
    commitIndex = $commitIndexPath
    manifestEntries = $entryCount
    zipEntries = $zipEntries
    distFiles = $distFileCount
}
$result | ConvertTo-Json -Depth 4 | Write-Host
