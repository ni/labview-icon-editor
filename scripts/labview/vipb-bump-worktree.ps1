[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetLabVIEWVersion,

[string]$VipbPath = 'Tooling/deployment/seed.vipb',
[string]$WorktreeName = 'lvsd-next',
[string]$SeedImage,
[string]$SeedCmd = 'vipb-set-version',
[string]$SeedBuildContext = '.',
[string]$SeedDockerfile = 'Tooling/seed/Dockerfile',
[switch]$NoWorktree,
[switch]$RunSourceDistribution,
[switch]$RunPackageBuild,
[switch]$RunDevModeBind = $true,
[switch]$ForceWorktree,
[string]$CompanyName = "LabVIEW Icon Editor",
[string]$AuthorName = "Automation Agent",
[string]$BuildScriptPath = 'scripts/build/Build.ps1',
[string]$LvsdProjectPath = 'lv_icon_editor.lvproj',
[string]$LvsdBuildSpec = 'Editor Packed Library',
[string]$LvsdTarget = 'My Computer'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Repo {
    param([string]$Path)
    return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
}

$repo = Resolve-Repo $RepositoryPath
$vipbFull = $null
try {
    $vipbFull = (Resolve-Path -LiteralPath (Join-Path $repo $VipbPath)).ProviderPath
} catch {
    throw "VIPB not found at $VipbPath"
}

# Compute repo commit
$repoCommit = (git -C $repo rev-parse --short HEAD).Trim()
$repoRef = $null
try { $repoRef = (git -C $repo symbolic-ref --short -q HEAD).Trim() } catch {}

$stashDir = Join-Path $repo ("builds/vipb-stash/{0}" -f $repoCommit)
New-Item -ItemType Directory -Force -Path $stashDir | Out-Null

$vipbStaged = Join-Path $stashDir (Split-Path -Leaf $vipbFull)
Copy-Item -LiteralPath $vipbFull -Destination $vipbStaged -Force

# Copy the staged VIPB into the canonical location under the repo so downstream scripts can resolve it
$vipbDest = Join-Path $repo $VipbPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $vipbDest) | Out-Null
Copy-Item -LiteralPath $vipbStaged -Destination $vipbDest -Force

# Derive fork owner and seed image/tag
function Get-RepoOwner {
    param([string]$RepoPath)
    try {
        $url = git -C $RepoPath config --get remote.origin.url
        if ($url -match '[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$') {
            return $Matches['owner']
        }
    } catch {}
    return $null
}
$owner = Get-RepoOwner -RepoPath $repo
if (-not $SeedImage) {
    $SeedImage = if ($owner) { "ghcr.io/$owner/seed:latest" } else { "seed:latest" }
}
$SeedBuildContext = if ($SeedBuildContext) { (Resolve-Path -LiteralPath (Join-Path $repo $SeedBuildContext)).ProviderPath } else { $repo }
$SeedDockerfile = if ($SeedDockerfile) { (Resolve-Path -LiteralPath (Join-Path $repo $SeedDockerfile)).ProviderPath } else { (Join-Path $repo 'Tooling/seed/Dockerfile') }

# Build seed image locally before running
Write-Host "[vipb-bump] Building seed image $SeedImage from $SeedBuildContext (Dockerfile: $SeedDockerfile)"
docker build -f $SeedDockerfile -t $SeedImage $SeedBuildContext
if ($LASTEXITCODE -ne 0) {
    throw "Seed image build failed with exit code $LASTEXITCODE"
}

