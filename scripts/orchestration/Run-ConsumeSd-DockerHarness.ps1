[CmdletBinding()]
param(
    [string]$Repo = (Get-Location).ProviderPath,
    [string]$ImageName = "consume-sd-harness",
    [string]$RunKeyA,
    [string]$RunKeyB,
    [int]$LockTtlSec = 900
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI not found; Docker Desktop is required for the consume-sd harness."
}

$repoRoot = (Resolve-Path -LiteralPath $Repo).ProviderPath
$handshakePath = Join-Path $repoRoot 'artifacts/labview-icon-api-handshake.json'
if (-not (Test-Path -LiteralPath $handshakePath)) {
    throw "Handshake JSON not found at $handshakePath; run the Windows handshake script first."
}
$handshake = Get-Content -LiteralPath $handshakePath | ConvertFrom-Json
if (-not $RunKeyA) { $RunKeyA = $handshake.runKey }
if (-not $RunKeyB) { $RunKeyB = "$($handshake.runKey)-force" }

function Publish-OrchestrationCli {
    param([string]$RepoRoot)
    $proj = Join-Path $RepoRoot "Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj"
    $out = Join-Path $RepoRoot "builds/docker/OrchestrationCli"
    if (Test-Path -LiteralPath $out) { Remove-Item -Recurse -Force $out }
    dotnet publish $proj -c Release -r linux-x64 --self-contained false -o $out | Out-Null
    return $out
}

$publishPath = Publish-OrchestrationCli -RepoRoot $repoRoot
$dockerContext = Join-Path $repoRoot "builds/docker/consume-sd"
if (Test-Path -LiteralPath $dockerContext) { Remove-Item -Recurse -Force $dockerContext }
New-Item -ItemType Directory -Path (Join-Path $dockerContext "OrchestrationCli") -Force | Out-Null
Copy-Item -Path (Join-Path $publishPath "*") -Destination (Join-Path $dockerContext "OrchestrationCli") -Recurse -Force
Copy-Item -Path (Join-Path $repoRoot "Tooling/docker/consume-sd/Dockerfile") -Destination $dockerContext -Force

(Push-Location $dockerContext)
docker build -t $ImageName .
if ($LASTEXITCODE -ne 0) { throw "docker build failed with exit code $LASTEXITCODE" }
(Pop-Location)

function Run-Container {
    param([string]$runKey,[switch]$Force,[switch]$KeepLock)
    $envs = @("ORCH_SKIP_LOCAL_SD_BUILD=1", "ORCH_RUN_KEY=$runKey", "ORCH_LOCK_TTL_SEC=$LockTtlSec")
    if ($Force) { $envs += "ORCH_FORCE=1" }
    if ($KeepLock) { $envs += "ORCH_KEEP_LOCK=1" }
    $envArgs = @()
    foreach ($env in $envs) {
        $envArgs += '--env'
        $envArgs += $env
    }
    docker run --rm -v "${repoRoot}:/workspace" -w /workspace --entrypoint "/usr/bin/pwsh" $envArgs $ImageName `
        -NoProfile -File scripts/orchestration/ConsumeSdInContainer.ps1 `
        -Repo /workspace -HandshakePath /workspace/artifacts/labview-icon-api-handshake.json `
        -RunKey $runKey -Force:$Force -KeepLock:$KeepLock
    return $LASTEXITCODE
}

Write-Host "[harness] handshake path: $handshakePath"

$exitA = Run-Container -runKey $RunKeyA -KeepLock
Write-Host "[harness] container A exit code: $exitA"
if ($exitA -ne 0) { throw "First consume run failed (A) with exit code $exitA" }

$exitB = Run-Container -runKey $RunKeyB
Write-Host "[harness] container B exit (expected busy): $exitB"
if ($exitB -eq 0) { throw "Container B unexpectedly succeeded; busy guard did not trigger." }

$exitBForce = Run-Container -runKey $RunKeyB -Force
Write-Host "[harness] container B (force) exit: $exitBForce"
if ($exitBForce -ne 0) { throw "Forced consume run failed with exit code $exitBForce" }

if (Test-Path -LiteralPath (Join-Path $repoRoot 'builds-isolated')) {
    Write-Host "[harness] staged runs:"
    Get-ChildItem -Path (Join-Path $repoRoot 'builds-isolated') -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
}

Write-Host "[harness] Docker consume workflow completed."
