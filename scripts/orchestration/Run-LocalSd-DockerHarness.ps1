<#
Runs a Docker-based harness to validate LVSD-008 locking/run-key coordination without requiring LabVIEW in the container.
Prereqs: Docker Desktop, dotnet SDK/pwsh on host. Uses ORCH_SKIP_LOCAL_SD_BUILD=1 to exercise lock/run-key only.
#>
param(
    [string]$Repo = (Get-Location).ProviderPath,
    [string]$ImageName = "local-sd-lock",
    [string]$RunKeyA = "runA",
    [string]$RunKeyB = "runB"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Publish-OrchestrationCli {
    param([string]$RepoRoot)
    $proj = Join-Path $RepoRoot "Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj"
    $out = Join-Path $RepoRoot "builds/docker/OrchestrationCli"
    if (Test-Path $out) { Remove-Item -Recurse -Force $out }
    dotnet publish $proj -c Release -r linux-x64 --self-contained false -o $out | Out-Null
    return $out
}

$repoRoot = (Resolve-Path $Repo).ProviderPath
Write-Host "Repo: $repoRoot"

# Clean lock/artifacts for a fresh run
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue (Join-Path $repoRoot ".locks")
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue (Join-Path $repoRoot "builds-isolated")
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue (Join-Path $repoRoot "artifacts")

# Publish OrchestrationCli for Linux container
$publishPath = Publish-OrchestrationCli -RepoRoot $repoRoot
$dockerContext = Join-Path $repoRoot "builds/docker/context"
if (Test-Path $dockerContext) { Remove-Item -Recurse -Force $dockerContext }
New-Item -ItemType Directory -Path (Join-Path $dockerContext "OrchestrationCli") -Force | Out-Null
Copy-Item -Path (Join-Path $publishPath "*") -Destination (Join-Path $dockerContext "OrchestrationCli") -Recurse -Force
Copy-Item -Path (Join-Path $repoRoot "Tooling/docker/local-sd-lock/Dockerfile") -Destination $dockerContext -Force

Push-Location $dockerContext
docker build -t $ImageName .
if ($LASTEXITCODE -ne 0) { throw "docker build failed with exit code $LASTEXITCODE" }
Pop-Location

function Run-LocalSdContainer {
    param([string]$runKey,[switch]$Force,[switch]$KeepLock)
    $envs = @("ORCH_SKIP_LOCAL_SD_BUILD=1", "ORCH_RUN_KEY=$runKey")
    if ($Force) { $envs += "ORCH_FORCE=1" }
    if ($KeepLock) { $envs += "ORCH_KEEP_LOCK=1" }
    $envArgs = @()
    foreach ($envVar in $envs) { $envArgs += @("--env", $envVar) }
    docker run --rm -v "${repoRoot}:/workspace" -w /workspace $envArgs $ImageName local-sd --repo /workspace --run-key $runKey | Out-Host
    $code = $LASTEXITCODE
    return $code
}

Write-Host "Running container A ($RunKeyA) (keeps lock)..."
$exitA = Run-LocalSdContainer -runKey $RunKeyA -KeepLock
Write-Host "Exit A: $exitA"

Write-Host "Running container B ($RunKeyB) expecting busy..."
$exitB = Run-LocalSdContainer -runKey $RunKeyB
Write-Host "Exit B: $exitB"

Write-Host "Running container B with force to proceed..."
$exitBForce = Run-LocalSdContainer -runKey $RunKeyB -Force
Write-Host "Exit B(force): $exitBForce"

if (Test-Path (Join-Path $repoRoot "builds-isolated")) {
    Write-Host "Staged runs:"
    Get-ChildItem -Path (Join-Path $repoRoot "builds-isolated") -Directory | Select-Object Name
}

if ($exitA -ne 0) { Write-Error "Container A failed (lock/run-key setup)"; exit $exitA }
if ($exitB -eq 0) { Write-Error "Container B unexpectedly succeeded (lock contention not enforced)"; exit 1 }
Write-Host "Docker harness completed. Force run exit: $exitBForce"
