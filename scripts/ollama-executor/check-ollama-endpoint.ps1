[CmdletBinding()]
param(
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$ModelTag = $env:OLLAMA_MODEL_TAG,
    [switch]$RequireModelTag
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    $Endpoint = "http://localhost:11435"
}

$simMode = $env:OLLAMA_EXECUTOR_MODE
if (-not [string]::IsNullOrWhiteSpace($simMode) -and $simMode.Trim().ToLowerInvariant() -eq "sim") {
    $displayModel = if ([string]::IsNullOrWhiteSpace($ModelTag)) { "<unspecified>" } else { $ModelTag }
    Write-Host "Simulation mode ($simMode) detected; skipping Ollama health check for $Endpoint (model $displayModel)."
    return
}

if ($RequireModelTag -and [string]::IsNullOrWhiteSpace($ModelTag)) {
    throw "OLLAMA_MODEL_TAG is missing. Set the env var or pass -ModelTag."
}
if ([string]::IsNullOrWhiteSpace($ModelTag)) {
    $ModelTag = "llama3-8b-local:latest"
}

$uri = "$($Endpoint.TrimEnd('/'))/api/tags"
Write-Host "Checking Ollama endpoint at $uri for model '$ModelTag'"

try {
    $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10
}
catch {
    throw "Failed to reach Ollama at $uri. Ensure the container is running and OLLAMA_HOST is set. $_"
}

if (-not $response -or -not $response.models) {
    throw "Endpoint reachable but returned no models from $uri"
}

$found = $response.models | Where-Object { $_.name -eq $ModelTag }
if (-not $found) {
    $available = ($response.models.name) -join ', '
    throw "Model '$ModelTag' not found. Available: $available"
}

Write-Host "OK: Model '$ModelTag' is available at $Endpoint"
