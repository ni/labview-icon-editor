<#
.SYNOPSIS
Build and run the containerized Seed runner with a Buildx check/fallback.

.NOTES
- Uses docker compose build if buildx is available; otherwise falls back to docker build + compose run --no-build.
- Respects optional env vars: CA_CERT_BUNDLE_BASE64, PESTER_VERSION, PESTER_SHA256.
#>
[CmdletBinding()]
param()

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$composeFile = Join-Path $repoRoot "Tooling/docker/seed-runner/docker-compose.yml"
$dockerfile = Join-Path $repoRoot "Tooling/docker/seed-runner/Dockerfile"
$buildContext = Join-Path $repoRoot "Tooling/docker/seed-runner"

# Ensure host workspace path is available to downstream docker compose inside the runner (for volume binds).
if (-not [Environment]::GetEnvironmentVariable("WORKSPACE_HOST_PATH")) {
    $env:WORKSPACE_HOST_PATH = $repoRoot
}

$buildArgs = @()
foreach ($argName in "CA_CERT_BUNDLE_BASE64","PESTER_VERSION","PESTER_SHA256") {
    $val = [Environment]::GetEnvironmentVariable($argName)
    if (![string]::IsNullOrWhiteSpace($val)) {
        $buildArgs += @("--build-arg", "$argName=$val")
    }
}

$hasBuildx = $true
try {
    & docker buildx version *> $null
} catch {
    $hasBuildx = $false
}

if ($hasBuildx) {
    Write-Host "Building seed-runner image via docker compose (buildx) ..."
    & docker compose -f $composeFile build seed-runner
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Warning "docker buildx not found; falling back to docker build (no Bake). Install buildx for faster builds."
    & docker build -f $dockerfile -t seed-runner:latest @buildArgs $buildContext
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Running seed-runner ..."
if ($hasBuildx) {
    & docker compose -f $composeFile run --rm seed-runner
} else {
    & docker compose -f $composeFile run --rm --no-build seed-runner
}
exit $LASTEXITCODE