# Convert VIPB -> JSON, patch the LabVIEW version, convert back via seed image wrappers
$vipbRel = [System.IO.Path]::GetRelativePath($repo, $vipbStaged) -replace '\\','/'
$vipbJson = Join-Path $stashDir 'seed.vipb.json'
$vipbJsonRel = [System.IO.Path]::GetRelativePath($repo, $vipbJson) -replace '\\','/'
Write-Host "[vipb-bump] Converting VIPB to JSON via seed image"
docker run --rm -v "${repo}:/repo" --entrypoint /usr/local/bin/vipb2json $SeedImage --input "/repo/$vipbRel" --output "/repo/$vipbJsonRel"
if ($LASTEXITCODE -ne 0) { throw "vipb2json failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $vipbJson)) {
    throw "vipb2json did not produce JSON at $vipbJson"
}
$json = Get-Content -LiteralPath $vipbJson -Raw | ConvertFrom-Json
$currentVersion = $json.VI_Package_Builder_Settings.Library_General_Settings.Package_LabVIEW_Version
$bitnessSuffix = '64-bit'
if ($currentVersion -and ($currentVersion -match '\((?<bits>\d+)-bit\)')) {
    $bitnessSuffix = "$($Matches['bits'])-bit"
}
$lvMajorToken = $TargetLabVIEWVersion
if ($lvMajorToken -match '^20(?<maj>\d{2})$') { $lvMajorToken = $Matches['maj'] }
$newVersionString = ("{0}.0 ({1})" -f $lvMajorToken, $bitnessSuffix)
$json.VI_Package_Builder_Settings.Library_General_Settings.Package_LabVIEW_Version = $newVersionString
$json | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $vipbJson -Encoding UTF8
Write-Host "[vipb-bump] Updated Package_LabVIEW_Version to '$newVersionString'"
docker run --rm -v "${repo}:/repo" --entrypoint /usr/local/bin/json2vipb $SeedImage --input "/repo/$vipbJsonRel" --output "/repo/$vipbRel"
if ($LASTEXITCODE -ne 0) { throw "json2vipb failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $vipbStaged)) {
    throw "Seed tool did not produce the staged VIPB at $vipbStaged"
}
# Copy bumped VIPB back into the canonical repo path so callers without a worktree see the new version.
Copy-Item -LiteralPath $vipbStaged -Destination $vipbFull -Force

# Compute checksum and manifest
$vipbHash = (Get-FileHash -LiteralPath $vipbStaged -Algorithm SHA256).Hash
$manifest = [ordered]@{
    schema         = 'vipb-bump/v1'
    source_vipb    = $vipbFull
    staged_vipb    = $vipbStaged
    target_version = $TargetLabVIEWVersion
    repo_commit    = $repoCommit
    git_ref        = $repoRef
    hash           = $vipbHash
    timestamp      = (Get-Date).ToString('o')
    seed_image     = $SeedImage
    seed_mode      = 'docker'
    seed_path      = $SeedBuildContext
    seed_cmd       = $SeedCmd
}
$manifestPath = Join-Path $stashDir 'vipb-bump-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "[vipb-bump] Manifest written: $manifestPath"

if ($NoWorktree) {
    Write-Host "[vipb-bump] Worktree creation skipped (--NoWorktree)."
    return
}

$worktreePath = Join-Path (Split-Path -Parent $repo) $WorktreeName
if (Test-Path -LiteralPath $worktreePath) {
    if ($ForceWorktree) {
        Write-Host "[vipb-bump] Removing existing worktree at $worktreePath"
        git -C $repo worktree remove --force $worktreePath 2>$null
        if (Test-Path -LiteralPath $worktreePath) {
            Remove-Item -LiteralPath $worktreePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        throw "Worktree path already exists: $worktreePath (use -ForceWorktree to replace)"
    }
}

Write-Host "[vipb-bump] Creating worktree at $worktreePath"
git -C $repo worktree add --detach $worktreePath $repoCommit

# Apply VIPB and manifest into the worktree and commit
Copy-Item -LiteralPath $vipbStaged -Destination (Join-Path $worktreePath $VipbPath) -Force
$manifestRel = [System.IO.Path]::GetRelativePath($repo, $manifestPath)
$manifestDest = Join-Path $worktreePath $manifestRel
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $manifestDest) | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination $manifestDest -Force

git -C $worktreePath add $VipbPath $manifestRel
git -C $worktreePath commit -m "Bump VIPB LabVIEW version to $TargetLabVIEWVersion" --no-verify

