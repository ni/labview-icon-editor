[CmdletBinding()]
param(
    [switch]$RemoveVolume,
    [string]$VolumeName = "ollama"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot/ollama-common.ps1"
Assert-DockerReady -Purpose "Ollama container stop"

$existing = docker ps -aq -f name=^ollama-local$
if ($existing) {
    Write-Host "Stopping and removing ollama-local"
    docker rm -f $existing | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "docker rm failed with exit code $LASTEXITCODE while stopping ollama-local"
    }
    Write-Host "Removed ollama-local"
}
else {
    Write-Host "No ollama-local container running"
}

if ($RemoveVolume) {
    $volumeMatch = docker volume ls -q -f name=^$VolumeName$
    if ($volumeMatch) {
        Write-Host "Removing volume $VolumeName"
        docker volume rm -f $VolumeName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "docker volume rm failed with exit code $LASTEXITCODE for $VolumeName"
        }
        Write-Host "Removed volume $VolumeName"
    }
    else {
        Write-Host "Volume $VolumeName not found; nothing to remove"
    }
}
