param(
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness,
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev','normal')]
    [string]$State
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $RepositoryPath) {
    $repo = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $repo) { $repo = (Get-Location).ProviderPath }
    $RepositoryPath = $repo
}
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path

function Get-LabVIEWVersionFromVipb {
    param([Parameter(Mandatory)][string]$RootPath)
    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) { throw "No .vipb file found under $RootPath" }
    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) { throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)" }
    $raw = $match.Groups['ver'].Value
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) { throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)" }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    if ($maj -ge 20) { return "20$maj" }
    return $maj.ToString()
}

$lvVersion = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath
$lvRoot = if ($SupportedBitness -eq '64') {
    "C:\Program Files\National Instruments\LabVIEW $lvVersion"
} else {
    "C:\Program Files (x86)\National Instruments\LabVIEW $lvVersion"
}
$iniPath = Join-Path $lvRoot 'LabVIEW.ini'
$viLibPath = Join-Path $lvRoot 'vi.lib\LabVIEW Icon API'

Write-Host "Expect state      : $State"
Write-Host "LabVIEW version   : $lvVersion"
Write-Host "Bitness           : $SupportedBitness-bit"
Write-Host "INI path          : $iniPath"
Write-Host "vi.lib Icon API   : $viLibPath"

if (-not (Test-Path -LiteralPath $iniPath)) {
    Write-Error "LabVIEW.ini not found at $iniPath"
    exit 1
}

$entries = Get-Content -LiteralPath $iniPath | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d*=' }
$entries = @($entries)

$repoNorm = [System.IO.Path]::GetFullPath($RepositoryPath).TrimEnd('\','/')
$matchesRepo = @($entries | Where-Object {
    $parts = $_ -split '=',2
    if ($parts.Count -lt 2) { return $false }
    $val = [System.IO.Path]::GetFullPath($parts[1]).TrimEnd('\','/')
    return $val -eq $repoNorm
})

if ($State -eq 'dev') {
    if (-not $entries -or $matchesRepo.Count -eq 0) {
        Write-Error "Dev mode expected LocalHost.LibraryPaths pointing to repo, but none found in $iniPath"
        exit 2
    }
    if (Test-Path -LiteralPath $viLibPath) {
        Write-Error "Dev mode expected <LabVIEW>\vi.lib\LabVIEW Icon API to be removed, but it exists at $viLibPath"
        exit 3
    }
    Write-Host "Dev mode verified: LocalHost.LibraryPaths present and vi.lib Icon API removed."
    exit 0
}

# Normal mode expectations
if ($entries.Count -gt 0) {
    Write-Error "Normal mode expected no LocalHost.LibraryPaths entries, but found: $($entries -join '; ')"
    exit 4
}
if (-not (Test-Path -LiteralPath $viLibPath)) {
    Write-Error "Normal mode expected <LabVIEW>\vi.lib\LabVIEW Icon API to exist, but it is missing at $viLibPath"
    exit 5
}
Write-Host "Normal mode verified: no LocalHost.LibraryPaths entries and vi.lib Icon API restored."
exit 0
