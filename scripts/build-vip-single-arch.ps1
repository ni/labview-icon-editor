<#
.SYNOPSIS
Build a single-architecture VIP by pruning the other architecture's lvlibp from the VIPB and then invoking build_vip.ps1.

.DESCRIPTION
Creates a temporary copy of the VIPB with the non-target lvlibp entries removed (Additional_Files and Destination_Overrides) so that packaging succeeds when only one lvlibp is present. The original VIPB is left untouched.

.PARAMETER SupportedBitness
Target bitness for the VIP (32 or 64). The other bitness is removed from the VIPB copy.

.PARAMETER RepositoryPath
Path to the repository root.

.PARAMETER VIPBPath
Relative path to the source VIPB. Defaults to the main project VIPB.

.PARAMETER OutputVIPBPath
Where to write the pruned VIPB. Defaults to builds/tmp/seed.<bitness>.vipb under the repo.

.PARAMETER LabVIEWMinorRevision
LabVIEW minor revision (0 or 3) forwarded to build_vip.ps1.

.PARAMETER Major/Minor/Patch/Build/Commit/ReleaseNotesFile/DisplayInformationJSON
Passed through to build_vip.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("32", "64")]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$VIPBPath,
    [string]$OutputVIPBPath,

    [int]$LabVIEWMinorRevision = 3,

    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit = "manual",
    [string]$ReleaseNotesFile = "Tooling/deployment/release_notes.md",
    [string]$DisplayInformationJSON = "{}",

    [switch]$ModifyInPlace
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepoPath {
    param([string]$Path)
    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    catch {
        throw "RepositoryPath does not exist: $Path"
    }
}

$repoRoot = Resolve-RepoPath -Path $RepositoryPath
$semverInputs = @{
    Major = $Major
    Minor = $Minor
    Patch = $Patch
    Build = $Build
}
foreach ($key in $semverInputs.Keys) {
    $val = $semverInputs[$key]
    if ($val -lt 0) { throw "$key must be >= 0; got $val" }
}
$isUnc = $repoRoot -like "\\\\*"
if ($isUnc) {
    Write-Warning "RepositoryPath is a UNC path ($repoRoot). VIPM can behave poorly on UNC paths; consider mapping a drive."
}
$sourceVIPB = if ([System.IO.Path]::IsPathRooted($VIPBPath)) {
    $VIPBPath
} else {
    Join-Path -Path $repoRoot -ChildPath $VIPBPath
}
if (-not (Test-Path -LiteralPath $sourceVIPB)) {
    throw "VIPBPath not found: $sourceVIPB"
}

# Default: modify in place unless an explicit output path is provided
if (-not $OutputVIPBPath) {
    if ($ModifyInPlace -or -not $PSBoundParameters.ContainsKey('ModifyInPlace')) {
        $OutputVIPBPath = $sourceVIPB
    }
    else {
        $OutputVIPBPath = Join-Path -Path $repoRoot -ChildPath ("builds/tmp/seed.{0}.vipb" -f $SupportedBitness)
    }
} elseif (-not [System.IO.Path]::IsPathRooted($OutputVIPBPath)) {
    $OutputVIPBPath = Join-Path -Path $repoRoot -ChildPath $OutputVIPBPath
}

[xml]$vipb = Get-Content -LiteralPath $sourceVIPB -Raw
$otherToken = if ($SupportedBitness -eq "64") { "resource/plugins/lv_icon_x86.lvlibp" } else { "resource/plugins/lv_icon_x64.lvlibp" }

# Remove the other arch's lvlibp entries
$fileNodes = $vipb.SelectNodes("//File[Path[contains(., '$otherToken')]]")
foreach ($node in @($fileNodes)) {
    [void]$node.ParentNode.RemoveChild($node)
}

$destNodes = $vipb.SelectNodes("//Destination_Overrides[Path[contains(., '$otherToken')]]")
foreach ($node in @($destNodes)) {
    [void]$node.ParentNode.RemoveChild($node)
}

# VIPB sanity: ensure target arch destination remains and other arch is gone
$targetToken = "resource/plugins/lv_icon_{0}.lvlibp" -f ($SupportedBitness -eq '64' ? 'x64' : 'x86')
$targetDestNodes = $vipb.SelectNodes("//Destination_Overrides[Path='$targetToken']")
if (-not $targetDestNodes -or $targetDestNodes.Count -eq 0) {
    throw "Pruned VIPB is missing destination for $targetToken; cannot package this arch."
}

# Preflight: ensure the target lvlibp exists before packaging
$targetLvlibp = Join-Path -Path $repoRoot -ChildPath ("resource/plugins/lv_icon_{0}.lvlibp" -f ($SupportedBitness -eq '64' ? 'x64' : 'x86'))
$otherLvlibp = Join-Path -Path $repoRoot -ChildPath ("resource/plugins/lv_icon_{0}.lvlibp" -f ($SupportedBitness -eq '64' ? 'x86' : 'x64'))
if (-not (Test-Path -LiteralPath $targetLvlibp)) {
    $hint = if (Test-Path -LiteralPath $otherLvlibp) {
        " Found the other arch at $otherLvlibp; you may have chosen the wrong bitness."
    } else { "" }
    throw "Expected lvlibp not found for $SupportedBitness-bit build: $targetLvlibp. Build the lvlibp first or run the vip+lvlibp mode.$hint"
}

