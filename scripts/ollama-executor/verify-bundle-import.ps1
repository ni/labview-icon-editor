[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Full path to the .ollama model bundle (e.g., C:\\path\\llama3-8b-local.ollama)")]
    [string]$BundlePath,
    [string]$Host = "http://localhost:11435",
    [string]$ModelTag = "llama3-8b-local",
    [string]$Image = $env:OLLAMA_IMAGE,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest",
    [int]$Port = 11435,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot/ollama-common.ps1"
Assert-DockerReady -Purpose "verify bundle import"

if (-not (Test-Path -LiteralPath $BundlePath)) {
    throw "BundlePath not found: $BundlePath. Provide the full path to your .ollama bundle (e.g., C:\path\llama3-8b-local.ollama)."
}
$bundleResolved = (Resolve-Path -LiteralPath $BundlePath).Path

Write-Host "Starting ollama-local with bundle $bundleResolved on port $Port"
$args = @{
    Image             = $Image
    Owner             = $Owner
    Tag               = $Tag
    Port              = $Port
    ModelBundlePath   = $bundleResolved
    BundleTargetTag   = $ModelTag
}

& "$PSScriptRoot/run-ollama-container.ps1" @args

$defaultHost = "http://localhost:$Port"
$resolvedHost = if (-not $PSBoundParameters.ContainsKey('Host') -or [string]::IsNullOrWhiteSpace($Host)) { $defaultHost } else { $Host }
Write-Host "Running health check at $resolvedHost for model $ModelTag"
& "$PSScriptRoot/check-ollama-endpoint.ps1" -Endpoint $resolvedHost -ModelTag $ModelTag -RequireModelTag

if (-not $SkipCleanup) {
    Write-Host "Stopping test container"
    & "$PSScriptRoot/stop-ollama-container.ps1"
}

Write-Host "Bundle import verification completed successfully."
