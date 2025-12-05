[CmdletBinding()]
param(
    [string]$Image = $env:OLLAMA_IMAGE,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest",
    [int]$Port = 11435,
    [string]$Cpus = $env:OLLAMA_CPUS,
    [string]$Memory = $env:OLLAMA_MEM,
    [string]$ModelBundlePath,
    [string]$BundleImportTag = "llama3-8b-local",
    [string]$BundleTargetTag = $env:OLLAMA_MODEL_TAG
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot/ollama-common.ps1"

if ([string]::IsNullOrWhiteSpace($Image)) {
    if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = "svelderrainruiz" }
    if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "cpu-latest" }
    $ref = "ghcr.io/$($Owner.Trim().ToLowerInvariant())/ollama-local:$($Tag.Trim())"
}
else {
    $ref = $Image.Trim()
}

if (-not $ref) { throw "Image reference is empty; specify Image or Owner/Tag." }

$runArgs = @("run", "-d", "--name", "ollama-local", "-p", "${Port}:${Port}", "-e", "OLLAMA_HOST=0.0.0.0:${Port}", "-v", "ollama:/root/.ollama")
if (-not [string]::IsNullOrWhiteSpace($Cpus)) {
    $runArgs += @("--cpus", $Cpus)
}
if (-not [string]::IsNullOrWhiteSpace($Memory)) {
    $runArgs += @("--memory", $Memory)
}
if (-not [string]::IsNullOrWhiteSpace($Cpus) -or -not [string]::IsNullOrWhiteSpace($Memory)) {
    Write-Host ("Resource limits -> CPUs: {0}; Memory: {1}" -f ($Cpus ?? "<unset>"), ($Memory ?? "<unset>"))
}

Assert-DockerReady -Purpose "Ollama container start"

$existing = docker ps -aq -f name=^ollama-local$
if ($existing) {
    Write-Host "Removing existing ollama-local container"
    docker rm -f $existing | Out-Null
}

Write-Host "Starting $ref on localhost:$Port"
& docker @runArgs $ref serve
if ($LASTEXITCODE -ne 0) {
    throw "docker run failed with exit code $LASTEXITCODE for $ref"
}

if (-not [string]::IsNullOrWhiteSpace($ModelBundlePath)) {
    if (-not (Test-Path -LiteralPath $ModelBundlePath)) {
        throw "Model bundle not found at '$ModelBundlePath'"
    }

    $targetTag = if ([string]::IsNullOrWhiteSpace($BundleTargetTag)) { $BundleImportTag } else { $BundleTargetTag }
    $bundleName = Split-Path -Leaf $ModelBundlePath
    $tmpDir = "/tmp/ollama-import"
    $containerBundle = "$tmpDir/$bundleName"

    Write-Host "Importing bundle $bundleName into container (import tag: $BundleImportTag; target tag: $targetTag)"
    docker exec ollama-local mkdir -p $tmpDir | Out-Null
    docker cp $ModelBundlePath "ollama-local:$containerBundle" | Out-Null
    docker exec ollama-local ollama import $containerBundle | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "ollama import failed with exit code $LASTEXITCODE for $containerBundle"
    }

    if ($targetTag -ne $BundleImportTag) {
        docker exec ollama-local ollama cp $BundleImportTag $targetTag | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "ollama cp failed while retagging $BundleImportTag -> $targetTag"
        }
    }

    docker exec ollama-local ollama list
}
