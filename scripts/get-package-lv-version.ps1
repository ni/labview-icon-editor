param(
    [Parameter(Mandatory)][string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path

# Prefer the canonical VIPB under Tooling/deployment to avoid picking up temp/worktree copies.
$preferredVipb = Join-Path $RepositoryPath 'Tooling/deployment/seed.vipb'
if (Test-Path -LiteralPath $preferredVipb) {
    $vipb = Get-Item -LiteralPath $preferredVipb
}
else {
    $vipb = Get-ChildItem -Path $RepositoryPath -Filter *.vipb -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\\.tmp-tests\\' -and
            $_.FullName -notmatch '\\builds(-isolated(-tests)?)?\\' -and
            $_.FullName -notmatch '\\temp_telemetry\\' -and
            $_.FullName -notmatch '\\artifacts\\'
        } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1
}
if (-not $vipb) { throw "No .vipb file found under $RepositoryPath" }

try {
    [xml]$vipbXml = Get-Content -LiteralPath $vipb.FullName -Raw
}
catch {
    throw ("Failed to parse VIPB XML at {0}: {1}" -f $vipb.FullName, $_.Exception.Message)
}

$settings = $vipbXml.VI_Package_Builder_Settings
if (-not $settings) { throw ("VIPB is missing VI_Package_Builder_Settings: {0}" -f $vipb.FullName) }

$generalSettings = $settings.Library_General_Settings
if (-not $generalSettings) { throw ("VIPB is missing Library_General_Settings: {0}" -f $vipb.FullName) }

$raw = [string]$generalSettings.Package_LabVIEW_Version
if ([string]::IsNullOrWhiteSpace($raw)) { throw "Package_LabVIEW_Version not found in $($vipb.FullName)" }

$verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
if (-not $verMatch.Success) { throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)" }
$maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
$lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
Write-Output $lvVersion
