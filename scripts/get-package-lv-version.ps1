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

$settings = $vipbXml.SelectSingleNode('/VI_Package_Builder_Settings')
if (-not $settings) {
    $settings = $vipbXml.SelectSingleNode('/Package')
}
if (-not $settings) {
    $rootName = $vipbXml.DocumentElement.Name
    throw ("VIPB is missing VI_Package_Builder_Settings/Package root (found '{0}'): {1}" -f $rootName, $vipb.FullName)
}

$generalSettings = $settings.SelectSingleNode('Library_General_Settings')
if (-not $generalSettings) { throw ("VIPB is missing Library_General_Settings: {0}" -f $vipb.FullName) }

$raw = ([string]$generalSettings.Package_LabVIEW_Version).Trim()
if ([string]::IsNullOrWhiteSpace($raw)) { throw "Package_LabVIEW_Version not found in $($vipb.FullName)" }

if ($raw -notmatch '(?i)labview') {
    throw "Package_LabVIEW_Version must reference 'LabVIEW' or 'LabVIEW>=' (found '$raw' in $($vipb.FullName))."
}

$pattern = '(?i)LabVIEW\s*(?:>=\s*)?(?<ver>\d{2,4}(?:\.\d+)?)'
$match = [regex]::Match($raw, $pattern)
if (-not $match.Success) {
    throw "Package_LabVIEW_Version must specify a numeric LabVIEW version after the label (found '$raw' in $($vipb.FullName))."
}

$verToken = $match.Groups['ver'].Value
$parts = $verToken.Split('.')
$maj = [int]$parts[0]
if ($maj -lt 100) { $maj += 2000 }
if ($maj -lt 2009 -or $maj -gt 2100) {
    throw "Parsed LabVIEW major version '$maj' is outside the supported range (2009-2100)."
}

Write-Output ($maj.ToString())
