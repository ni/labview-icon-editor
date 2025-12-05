param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('32','64','both')]
    [string]$SupportedBitness = 'both',

    [Parameter(Mandatory = $false)]
    [string]$Package_LabVIEW_Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$versionScript = Join-Path $repoRoot 'scripts/get-package-lv-version.ps1'
if (-not $Package_LabVIEW_Version) {
    if (Test-Path -LiteralPath $versionScript) {
        $Package_LabVIEW_Version = & $versionScript -RepositoryPath $repoRoot
    } else {
        $Package_LabVIEW_Version = '2023'
    }
}

# Token target: folder containing the first lvproj
$project = Get-ChildItem -Path $repoRoot -Filter '*.lvproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
$tokenTarget = if ($project) { Split-Path -Parent $project.FullName } else { $repoRoot }

# Load INI helper
$helper = Join-Path $repoRoot 'scripts/add-token-to-labview/LocalhostLibraryPaths.ps1'
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw "LocalhostLibraryPaths helper missing: $helper"
}
. $helper

$bitnessList = if ($SupportedBitness -eq 'both') { @('32','64') } else { @($SupportedBitness) }

# Clear packed libraries to avoid stale bindings
$plugins = Join-Path $repoRoot 'resource\plugins'
if (Test-Path -LiteralPath $plugins) {
    Get-ChildItem -LiteralPath $plugins -Filter '*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

foreach ($arch in $bitnessList) {
    Write-Host ("[set-dev] Setting LocalHost.LibraryPaths for {0}-bit LabVIEW {1} -> {2}" -f $arch, $Package_LabVIEW_Version, $tokenTarget)
    Clear-StaleLibraryPaths -LvVersion $Package_LabVIEW_Version -Arch $arch -RepositoryRoot $repoRoot -Force -TargetPath $tokenTarget | Out-Null
    Add-LibraryPathToken -LvVersion $Package_LabVIEW_Version -Arch $arch -TokenPath $tokenTarget -RepositoryRoot $repoRoot | Out-Null
}

# Optional cleanup: close LabVIEW if script exists
$closeScript = Join-Path $repoRoot 'scripts/close-labview/Close_LabVIEW.ps1'
if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
    foreach ($arch in $bitnessList) {
        try {
            & $closeScript -MinimumSupportedLVVersion $Package_LabVIEW_Version -SupportedBitness $arch | Out-Null
        } catch { Write-Warning ("[set-dev] Close_LabVIEW failed for {0}-bit: {1}" -f $arch, $_.Exception.Message) }
    }
}

Write-Host "[set-dev] Development mode tokens applied." -ForegroundColor Green
