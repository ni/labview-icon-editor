param(
    [string]$RepositoryPath,
    [ValidateSet('32','64')]
    [string]$SupportedBitness
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $RepositoryPath) {
    $repo = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $repo) { $repo = (Get-Location).ProviderPath }
    $RepositoryPath = $repo
}

if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
    throw "RepositoryPath is empty"
}

# Gate: require g-cli on PATH
$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli) {
    throw "g-cli is not available on PATH; install g-cli before running dev-mode tasks."
}

# Quick sanity check: g-cli --help (fail fast if g-cli is broken)
Write-Information "g-cli detected at $($gcli.Source); running g-cli --help for sanity..." -InformationAction Continue
& g-cli --help > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "g-cli --help failed with exit code $LASTEXITCODE; ensure g-cli is installed correctly."
}

$invokeArgs = @{
    RepositoryPath = $RepositoryPath
}
if ($PSBoundParameters.ContainsKey('SupportedBitness')) {
    $invokeArgs.SupportedBitness = $SupportedBitness
}

& (Join-Path $PSScriptRoot 'RevertDevelopmentMode.ps1') @invokeArgs