# Add an exclusion for the removed arch to avoid missing-file packaging errors
$sourceFilesNode = $vipb.VI_Package_Builder_Settings.Advanced_Settings.Source_Files
if ($sourceFilesNode -and -not $vipb.SelectSingleNode("//Exclusions[Path='$otherToken']")) {
    $exclusion = $vipb.CreateElement("Exclusions")
    $pathNode = $vipb.CreateElement("Path")
    $pathNode.InnerText = $otherToken
    [void]$exclusion.AppendChild($pathNode)
    [void]$sourceFilesNode.AppendChild($exclusion)
}

# Normalize Package_LabVIEW_Version to match the selected bitness
try {
    $lvMajor = [int]$packageVersion - 2000
    $lvMinor = [int]$LabVIEWMinorRevision
    $bitnessSuffix = if ($SupportedBitness -eq '64') { " (64-bit)" } else { "" }
    $normalizedLv = "{0}.{1}{2}" -f $lvMajor, $lvMinor, $bitnessSuffix
    $vipb.VI_Package_Builder_Settings.Library_General_Settings.Package_LabVIEW_Version = $normalizedLv
}
catch {
    Write-Warning ("Unable to normalize Package_LabVIEW_Version for bitness {0}: {1}" -f $SupportedBitness, $_.Exception.Message)
}

$outDir = Split-Path -Parent $OutputVIPBPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$vipb.Save($OutputVIPBPath)
$resolvedOutputVIPB = Resolve-Path -LiteralPath $OutputVIPBPath -ErrorAction Stop

# Ensure the pruned VIPB actually dropped the other arch
$reserialized = [xml](Get-Content -LiteralPath $resolvedOutputVIPB -Raw)
if ($reserialized.SelectNodes("//Destination_Overrides[Path[contains(., '$otherToken')]]").Count -gt 0) {
    throw "Pruned VIPB still contains destination for $otherToken; refusing to package. Inspect $resolvedOutputVIPB."
}
if ($reserialized.SelectNodes("//Destination_Overrides[Path='$targetToken']").Count -eq 0) {
    throw "Pruned VIPB no longer contains destination for $targetToken; refusing to package. Inspect $resolvedOutputVIPB."
}

# Build using the pruned VIPB copy
$versionScript = Join-Path -Path $repoRoot -ChildPath "scripts/get-package-lv-version.ps1"
if (-not (Test-Path -LiteralPath $versionScript)) {
    throw "get-package-lv-version.ps1 not found at $versionScript"
}
$packageVersion = & $versionScript -RepositoryPath $repoRoot

if (-not (Get-Command vipm -ErrorAction SilentlyContinue)) {
    throw "vipm CLI not found on PATH. Install VIPM CLI before packaging."
}

$buildVipScript = Join-Path -Path $repoRoot -ChildPath "scripts/build-vip/build_vip.ps1"
if (-not (Test-Path -LiteralPath $buildVipScript)) {
    throw "build_vip.ps1 not found at $buildVipScript"
}

$releaseNotesPath = if ([System.IO.Path]::IsPathRooted($ReleaseNotesFile)) {
    $ReleaseNotesFile
} else {
    Join-Path -Path $repoRoot -ChildPath $ReleaseNotesFile
}
try {
    $releaseNotesDir = Split-Path -Parent $releaseNotesPath
    if ($releaseNotesDir -and -not (Test-Path -LiteralPath $releaseNotesDir)) {
        New-Item -ItemType Directory -Path $releaseNotesDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $releaseNotesPath)) {
        "" | Set-Content -LiteralPath $releaseNotesPath -Encoding utf8
    }
}
catch {
    throw "Unable to ensure ReleaseNotesFile exists or is writable at '$releaseNotesPath': $($_.Exception.Message)"
}

$buildParams = @{
    SupportedBitness        = $SupportedBitness
    RepositoryPath          = $repoRoot
    VIPBPath                = $OutputVIPBPath
    Package_LabVIEW_Version = $packageVersion
    LabVIEWMinorRevision    = $LabVIEWMinorRevision
    Major                   = $Major
    Minor                   = $Minor
    Patch                   = $Patch
    Build                   = $Build
    Commit                  = $Commit
    ReleaseNotesFile        = $releaseNotesPath
    DisplayInformationJSON  = $DisplayInformationJSON
}

try {
    $startTime = Get-Date
    $existingVips = Get-ChildItem -Path (Join-Path $repoRoot 'builds') -Filter *.vip -Recurse -ErrorAction SilentlyContinue
}
catch {
    $existingVips = @()
}

& $buildVipScript @buildParams
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Verify a VIP was produced and surface its path
try {
    $vipsAfter = @(Get-ChildItem -Path (Join-Path $repoRoot 'builds') -Filter *.vip -Recurse -ErrorAction SilentlyContinue)
    $newVips = if ($vipsAfter) { @($vipsAfter | Where-Object { $_.LastWriteTime -ge $startTime }) } else { @() }
    if (-not $newVips -or $newVips.Count -eq 0) {
        throw "No .vip artifact found after packaging. Check vipm logs under builds/logs."
    }
    $newVips | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
        Write-Information ("Produced VIP: {0}" -f $_.FullName) -InformationAction Continue
    }
}
catch {
    throw $_
}
