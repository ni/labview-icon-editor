[CmdletBinding()]
param(
    [string]$Ref = "main",
    [string]$TagSuffix = "cpu-latest",
    [Parameter(Mandatory = $true)]
    [string]$BundleUrl,
    [Parameter(Mandatory = $true)]
    [string]$BundleSha256
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required to dispatch the workflow."
}

if ([string]::IsNullOrWhiteSpace($BundleUrl)) {
    throw "BundleUrl is required."
}
if ([string]::IsNullOrWhiteSpace($BundleSha256)) {
    throw "BundleSha256 is required."
}

$workflow = ".github/workflows/ollama-image.yml"

$args = @(
    "workflow", "run", $workflow,
    "--ref", $Ref,
    "-f", "ref=$Ref",
    "-f", "tag=$TagSuffix",
    "-f", "bundle_url=$BundleUrl",
    "-f", "bundle_sha256=$BundleSha256"
)

Write-Host "Dispatching $workflow with tag=$TagSuffix and bundle_url=$BundleUrl"
gh @args
