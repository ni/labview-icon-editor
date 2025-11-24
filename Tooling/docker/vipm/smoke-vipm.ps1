param(
    [string]$RepositoryRoot = ($PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent),
    [string]$VipcPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$envPath = Join-Path -Path $RepositoryRoot -ChildPath 'Tooling/docker/vipm/.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Missing .env at $envPath. Copy .env.example and add VIPM credentials before running the smoke test."
}

$composeFile = Join-Path -Path $RepositoryRoot -ChildPath 'Tooling/docker/vipm/docker-compose.yml'
$commands = @(
    'set -e',
    'echo "== VIPM version =="',
    'vipm version',
    'echo "== Activate VIPM =="',
    'vipm vipm-activate --serial-number "$VIPM_SERIAL_NUMBER" --name "$VIPM_FULL_NAME" --email "$VIPM_EMAIL"',
    'echo "== Refresh package list =="',
    'vipm package-list-refresh',
    'echo "== Install sample package (oglib_boolean) =="',
    'vipm install oglib_boolean',
    'echo "== Installed packages =="',
    'vipm list --installed',
    'echo "== Sanity check OpenG files =="',
    'ls -al /usr/local/natinst/LabVIEW-2025-64/user.lib/_OpenG.lib || true'
)

if ($VipcPath) {
    $resolvedVipc = if ([System.IO.Path]::IsPathRooted($VipcPath)) {
        Resolve-Path -LiteralPath $VipcPath
    } else {
        Resolve-Path -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath $VipcPath)
    }
    $relativeVipc = [System.IO.Path]::GetRelativePath($RepositoryRoot, $resolvedVipc)
    $containerVipc = "/workspace/" + ($relativeVipc -replace '\\', '/')
    $commands += @(
        "echo ""== Install VIPC: $containerVipc ==""",
        "vipm install ""$containerVipc"""
    )
}

$innerScript = $commands -join ' && '
docker compose -f $composeFile build vipm-labview
docker compose -f $composeFile run --rm vipm-labview bash -lc $innerScript
