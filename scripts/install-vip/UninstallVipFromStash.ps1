<#
.SYNOPSIS
    Uninstalls the most recent VI Package produced by the build (from builds/vip-stash) using VIPM CLI.

.DESCRIPTION
    Locates the latest stash folder containing a VIP artifact/manifest. Derives the package name from
    the VIP filename (stripping version suffixes) and runs `vipm uninstall`. Fails early if no stash
    exists so users know a successful build has not yet occurred.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).ProviderPath,
    [ValidateSet('32','64')]
    [string]$LabVIEWBitness = '64',
    [switch]$ForcePlainOutput
)

$ErrorActionPreference = 'Stop'
$isCi = ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true' -or $ForcePlainOutput)
if ($isCi) {
    try { $PSStyle.OutputRendering = 'PlainText' } catch { }
    $ProgressPreference = 'SilentlyContinue'
    $env:NO_COLOR = '1'
    $env:CLICOLOR = '0'
}

function Resolve-RepoRoot {
    param([string]$Path)
    return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
}

$repoRoot  = Resolve-RepoRoot -Path $RepositoryPath
$stashRoot = Join-Path $repoRoot 'builds\vip-stash'
$logsDir   = Join-Path $repoRoot 'builds\logs'
if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $stashRoot -PathType Container)) {
    throw "No VIP stash found at '$stashRoot'. Run the '02 Build LVAddon (VI Package)' task first to produce a package."
}

if (-not (Get-Command vipm -ErrorAction SilentlyContinue)) {
    throw "vipm CLI not found on PATH; cannot uninstall the VI Package."
}

$selected = $null
$stashes = Get-ChildItem -LiteralPath $stashRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
foreach ($dir in $stashes) {
    $manifestPath = Join-Path $dir.FullName 'manifest.json'
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { $manifest = $null }
    }
    if ($manifest -and $manifest.type -ne 'vip') { continue }

    $vipPath = $null
    if ($manifest -and $manifest.vipFile) {
        $candidate = Join-Path $dir.FullName $manifest.vipFile
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $vipPath = $candidate }
    }
    if (-not $vipPath) {
        $vipCandidate = Get-ChildItem -LiteralPath $dir.FullName -Filter *.vip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($vipCandidate) { $vipPath = $vipCandidate.FullName }
    }

    if ($vipPath) {
        $selected = [pscustomobject]@{
            Dir      = $dir.FullName
            Manifest = $manifest
            VipPath  = $vipPath
        }
        break
    }
}

if (-not $selected) {
    throw "No .vip artifacts found under '$stashRoot'. Run the '02 Build LVAddon (VI Package)' task to create a package before uninstalling."
}

$lvVersion = $null
if ($selected.Manifest -and $selected.Manifest.labviewVersion) {
    $lvVersion = $selected.Manifest.labviewVersion
}
else {
    $versionScript = Join-Path $repoRoot 'scripts\get-package-lv-version.ps1'
    if (Test-Path -LiteralPath $versionScript) {
        try { $lvVersion = & $versionScript -RepositoryPath $repoRoot } catch { $lvVersion = $null }
    }
}

$vipLeaf = Split-Path -Leaf $selected.VipPath
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($vipLeaf)
$packageName = $baseName
$m = [regex]::Match($baseName, '^(?<name>.+?)-\d+\.\d+\.\d+(?:[-_]\d+)?$')
if ($m.Success) {
    $packageName = $m.Groups['name'].Value
}

$logFile = Join-Path $logsDir ("vipm-uninstall-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$vipmArgs = @('uninstall', $packageName)
if ($lvVersion) { $vipmArgs += @('--labview-version', $lvVersion) }
if ($LabVIEWBitness) { $vipmArgs += @('--labview-bitness', $LabVIEWBitness) }

Write-Host ("Uninstalling VI Package: {0}" -f $packageName)
Write-Host ("Stash source         : {0}" -f $selected.Dir)
Write-Host ("VIP artifact         : {0}" -f $selected.VipPath)
if ($lvVersion) {
    Write-Host ("LabVIEW target       : {0} ({1}-bit)" -f $lvVersion, $LabVIEWBitness)
}
Write-Host ("vipm log             : {0}" -f $logFile)

try {
    & vipm @vipmArgs 2>&1 | Tee-Object -FilePath $logFile
}
catch {
    $_ | Out-String | Tee-Object -FilePath $logFile -Append | Out-Null
    $LASTEXITCODE = 1
}

if ($LASTEXITCODE -ne 0) {
    throw ("vipm uninstall failed with exit code {0}. See log: {1}" -f $LASTEXITCODE, $logFile)
}

Write-Host ("vipm uninstall succeeded. Log: {0}" -f $logFile)
exit 0
