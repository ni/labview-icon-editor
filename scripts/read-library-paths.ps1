param(
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness,
    [switch]$FailOnMissing
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
$helperPath = Resolve-Path (Join-Path $PSScriptRoot 'add-token-to-labview\LocalhostLibraryPaths.ps1')
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

$lines = Get-Content -LiteralPath $iniPath
$entries = $lines | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d*=' }
$entries = @($entries)

if (-not $entries -or $entries.Count -eq 0) {
    $msg = "No LocalHost.LibraryPaths entries found in $iniPath"
    Write-Warning $msg
    if ($FailOnMissing) {
        Write-Host "Hint: Run the VSCode task 'Set Dev Mode (LabVIEW)' for bitness $SupportedBitness, or call scripts/set-development-mode/run-dev-mode.ps1 -SupportedBitness $SupportedBitness to populate the INI." -ForegroundColor Yellow
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
    $valueRaw = ($entry -split '=',2)[1]
    # Trim surrounding quotes from INI values before comparing paths
    $value = $valueRaw.Trim('"')
    $valuePath = [System.IO.Path]::GetFullPath($value).TrimEnd('\','/')
    if ($valuePath -ne $repoPathNormalized) {
        $mismatched += $value
    }
    $index++
}

if ($mismatched.Count -gt 0) {
    $taskHint = "VS Code tasks: 'Revert Dev Mode (LabVIEW)' then 'Set Dev Mode (LabVIEW)' for bitness {0}".ToString() -f $SupportedBitness
    foreach ($badPath in $mismatched) {
        Write-Warning ("Found LocalHost.LibraryPaths entry that do not point to this repo: {0}. {1} (Terminal -> Run Task) to refresh the INI, then rerun your build." -f $badPath, $taskHint)
    }
    if ($FailOnMissing) {
        Write-Error "LocalHost.LibraryPaths entries do not point to this repo. Run the dev-mode tasks noted above and retry."
        exit 3
    }
}

exit 0