Write-Host "[vipb-bump] Worktree ready at $worktreePath"

# Resolve LabVIEW version/bitness and expected LabVIEW.exe path for downstream runs
$lvVersion = $null
$lvBitness = $null
$lvPath = $null
try {
    $lvVersion = & (Join-Path $worktreePath 'scripts/get-package-lv-version.ps1') -RepositoryPath $worktreePath
    $lvBitness = & (Join-Path $worktreePath 'scripts/get-package-lv-bitness.ps1') -RepositoryPath $worktreePath
    if ($lvBitness -eq 'both') { $lvBitness = '64' }
    $candidate = if ($lvBitness -eq '32') {
        "C:\Program Files (x86)\National Instruments\LabVIEW $lvVersion\LabVIEW.exe"
    } else {
        "C:\Program Files\National Instruments\LabVIEW $lvVersion\LabVIEW.exe"
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $lvPath = $candidate
        Write-Host "[vipb-bump] Using LabVIEW $lvVersion $lvBitness-bit at $lvPath for LVSD"
    } else {
        Write-Warning "[vipb-bump] Expected LabVIEW $lvVersion $lvBitness-bit at $candidate was not found; LVSD will fall back to LabVIEWCLI default."
    }
} catch {
    Write-Warning "[vipb-bump] Unable to resolve LabVIEW version/bitness from VIPB: $($_.Exception.Message)"
}

if ($RunSourceDistribution) {
    $lvsdScript = Join-Path $worktreePath 'scripts/labview/build-source-distribution.ps1'
    if (-not (Test-Path -LiteralPath $lvsdScript)) {
        Write-Warning "[vipb-bump] LVSD script not found at $lvsdScript; skipping source distribution run."
    } else {
        Write-Host "[vipb-bump] Running source distribution in worktree $worktreePath"
        $logDir = Join-Path $worktreePath 'reports/logs'
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $logPath = Join-Path $logDir ("lvsd-build-{0}.log" -f $repoCommit)
        pwsh -NoProfile -File $lvsdScript `
            -RepositoryPath $worktreePath `
            -ProjectPath (Join-Path $worktreePath $LvsdProjectPath) `
            -VipbPath (Join-Path $worktreePath $VipbPath) `
            -BuildSpecName $LvsdBuildSpec `
            -TargetName $LvsdTarget `
            -LabVIEWPath $lvPath `
            -PortNumber 3363 `
            -LogFilePath $logPath
    }
}

if ($RunPackageBuild) {
    $buildScript = Join-Path $worktreePath $BuildScriptPath
    if (-not (Test-Path -LiteralPath $buildScript)) {
        Write-Warning "[vipb-bump] Build script not found at $buildScript; skipping lvlibp/VI Package build."
    } else {
        # Optionally bind dev mode before building
        if ($RunDevModeBind) {
            $bindScript = Join-Path $worktreePath 'scripts/task-devmode-bind.ps1'
            if (Test-Path -LiteralPath $bindScript) {
                Write-Host "[vipb-bump] Binding dev mode in worktree $worktreePath"
                try {
                    pwsh -NoProfile -File $bindScript -RepositoryPath $worktreePath -Mode bind -Bitness auto -Verbose:$false
                } catch {
                    Write-Warning "[vipb-bump] Dev mode bind failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "[vipb-bump] Dev mode bind script not found at $bindScript; skipping bind."
            }
        }
        Write-Host "[vipb-bump] Running lvlibp/VI Package build in worktree $worktreePath"
        try {
            pwsh -NoProfile -File $buildScript -RepositoryPath $worktreePath -CompanyName $CompanyName -AuthorName $AuthorName -Verbose:$false
        } catch {
            Write-Warning "[vipb-bump] Build script failed: $($_.Exception.Message)"
        }
    }
}

Write-Host "Next: run VS Code task '20 LabVIEW: Source Distribution' (if not already run) and the lvlibp/VI Package flow in the worktree $worktreePath."
