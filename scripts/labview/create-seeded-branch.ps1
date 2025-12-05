<#
.SYNOPSIS
    Creates a seeded branch with a custom VIPB targeting a specific LabVIEW version.

.DESCRIPTION
    This script creates a new git branch with a modified VIPB file that targets
    a specific LabVIEW version and bitness. The branch can then be used to create
    a PR to develop, triggering a CI build.

    Branch naming convention: seed/lv<year>q<quarter>-<bitness>bit-<timestamp>
    Examples:
      - seed/lv2025q3-64bit-20251203-210500 -> LabVIEW 2025 Q3 64-bit
      - seed/lv2025q1-64bit-20251203-211200 -> LabVIEW 2025 Q1 64-bit
      - seed/lv2024q3-32bit-20251204-093000 -> LabVIEW 2024 Q3 32-bit

    The timestamp ensures multiple builds of the same version don't conflict.

.PARAMETER RepositoryPath
    Path to the repository root. Default: current directory.

.PARAMETER LabVIEWVersion
    The LabVIEW major version year (e.g., 2021, 2024, 2025).

.PARAMETER LabVIEWMinor
    The LabVIEW minor version: '0' for Q1, '3' for Q3. Default: '3'.

.PARAMETER Bitness
    Target bitness: '32' or '64'. Default: '64'.

.PARAMETER BaseBranch
    The base branch to create the seeded branch from. Default: 'develop'.

.PARAMETER RunKey
    Optional custom identifier for the branch. If not provided, a timestamp is used.
    This allows for reproducible branch names when needed.

.PARAMETER NoTimestamp
    If specified, omits the timestamp from the branch name.
    WARNING: This may cause conflicts if multiple builds target the same version.

.PARAMETER DryRun
    If specified, shows what would be done without making changes.

.EXAMPLE
    # Create a seeded branch for LabVIEW 2025 Q3 64-bit (with auto-generated timestamp)
    ./create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64

.EXAMPLE
    # Create multiple seeded branches for the same version (each gets unique timestamp)
    ./create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64
    ./create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64

.EXAMPLE
    # Create a branch with a custom run key for reproducibility
    ./create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64 -RunKey "release-v1.0"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RepositoryPath = ".",

    [Parameter(Mandatory = $true)]
    [ValidateRange(2020, 2030)]
    [int]$LabVIEWVersion,

    [ValidateSet('0', '3')]
    [string]$LabVIEWMinor = '3',

    [ValidateSet('32', '64')]
    [string]$Bitness = '64',

    [string]$BaseBranch = 'develop',

    [string]$RunKey,

    [switch]$NoTimestamp,

    [switch]$DryRun,

    # Seed image settings (vendored/local by default)
    [string]$SeedImage,
    [string]$SeedBuildContext = '.',
    [string]$SeedDockerfile = 'Tooling/seed/Dockerfile',
    [switch]$SkipSeedBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runOnWindows = $PSVersionTable.OS -like '*Windows*'

# Resolve repository path
$repo = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$SeedImage = if ($SeedImage) { $SeedImage } elseif ($env:SEED_IMAGE) { $env:SEED_IMAGE } else { 'seed:latest' }
$SeedBuildContext = (Resolve-Path -LiteralPath (Join-Path $repo $SeedBuildContext)).ProviderPath
$SeedDockerfile = (Resolve-Path -LiteralPath (Join-Path $repo $SeedDockerfile)).ProviderPath

# Calculate version string
$lvMajor = $LabVIEWVersion - 2000
$quarter = if ($LabVIEWMinor -eq '3') { 'q3' } else { 'q1' }
$versionString = "$lvMajor.$LabVIEWMinor ($Bitness-bit)"

# Generate unique identifier for branch name
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$uniqueId = if ($RunKey) { $RunKey } elseif (-not $NoTimestamp) { $timestamp } else { $null }

# Generate branch name with optional unique identifier
$branchBase = "seed/lv$($LabVIEWVersion)$quarter-${Bitness}bit"
$branchName = if ($uniqueId) { "$branchBase-$uniqueId" } else { $branchBase }

