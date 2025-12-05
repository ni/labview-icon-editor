[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Image = $env:OLLAMA_IMAGE,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-preloaded",
    [int]$Port = 11435,
    [string]$Cpus = $env:OLLAMA_CPUS,
    [string]$Memory = $env:OLLAMA_MEM,
    [string]$ModelTag = $env:OLLAMA_MODEL_TAG,
    [string]$ModelBundlePath,
    [ValidateSet("setup", "package-build", "source-distribution", "local-sd-ppl", "full")]
    [string]$Mode = "setup",
    [int]$CommandTimeoutSec = 600,
    [ValidateSet("leave-running", "stop", "reset")]
    [string]$StopMode = "leave-running",
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedRepo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$insideContainer = Test-Path -LiteralPath "/.dockerenv"
# Default host to localhost unless we are running inside the devcontainer (needs host.docker.internal).
$defaultHost = if ($insideContainer) { "http://host.docker.internal:${Port}" } else { "http://localhost:${Port}" }
$resolvedHost = if ([string]::IsNullOrWhiteSpace($Endpoint)) { $defaultHost } else { $Endpoint }
$resolvedModel = if ([string]::IsNullOrWhiteSpace($ModelTag)) { "llama3-8b-local:latest" } else { $ModelTag }

Write-Host "[design-bench] Repo: $resolvedRepo"
Write-Host "[design-bench] Endpoint: $resolvedHost"
Write-Host "[design-bench] Model tag: $resolvedModel"

$pullParams = @{ Image = $Image; Owner = $Owner; Tag = $Tag }
if (-not $SkipPull) {
    Write-Host "[design-bench] Pulling image (skip with -SkipPull)"
    & "$PSScriptRoot/pull-ollama-image.ps1" @pullParams
}
else {
    Write-Host "[design-bench] Skipping image pull (requested)"
}

$runParams = @{
    Image            = $Image
    Owner            = $Owner
    Tag              = $Tag
    Port             = $Port
    Cpus             = $Cpus
    Memory           = $Memory
    ModelBundlePath  = $ModelBundlePath
    BundleTargetTag  = $resolvedModel
}
Write-Host "[design-bench] Starting container"
& "$PSScriptRoot/run-ollama-container.ps1" @runParams

$healthParams = @{ Endpoint = $resolvedHost; ModelTag = $resolvedModel; RequireModelTag = $true }
Write-Host "[design-bench] Health check"
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams

$runPackage = $Mode -in @("package-build", "full")
$runSourceDist = $Mode -in @("source-distribution", "full")
$runLocalSdPpl = $Mode -in @("local-sd-ppl", "full")

$lockedParams = @{
    RepoPath          = $resolvedRepo
    Host              = $resolvedHost
    Model             = $resolvedModel
    CommandTimeoutSec = $CommandTimeoutSec
}

if ($runPackage) {
    Write-Host "[design-bench] Running locked package-build"
    & "$PSScriptRoot/Run-Locked-PackageBuild.ps1" @lockedParams
}

if ($runSourceDist) {
    Write-Host "[design-bench] Running locked source-distribution"
    & "$PSScriptRoot/Run-Locked-SourceDistribution.ps1" @lockedParams
}

if ($runLocalSdPpl) {
    Write-Host "[design-bench] Running locked local-sd-ppl"
    & "$PSScriptRoot/Run-Locked-LocalSdPpl.ps1" @lockedParams
}

switch ($StopMode) {
    "stop" {
        Write-Host "[design-bench] Stopping container"
        & "$PSScriptRoot/stop-ollama-container.ps1"
    }
    "reset" {
        Write-Host "[design-bench] Stopping and clearing cached models"
        & "$PSScriptRoot/stop-ollama-container.ps1" -RemoveVolume
    }
    default {
        Write-Host "[design-bench] Leaving container running"
    }
}

Write-Host "[design-bench] Complete"
