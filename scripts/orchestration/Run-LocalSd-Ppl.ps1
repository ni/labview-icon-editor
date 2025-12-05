[CmdletBinding()]
param(
    [string]$Repo = '.',
    [string]$RunKey,
    [int]$LockTtlSec = 900,
    [switch]$ForceLock,
    [ValidateSet('32','64')][string]$SupportedBitness = '64',
    [int]$PackageLabVIEWVersion = 2021,
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $Repo).ProviderPath
$runKey = if ($RunKey) { $RunKey } else { "sd-ppl-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" }
$lockPath = Join-Path $repoRoot '.locks/orchestration.lock'
$lockDir = Split-Path -Parent $lockPath
if (-not (Test-Path -LiteralPath $lockDir)) { New-Item -ItemType Directory -Path $lockDir -Force | Out-Null }

# Simulation/parity mode short-circuit (no LabVIEW/VIPM)
$simMode = [string]::Equals($env:OLLAMA_EXECUTOR_MODE, 'sim', 'OrdinalIgnoreCase') -or `
           [string]::Equals($env:ORCH_SIM_MODE, '1', 'OrdinalIgnoreCase') -or `
           [string]::Equals($env:ORCH_SIM_MODE, 'true', 'OrdinalIgnoreCase')

function Rel([string]$Path) {
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

function Ensure-LockPath([string]$Path) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-AppliedRequirements {
    $raw = $env:OLLAMA_REQUIREMENTS_APPLIED
    if ($raw) {
        return ($raw -split '[,\s]+' | Where-Object { $_ }) | Select-Object -Unique
    }
    return @('OEX-PARITY-001','OEX-PARITY-002','OEX-PARITY-003','OEX-PARITY-004')
}

if ($simMode) {
    $logDir = Join-Path $repoRoot 'reports/logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logPath = Join-Path $logDir "local-sd-ppl-$runKey.log"

    $artifactsDir = Join-Path $repoRoot 'artifacts'
    $buildsArtifacts = Join-Path $repoRoot 'builds/artifacts'
    $isoRoot = Join-Path $repoRoot 'builds-isolated'
    $runDir = Join-Path $isoRoot $runKey

    foreach ($dir in @($artifactsDir, $buildsArtifacts, $isoRoot)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $zipPath = Join-Path $artifactsDir 'labview-icon-api.zip'
    $pplPath = Join-Path $artifactsDir 'labview-icon-api.ppl'
    "SIMULATION MODE - stub source distribution for $runKey" | Set-Content -LiteralPath $zipPath -Encoding utf8
    "SIMULATION MODE - stub PPL for $runKey" | Set-Content -LiteralPath $pplPath -Encoding utf8

    Copy-Item -LiteralPath $zipPath -Destination (Join-Path $buildsArtifacts (Split-Path $zipPath -Leaf)) -Force
    Copy-Item -LiteralPath $pplPath -Destination (Join-Path $buildsArtifacts (Split-Path $pplPath -Leaf)) -Force

    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    $pplHash = (Get-FileHash -LiteralPath $pplPath -Algorithm SHA256).Hash

    $appliedReqs = Get-AppliedRequirements
    $handshake = @{
        runKey     = $runKey
        lockPath   = (Ensure-LockPath -Path $lockPath)
        lockTtlSec = $LockTtlSec
        forceLock  = $ForceLock.IsPresent
        zipRelPath = (Rel $zipPath)
        zipSha256  = $zipHash
        pplRelPath = (Rel $pplPath)
        pplSha256  = $pplHash
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode       = 'sim'
        requirements = $appliedReqs
        prereqBypassed = $true
    }

    $handshakePath = Join-Path $artifactsDir 'labview-icon-api-handshake.json'
    ConvertTo-Json $handshake -Depth 5 | Set-Content -LiteralPath $handshakePath -Encoding utf8

    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Copy-Item -Path $artifactsDir -Destination $runDir -Recurse -Force

    $summaryPath = Join-Path $logDir "local-sd-ppl-$runKey.summary.json"
    $handshake | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8

    $messages = @(
        "[local-sd-ppl][sim] runKey=$($handshake.runKey) lock=$($handshake.lockPath) ttl=$($handshake.lockTtlSec)s mode=sim",
        "[local-sd-ppl][sim][requirements] applied=$($appliedReqs -join ',')",
        "[artifact][labview-icon-api.zip] $($handshake.zipRelPath) ($zipHash)",
        "[artifact][labview-icon-api.ppl] $($handshake.pplRelPath) ($pplHash)",
        "[local-sd-ppl][sim] handshake=$((Rel $handshakePath))",
        "[local-sd-ppl][sim] staged=$((Rel $runDir))",
        "[local-sd-ppl][sim] summary-json=$((Rel $summaryPath))"
    )
    $messages | Tee-Object -FilePath $logPath
    exit 0
}

# Create an isolated worktree for the PPL build to keep it separate from the SD build.
$worktreeRoot = Join-Path $repoRoot "builds/worktrees/ppl-$runKey"
if (Test-Path -LiteralPath $worktreeRoot) {
    git -C $repoRoot worktree remove -f $worktreeRoot 2>$null | Out-Null
}
git -C $repoRoot worktree add $worktreeRoot HEAD | Out-Null

$orchArgs = @('local-sd', '--repo', $repoRoot, '--run-key', $runKey, '--lock-path', $lockPath, '--lock-ttl-sec', $LockTtlSec)
if ($ForceLock) { $orchArgs += '--force-lock' }

$invoker = Join-Path $repoRoot 'scripts/common/invoke-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $invoker)) { throw "CLI invoker missing at $invoker" }

Write-Host "[orchestration] runKey=$runKey lock=$lockPath ttl=${LockTtlSec}s force=$ForceLock"
& $invoker -CliName 'OrchestrationCli' -RepoRoot $repoRoot -Args $orchArgs
if ($LASTEXITCODE -ne 0) { throw "OrchestrationCli local-sd failed with exit code $LASTEXITCODE" }

$zipPath = Join-Path $repoRoot 'builds/artifacts/labview-icon-api.zip'
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "labview-icon-api.zip missing; expected at $zipPath" }

$extractRoot = Join-Path $worktreeRoot 'sd-extract'
if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
Write-Host "[sequence] prepare extract at $extractRoot from $zipPath"
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

$projectPath = Join-Path $extractRoot 'lv_icon_editor.lvproj'
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Extracted SD missing project at $projectPath"
}
Write-Host "[sequence] extracted lvproj: $projectPath"

