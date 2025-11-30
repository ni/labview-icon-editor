[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [ValidateSet('both','64','32')]
    [string]$SupportedBitness = 'both',

    [string]$VipcPath = 'runner_dependencies.vipc',
    [string]$PackageLabVIEWVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$global:LASTEXITCODE = 0

Write-Warning "Deprecated: prefer 'dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- apply-deps --repo <path> --bitness both --vipc-path runner_dependencies.vipc'; this script remains as a delegate."
Write-Information "[legacy-ps] apply-deps delegate invoked" -InformationAction Continue

if (-not $IsWindows) {
    Write-Error "Dependency application requires Windows with VIPM CLI; run from a Windows host."
    exit 1
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$applyScript = Join-Path $repoRoot 'scripts/apply-vipc/ApplyVIPC.ps1'
if (-not (Test-Path -LiteralPath $applyScript)) {
    throw "ApplyVIPC.ps1 not found at $applyScript"
}

if (-not (Get-Command vipm -ErrorAction SilentlyContinue)) {
    throw "vipm CLI not found on PATH. Install VIPM CLI or expose it to PATH before applying dependencies."
}

if (-not $PackageLabVIEWVersion) {
    $lvScript = Join-Path $repoRoot 'scripts/get-package-lv-version.ps1'
    if (-not (Test-Path -LiteralPath $lvScript)) {
        throw "get-package-lv-version.ps1 not found at $lvScript"
    }
    $PackageLabVIEWVersion = & $lvScript -RepositoryPath $repoRoot
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($PackageLabVIEWVersion)) {
        throw "Failed to resolve LabVIEW version from VIPB."
    }
}

if ([System.IO.Path]::IsPathRooted($VipcPath)) {
    $vipcResolved = $VipcPath
}
else {
    $vipcResolved = Join-Path $repoRoot $VipcPath
}

if (-not (Test-Path -LiteralPath $vipcResolved -PathType Leaf)) {
    throw "VIPC file not found at $vipcResolved"
}

function Invoke-ApplyDependencies {
    param([Parameter(Mandatory)][ValidateSet('32','64')][string]$Bitness)

    Write-Host ("---- {0}-bit: apply dependencies ----" -f $Bitness)
    & $applyScript -Package_LabVIEW_Version $PackageLabVIEWVersion -SupportedBitness $Bitness -RepositoryPath $repoRoot -VIPCPath $vipcResolved
    if ($LASTEXITCODE -ne 0) {
        throw ("ApplyVIPC failed for {0}-bit (exit code {1})" -f $Bitness, $LASTEXITCODE)
    }
}

if ($SupportedBitness -eq 'both') {
    Invoke-ApplyDependencies -Bitness '32'
    Invoke-ApplyDependencies -Bitness '64'
}
else {
    Invoke-ApplyDependencies -Bitness $SupportedBitness
}

Write-Host ("Dependencies verified/applied for {0} using {1}" -f $SupportedBitness, $vipcResolved)