Write-Host "=== Seeded Branch Creation ===" -ForegroundColor Cyan
Write-Host "Target: LabVIEW $LabVIEWVersion $($quarter.ToUpper()) ${Bitness}-bit"
Write-Host "Version String: $versionString"
Write-Host "Branch Name: $branchName"
Write-Host "Base Branch: $BaseBranch"
if ($uniqueId) {
    Write-Host "Unique ID: $uniqueId"
}
Write-Host "Seed Image: $SeedImage"
Write-Host "Seed Build Context: $SeedBuildContext"
Write-Host "Seed Dockerfile: $SeedDockerfile"
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would create branch '$branchName' from '$BaseBranch'" -ForegroundColor Yellow
    Write-Host "[DRY RUN] Would update VIPB to: Package_LabVIEW_Version = $versionString" -ForegroundColor Yellow
    Write-Host "[DRY RUN] Seed image would be built/used: $SeedImage (Dockerfile: $SeedDockerfile)" -ForegroundColor Yellow
    return [PSCustomObject]@{
        BranchName = $branchName
        LabVIEWVersion = $LabVIEWVersion
        LabVIEWMinor = $LabVIEWMinor
        Quarter = $quarter.ToUpper()
        Bitness = $Bitness
        VersionString = $versionString
        BaseBranch = $BaseBranch
        UniqueId = $uniqueId
        DryRun = $true
    }
}

# Check if branch already exists (only warn if NoTimestamp is used)
$existingBranch = git -C $repo branch --list $branchName 2>$null
$existingRemote = git -C $repo ls-remote --heads origin $branchName 2>$null

if ($existingBranch -or $existingRemote) {
    if ($NoTimestamp) {
        throw "Branch '$branchName' already exists. Remove -NoTimestamp to use unique timestamps, or delete the existing branch first."
    }
    # This shouldn't happen with timestamps, but handle it gracefully
    Write-Warning "Branch '$branchName' exists. Generating new timestamp..."
    Start-Sleep -Milliseconds 1100  # Ensure new timestamp
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $branchName = "$branchBase-$timestamp"
    Write-Host "New branch name: $branchName" -ForegroundColor Yellow
}

# Fetch base branch (best effort)
Write-Host "Fetching base branch '$BaseBranch' (best effort)..." -ForegroundColor Gray
git -C $repo fetch origin $BaseBranch 2>$null

# Ensure seed image exists (build unless explicitly skipped)
if (-not $SkipSeedBuild) {
    Write-Host "Building seed image '$SeedImage' (Dockerfile: $SeedDockerfile)" -ForegroundColor Gray
    docker build -f $SeedDockerfile -t $SeedImage $SeedBuildContext
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Seed image build failed (code $LASTEXITCODE). Attempting to pull fallback ghcr.io/labview-community-ci-cd/seed:latest..."
        docker pull ghcr.io/labview-community-ci-cd/seed:latest
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build or pull seed image '$SeedImage'"
        }
        if ($SeedImage -ne 'seed:latest') {
            docker tag ghcr.io/labview-community-ci-cd/seed:latest $SeedImage
        }
    }
} else {
    Write-Host "Skipping seed image build (--SkipSeedBuild). Expecting image '$SeedImage' to be available." -ForegroundColor Yellow
}

# Docker user mapping to avoid root-owned outputs on Linux
$dockerUserArgs = @()
if (-not $runOnWindows) {
    $uid = (& id -u)
    $gid = (& id -g)
    $dockerUserArgs = @('--user', "$uid`:$gid")
}

# Create new branch from local base (works even if remote is stale)
Write-Host "Creating branch '$branchName' from '$BaseBranch'..." -ForegroundColor Gray
git -C $repo checkout -B $branchName $BaseBranch
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create branch '$branchName'"
}

# Path to VIPB
$vipbPath = Join-Path $repo 'Tooling/deployment/seed.vipb'
if (-not (Test-Path -LiteralPath $vipbPath)) {
    throw "VIPB file not found at $vipbPath"
}

# Use Seed Docker container to modify VIPB
$stashDir = Join-Path $repo "builds/vipb-stash"
New-Item -ItemType Directory -Force -Path $stashDir | Out-Null

$vipbJson = Join-Path $stashDir 'seed.vipb.json'
$vipbRel = 'Tooling/deployment/seed.vipb'
$vipbJsonRel = 'builds/vipb-stash/seed.vipb.json'

