<#
.SYNOPSIS
    Builds the Editor Packed Library (.lvlibp) using g-cli.

.DESCRIPTION
    Invokes the LabVIEW build specification "Editor Packed Library" through
    g-cli, embedding the provided version information and commit identifier.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version used for the build.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root where the project file resides.

.PARAMETER Major
    Major version component for the PPL.

.PARAMETER Minor
    Minor version component for the PPL.

.PARAMETER Patch
    Patch version component for the PPL.

.PARAMETER Build
    Build number component for the PPL.

.PARAMETER Commit
    Commit hash or identifier recorded in the build.

.EXAMPLE
    .\Build_lvlibp.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor" -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
#>
param(
    [Alias('MinimumSupportedLVVersion')][string]$Package_LabVIEW_Version,
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [Int32]$Major = 0,
    [Int32]$Minor = 1,
    [Int32]$Patch = 0,
    [Int32]$Build = 0,
    [string]$Commit
)

function Resolve-SemverFromLatestTag {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $tag = ''
    try {
        $tag = git -C $RepoRoot describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) {
            $tag = ''
        }
    }
    catch {
        $tag = ''
    }

    if ([string]::IsNullOrWhiteSpace($tag)) {
        throw "No git tags were found. Create a semantic version tag (for example, v0.1.0) so PPL versioning can derive MAJOR/MINOR/PATCH."
    }

    $tagTrimmed = $tag.Trim()
    $match = [regex]::Match($tagTrimmed, '^(?:refs/tags/)?v?(?<maj>\d+)\.(?<min>\d+)\.(?<pat>\d+)')
    if (-not $match.Success) {
        throw "Latest tag '$tag' is not a semantic version (expected vMAJOR.MINOR.PATCH[...])."
    }

    return [PSCustomObject]@{
        Major = [int]$match.Groups['maj'].Value
        Minor = [int]$match.Groups['min'].Value
        Patch = [int]$match.Groups['pat'].Value
        Raw   = $tagTrimmed
    }
}

    # Resolve version from VIPB for determinism
$versionScript = @(
    (Join-Path $PSScriptRoot '..\..\scripts\get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\..\scripts\get-package-lv-version.ps1') # fallback if invoked from a different working dir
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $versionScript) {
    throw "Unable to locate get-package-lv-version.ps1 relative to $PSScriptRoot"
}

# Normalize/guard the repository path (worktree/x-cli occasionally passes empty)
if (-not $RepositoryPath) {
    $repoGuess = Join-Path $PSScriptRoot '..\\..'
    try {
        $RepositoryPath = (Resolve-Path -LiteralPath $repoGuess -ErrorAction Stop).ProviderPath
    }
    catch {
        throw ("RepositoryPath was empty and default resolution failed (tried {0}): {1}" -f $repoGuess, $_.Exception.Message)
    }
}
else {
    $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
}

$Package_LabVIEW_Version = & $versionScript -RepositoryPath $RepositoryPath

$hasGit = Test-Path (Join-Path $RepositoryPath '.git')

# Override Major/Minor/Patch from the latest tag to keep PPL version aligned with repo semver when git is available
if ($hasGit) {
    try {
        $semver = Resolve-SemverFromLatestTag -RepoRoot $RepositoryPath
        $Major = $semver.Major
        $Minor = $semver.Minor
        $Patch = $semver.Patch
        Write-Information ("Using semantic version from latest tag for PPL: v{0}.{1}.{2}" -f $Major, $Minor, $Patch) -InformationAction Continue
    }
    catch {
        Write-Warning ("Unable to derive version from git tags; using provided version {0}.{1}.{2}" -f $Major, $Minor, $Patch)
    }
}
else {
    Write-Information ("No git metadata found at {0}; using provided version {1}.{2}.{3}" -f $RepositoryPath, $Major, $Minor, $Patch) -InformationAction Continue
}

# Derive build number from total commit count for PPL versioning; fall back to provided value
$DerivedBuild = $Build
if ($hasGit) {
    try {
        $isShallowRepo = git -C $RepositoryPath rev-parse --is-shallow-repository 2>$null
        if ($LASTEXITCODE -eq 0 -and $isShallowRepo -and $isShallowRepo.Trim().ToLower() -eq 'true') {
            git -C $RepositoryPath fetch --unshallow --no-progress 2>$null | Out-Null
        }
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    try {
        $commitCount = git -C $RepositoryPath rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $commitCount) {
            $DerivedBuild = [int]$commitCount
            Write-Information ("Using commit count for PPL build number: {0}" -f $DerivedBuild) -InformationAction Continue
        }
        else {
            Write-Information ("Falling back to provided build number: {0}" -f $Build) -InformationAction Continue
        }
    }
    catch {
        Write-Information ("Falling back to provided build number: {0} (commit count unavailable)" -f $Build) -InformationAction Continue
        $global:LASTEXITCODE = 0
    }
}
else {
    Write-Information ("No git history present; using provided build number: {0}" -f $Build) -InformationAction Continue
}
$Build = $DerivedBuild
Write-Output "PPL Version: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

$buildArgs = @(
"--lv-ver", $Package_LabVIEW_Version,
"--arch", $SupportedBitness,
    "lvbuildspec",
    "--",
    "-v", "$Major.$Minor.$Patch.$Build",
    "-p", "$RepositoryPath\lv_icon_editor.lvproj",
    "-b", "Editor Packed Library"
)
Write-Information ("Executing: g-cli {0}" -f ($buildArgs -join ' ')) -InformationAction Continue

$output = & g-cli @buildArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    $joined = ($output -join '; ')
    Write-Error "Build failed with exit code $LASTEXITCODE. Output: $joined"
    $closeScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'close-labview\Close_LabVIEW.ps1'
    try {
        if (-not (Test-Path -LiteralPath $closeScript)) {
            throw "Close_LabVIEW.ps1 not found at expected path: $closeScript"
        }
        & $closeScript -Package_LabVIEW_Version $Package_LabVIEW_Version -SupportedBitness $SupportedBitness | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW after build failure: {0}" -f $_.Exception.Message)
    }
    exit 1
}

Write-Information "Build succeeded." -InformationAction Continue
exit 0

