param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet("32","64")]
    [string]$SupportedBitness,
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit = "manual"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path

# Resolve LabVIEW version from VIPB
$verScript = Join-Path -Path $repo -ChildPath "scripts/get-package-lv-version.ps1"
if (-not (Test-Path -LiteralPath $verScript)) {
    throw "get-package-lv-version.ps1 not found at $verScript"
}
$lvVer = & $verScript -RepositoryPath $repo

# Fail fast if LocalHost.LibraryPaths is missing for the selected bitness
$pathsScript = Join-Path -Path $repo -ChildPath "scripts/read-library-paths.ps1"
if (-not (Test-Path -LiteralPath $pathsScript)) {
    throw "read-library-paths.ps1 not found at $pathsScript"
}
& $pathsScript -RepositoryPath $repo -SupportedBitness $SupportedBitness -FailOnMissing
if ($LASTEXITCODE -ne 0) {
    throw "LocalHost.LibraryPaths check failed (exit $LASTEXITCODE). Run 'Set Dev Mode (LabVIEW)' for bitness $SupportedBitness and try again."
}

$buildScript = Join-Path -Path $repo -ChildPath "scripts/build-lvlibp/Build_lvlibp.ps1"
if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Build_lvlibp.ps1 not found at $buildScript"
}

& $buildScript `
    -Package_LabVIEW_Version $lvVer `
    -SupportedBitness $SupportedBitness `
    -RepositoryPath $repo `
    -Major $Major `
    -Minor $Minor `
    -Patch $Patch `
    -Build $Build `
    -Commit $Commit

