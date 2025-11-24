param(
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Resolve repository root (default: git top-level)
if (-not $RepositoryPath) {
    $repo = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $repo) { $repo = (Get-Location).ProviderPath }
    $RepositoryPath = $repo
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$helperPath = Resolve-Path (Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1')
. $helperPath

function Get-LabVIEWVersionFromVipb {
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) {
        throw "No .vipb file found under $RootPath"
    }

    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)"
    }

    $raw = $match.Groups['ver'].Value
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) {
        throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)"
    }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    $lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $lvVersion
}

$lvVersion = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath

$iniPath = Resolve-LVIniPath -LvVersion $lvVersion -Arch $SupportedBitness

Write-Host "LabVIEW version : $lvVersion"
Write-Host "Bitness         : $SupportedBitness-bit"
Write-Host "INI path        : $iniPath"

$raw = Get-Content -LiteralPath $iniPath -Raw -Encoding UTF8
Write-Host "----- BEGIN LabVIEW.ini -----"
Write-Host $raw
Write-Host "----- END LabVIEW.ini -----"

exit 0