Write-Host "Converting VIPB to JSON..." -ForegroundColor Gray
docker run --rm @dockerUserArgs -v "${repo}:/repo" -w /repo --entrypoint /usr/local/bin/VipbJsonTool `
    $SeedImage vipb2json "/repo/$vipbRel" "/repo/$vipbJsonRel"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to convert VIPB to JSON"
}

# Modify JSON
Write-Host "Updating Package_LabVIEW_Version to '$versionString'..." -ForegroundColor Gray
$json = Get-Content -Raw -Encoding UTF8 $vipbJson | ConvertFrom-Json
$lg = $null
if ($json.PSObject.Properties['VI_Package_Builder_Settings']) {
    $lg = $json.VI_Package_Builder_Settings.Library_General_Settings
}
if (-not $lg -and $json.PSObject.Properties['Package']) {
    $lg = $json.Package.Library_General_Settings
}
if (-not $lg -and $json.PSObject.Properties['Library_General_Settings']) {
    $lg = $json.Library_General_Settings
}
if (-not $lg) {
    $known = ($json.PSObject.Properties.Name -join ', ')
    throw "Library_General_Settings not found in VIPB JSON. Known top-level properties: $known"
}
$lg.Package_LabVIEW_Version = $versionString
if ($lg.PSObject.Properties['Library_Version']) {
    $lg.Library_Version = "$lvMajor.$LabVIEWMinor.0.1"
}
$json | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $vipbJson -Encoding UTF8

# Convert back to VIPB
Write-Host "Converting JSON back to VIPB..." -ForegroundColor Gray
docker run --rm @dockerUserArgs -v "${repo}:/repo" -w /repo --entrypoint /usr/local/bin/VipbJsonTool `
    $SeedImage json2vipb "/repo/$vipbJsonRel" "/repo/$vipbRel"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to convert JSON to VIPB"
}

# Clean up JSON
Remove-Item -LiteralPath $vipbJson -Force -ErrorAction SilentlyContinue

# Create manifest
$manifest = [ordered]@{
    schema = 'seeded-branch/v1'
    branch_name = $branchName
    branch_base = $branchBase
    unique_id = $uniqueId
    base_branch = $BaseBranch
    labview_version = $LabVIEWVersion
    labview_minor = $LabVIEWMinor
    labview_quarter = $quarter.ToUpper()
    bitness = $Bitness
    version_string = $versionString
    created_at = (Get-Date).ToString('o')
    commit = (git -C $repo rev-parse --short HEAD)
}
$manifestPath = Join-Path $stashDir 'seeded-branch-manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

# Commit changes
Write-Host "Committing changes..." -ForegroundColor Gray
git -C $repo add $vipbRel
git -C $repo commit -m "Seed VIPB for LabVIEW $LabVIEWVersion $($quarter.ToUpper()) ${Bitness}-bit

Target: $versionString
Branch: $branchName
Base: $BaseBranch"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to commit changes"
}

Write-Host ""
Write-Host "=== Success ===" -ForegroundColor Green
Write-Host "Branch '$branchName' created with VIPB targeting:" -ForegroundColor Green
Write-Host "  LabVIEW Version: $LabVIEWVersion $($quarter.ToUpper())" -ForegroundColor Green
Write-Host "  Bitness: ${Bitness}-bit" -ForegroundColor Green
Write-Host "  Version String: $versionString" -ForegroundColor Green
if ($uniqueId) {
    Write-Host "  Unique ID: $uniqueId" -ForegroundColor Green
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Push the branch: git push origin $branchName"
Write-Host "  2. Create a PR from '$branchName' to '$BaseBranch'"
Write-Host "  3. The CI pipeline will trigger automatically"
Write-Host ""

# Return branch info for scripting
return [PSCustomObject]@{
    BranchName = $branchName
    BranchBase = $branchBase
    UniqueId = $uniqueId
    LabVIEWVersion = $LabVIEWVersion
    LabVIEWMinor = $LabVIEWMinor
    Quarter = $quarter.ToUpper()
    Bitness = $Bitness
    VersionString = $versionString
    BaseBranch = $BaseBranch
    CreatedAt = (Get-Date).ToString('o')
}