# Copy supporting scripts/Tooling into the extracted SD so dev-mode bind/tests can run in isolation.
$scriptSrc = Join-Path $repoRoot 'scripts'
$scriptDest = Join-Path $extractRoot 'scripts'
if (Test-Path -LiteralPath $scriptSrc) {
    Copy-Item -Path (Join-Path $scriptSrc '*') -Destination $scriptDest -Recurse -Force
}
$toolingSrc = Join-Path $repoRoot 'Tooling'
$toolingDest = Join-Path $extractRoot 'Tooling'
if (Test-Path -LiteralPath $toolingSrc) {
    Copy-Item -LiteralPath $toolingSrc -Destination $toolingDest -Recurse -Force
}

# Bind dev-mode to the extracted SD root for the target bitness.
$bindScriptCandidates = @(
    (Join-Path $extractRoot 'scripts/task-devmode-bind.ps1'),
    (Join-Path $extractRoot 'scripts/scripts/task-devmode-bind.ps1')
)
$bindScript = $bindScriptCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $bindScript) {
    throw "Dev-mode bind script not found under $extractRoot (looked in scripts/ and scripts/scripts/)"
}
Write-Host ("[sequence] dev-mode bind start (bitness={0})" -f $SupportedBitness)
& pwsh -NoProfile -File $bindScript -RepositoryPath $extractRoot -Mode bind -Bitness $SupportedBitness -UseWorktree:$false -Preclear
if ($LASTEXITCODE -ne 0) { throw "Dev-mode bind failed (exit $LASTEXITCODE)" }
Write-Host "[sequence] dev-mode bind complete"

Write-Host "[sequence] missing-check -> unit-tests -> PPL using runKey=$runKey worktree=$worktreeRoot"

