param(
    [string]$RepositoryRoot = ($PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$envPath = Join-Path -Path $RepositoryRoot -ChildPath 'Tooling/docker/vipm/.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Host "Creating empty $envPath for VIPM Docker task (populate with credentials for full use)."
    New-Item -ItemType File -Path $envPath -Force | Out-Null
}

$composeFile = Join-Path -Path $RepositoryRoot -ChildPath 'Tooling/docker/vipm/docker-compose.yml'
docker compose -f $composeFile build vipm-labview
docker compose -f $composeFile run --rm vipm-labview vipm help
