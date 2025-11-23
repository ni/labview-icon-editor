param(
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness,
    [switch]$FailOnMissing,
    [string]$IniPath
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

$allowCustom = [bool]$env:ALLOW_NONCANONICAL_LV_INI_PATH
$canonical = if ($SupportedBitness -eq '64') {
    "C:\Program Files\National Instruments\LabVIEW $lvVersion\LabVIEW.ini"
} else {
    "C:\Program Files (x86)\National Instruments\LabVIEW $lvVersion\LabVIEW.ini"
}

$iniCandidates = @()
if ($IniPath) {
    if (-not $allowCustom -and $IniPath -ne $canonical) {
        throw "Non-canonical LabVIEW.ini path provided: $IniPath. Expected: $canonical"
    }
    $iniCandidates += $IniPath
} else {
    $iniCandidates += $canonical
}

$iniPath = $iniCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

Write-Host "LabVIEW version : $lvVersion"
Write-Host "Bitness         : $SupportedBitness-bit"
Write-Host "INI candidates  : $($iniCandidates -join '; ')"
Write-Host "INI path        : $iniPath"

if (-not $iniPath) {
    Write-Error "LabVIEW.ini not found at canonical path: $canonical"
    exit 1
}

if (-not $allowCustom -and $iniPath -ne $canonical) {
    throw "Non-canonical LabVIEW.ini resolved: $iniPath. Expected: $canonical"
}

$lines = Get-Content -LiteralPath $iniPath
$entries = $lines | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d*=' }
$entries = @($entries)

if (-not $entries -or $entries.Count -eq 0) {
    $msg = "No LocalHost.LibraryPaths entries found in $iniPath"
    Write-Warning $msg
    if ($FailOnMissing) {
        Write-Host "Hint: Run the VSCode task 'Set Dev Mode (LabVIEW)' for bitness $SupportedBitness, or call .github/actions/set-development-mode/run-dev-mode.ps1 -SupportedBitness $SupportedBitness to populate the INI." -ForegroundColor Yellow
        Write-Error $msg
        exit 2
    }
    exit 0
}

$index = 1
$repoPathNormalized = [System.IO.Path]::GetFullPath($RepositoryPath).TrimEnd('\','/')
$mismatched = @()
foreach ($entry in $entries) {
    Write-Host ("[{0}] {1}" -f $index, $entry)
    $value = ($entry -split '=',2)[1]
    $valuePath = [System.IO.Path]::GetFullPath($value).TrimEnd('\','/')
    if ($valuePath -ne $repoPathNormalized) {
        $mismatched += $value
    }
    $index++
}

if ($mismatched.Count -gt 0) {
    $example = $mismatched | Select-Object -First 1
    Write-Warning ("Found LocalHost.LibraryPaths entries that do not point to this repo (example: {0}). Consider running 'Revert Dev Mode (LabVIEW)' then 'Set Dev Mode (LabVIEW)' for bitness {1} to refresh the path." -f $example, $SupportedBitness)
    if ($FailOnMissing) {
        Write-Error "LocalHost.LibraryPaths entries are not pointing to this repo."
        exit 3
    }
}

exit 0