Write-Host "[sequence] missing-check start"
$missingScript = Join-Path $repoRoot 'scripts/missing-in-project/RunMissingCheckWithGCLI.ps1'
& pwsh -NoProfile -File $missingScript -LVVersion $PackageLabVIEWVersion -Arch $SupportedBitness -ProjectFile $projectPath
if ($LASTEXITCODE -ne 0) { throw "missing-check failed (exit $LASTEXITCODE); aborting before PPL" }
Write-Host "[sequence] missing-check complete"

Write-Host "[sequence] unit-tests start"
$unitScript = Join-Path $repoRoot 'scripts/run-unit-tests/RunUnitTests.ps1'
& pwsh -NoProfile -File $unitScript -SupportedBitness $SupportedBitness -Package_LabVIEW_Version $PackageLabVIEWVersion -AbsoluteProjectPath $projectPath
if ($LASTEXITCODE -ne 0) { throw "unit-tests failed (exit $LASTEXITCODE); aborting before PPL" }
Write-Host "[sequence] unit-tests complete; starting PPL build"

$pplBuilder = Join-Path $repoRoot 'scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1'
Write-Host "[ppl-from-sd] Building PPL for ${PackageLabVIEWVersion}/${SupportedBitness} using worktree $worktreeRoot extract=$extractRoot"
& pwsh -NoProfile -ExecutionPolicy Bypass -File $pplBuilder `
    -RepositoryPath $worktreeRoot `
    -SourceDistZip $zipPath `
    -ExtractRoot $extractRoot `
    -UseExistingExtract `
    -Package_LabVIEW_Version $PackageLabVIEWVersion `
    -SupportedBitness $SupportedBitness `
    -Major $Major -Minor $Minor -Patch $Patch -Build $Build
if ($LASTEXITCODE -ne 0) { throw "PPL build failed with exit code $LASTEXITCODE" }

$pplSource = Join-Path $extractRoot 'resource/plugins/lv_icon.lvlibp'
if (-not (Test-Path -LiteralPath $pplSource)) { throw "Expected PPL not found at $pplSource" }

$artifactsDir = Join-Path $repoRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null

$zipStaged = Join-Path $artifactsDir 'labview-icon-api.zip'
Copy-Item -LiteralPath $zipPath -Destination $zipStaged -Force

$pplStaged = Join-Path $artifactsDir 'labview-icon-api.ppl'
Copy-Item -LiteralPath $pplSource -Destination $pplStaged -Force

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

$handshakeEntries = @(
    @{Label='labview-icon-api.zip'; Path=$zipStaged},
    @{Label='labview-icon-api.ppl'; Path=$pplStaged}
)

$hashData = @{}
foreach ($entry in $handshakeEntries) {
    $hash = (Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash
    $rel = Get-RelativePath -Path $entry.Path
    $hashData[$entry.Label] = @{path=$rel; sha256=$hash}
    Write-Host "[artifact][$($entry.Label)] $rel ($hash)"
}

$handshake = @{
    runKey = $runKey
    lockPath = (Resolve-Path -LiteralPath $lockPath).Path
    lockTtlSec = $LockTtlSec
    forceLock = $ForceLock.IsPresent
    zipRelPath = $hashData['labview-icon-api.zip'].path
    zipSha256 = $hashData['labview-icon-api.zip'].sha256
    pplRelPath = $hashData['labview-icon-api.ppl'].path
    pplSha256 = $hashData['labview-icon-api.ppl'].sha256
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
}

$handshakePath = Join-Path $artifactsDir 'labview-icon-api-handshake.json'
ConvertTo-Json $handshake -Depth 5 | Set-Content -LiteralPath $handshakePath -Encoding utf8
Write-Host "[handoff] handshake saved at $(Get-RelativePath -Path $handshakePath)"

$isoRoot = Join-Path $repoRoot 'builds-isolated'
$runDir = Join-Path $isoRoot $runKey
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
Copy-Item -Path $artifactsDir -Destination $runDir -Recurse -Force
Write-Host "[handoff] staged under $runDir"

Write-Host "[summary] zip=$(Get-RelativePath -Path $zipStaged) SHA=$($hashData['labview-icon-api.zip'].sha256)"
Write-Host "[summary] ppl=$(Get-RelativePath -Path $pplStaged) SHA=$($hashData['labview-icon-api.ppl'].sha256)"
Write-Host "[summary] runKey=$runKey lockPath=$lockPath lockTtl=$LockTtlSec force=$ForceLock"
