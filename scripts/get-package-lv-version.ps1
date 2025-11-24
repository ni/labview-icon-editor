param(
    [Parameter(Mandatory)][string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$vipb = Get-ChildItem -Path $RepositoryPath -Filter *.vipb -File -Recurse | Select-Object -First 1
if (-not $vipb) { throw "No .vipb file found under $RepositoryPath" }

$text = Get-Content -LiteralPath $vipb.FullName -Raw
$match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
if (-not $match.Success) { throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)" }

$raw = $match.Groups['ver'].Value
$verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
if (-not $verMatch.Success) { throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)" }
$maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
$lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
Write-Output $lvVersion
