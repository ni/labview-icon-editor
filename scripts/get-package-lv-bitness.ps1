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

$raw = [string]$generalSettings.Package_LabVIEW_Version

# Prefer explicit bitness suffix in Package_LabVIEW_Version, e.g., "25.3 (64-bit)".
$bitMatch = [regex]::Match($raw, '(?i)\((?<bitness>32|64)-bit\)')
if ($bitMatch.Success) {
    Write-Output $bitMatch.Groups['bitness'].Value
    return
}

# If no explicit bitness is encoded, VIPM defaults to 32-bit packaging. Do not infer from Install_Requirements
# (those flags express compatibility, not the VIPM build bitness).
Write-Output '32'
