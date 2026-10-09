param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(2000, 2100)]
    [int]$LabVIEWVersion,

    [Parameter(Mandatory = $true)]
    [int]$Major,

    [Parameter(Mandatory = $true)]
    [int]$Minor,

    [Parameter(Mandatory = $true)]
    [int]$Patch,

    [Parameter(Mandatory = $true)]
    [int]$Build,

    [Parameter(Mandatory = $true)]
    [string]$Commit,

    [Parameter(Mandatory = $true)]
    [string]$DisplayInformationJsonPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = 'C:\workspace'
$pplPath = Join-Path $repoRoot 'builds\lv_icon_x64.lvlibp'
$vipmPath = Join-Path $env:ProgramFiles 'JKI\VI Package Manager\support\vipm.exe'

if (-not (Test-Path -LiteralPath $pplPath)) {
    throw "The downloaded x64 PPL is missing at $pplPath."
}
if (-not (Test-Path -LiteralPath $vipmPath)) {
    if ([string]::IsNullOrWhiteSpace($env:VIPM_INSTALLER_URL)) {
        throw 'VIPM_INSTALLER_URL is not set.'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installer = Join-Path $env:TEMP 'vipm-setup.exe'
    Invoke-WebRequest -Uri $env:VIPM_INSTALLER_URL -OutFile $installer -UseBasicParsing
    $process = Start-Process -FilePath $installer -ArgumentList '/quiet', '/norestart' -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "VIPM installer failed with exit code $($process.ExitCode)."
    }
}
if (-not (Test-Path -LiteralPath $vipmPath)) {
    throw "vipm.exe not found at $vipmPath after installation."
}

$vipmSettings = Join-Path $env:ProgramData 'JKI\VIPM\Settings.ini'
if (-not (Test-Path -LiteralPath $vipmSettings)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $vipmSettings) -Force | Out-Null
    New-Item -ItemType File -Path $vipmSettings -Force | Out-Null
}

$refreshed = $false
foreach ($attempt in 1..3) {
    & $vipmPath package-list-refresh
    if ($LASTEXITCODE -eq 0) {
        $refreshed = $true
        break
    }
    Write-Warning "VIPM package-list-refresh attempt $attempt failed ($LASTEXITCODE)."
    Start-Sleep -Seconds (15 * $attempt)
}
if (-not $refreshed) {
    throw 'vipm package-list-refresh failed after 3 attempts.'
}
Start-Sleep -Seconds 30

foreach ($package in @('wiresmith_technology_lib_g_cli', 'sas_workshops_lib_vipb_builder_for_g_cli')) {
    & $vipmPath install $package --labview-version $LabVIEWVersion --labview-bitness 64
    if ($LASTEXITCODE -ne 0) {
        throw "vipm install $package failed ($LASTEXITCODE)."
    }
}

$gcli = (Get-Command g-cli -ErrorAction SilentlyContinue).Source
if (-not $gcli) {
    $gcli = @(
        (Join-Path $env:ProgramFiles 'G-CLI\g-cli.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'G-CLI\g-cli.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $gcli) {
    throw 'g-cli.exe was not found after installing the G-CLI VIPM package.'
}
$env:Path = "$(Split-Path -Parent $gcli);$env:Path"

$buildVipScript = Join-Path $repoRoot '.github\actions\build-vip\build_vip.ps1'
$releaseNotes = Join-Path $repoRoot 'Tooling\deployment\release_notes.md'
$vipbPath = 'NI Icon editor.ci.vipb'
foreach ($path in @($buildVipScript, $releaseNotes, (Join-Path $repoRoot $vipbPath), $DisplayInformationJsonPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required VIP build input is missing: $path"
    }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildVipScript `
    -SkipPreflight `
    -SupportedBitness 64 `
    -RepoRoot $repoRoot `
    -VIPBPath $vipbPath `
    -LabVIEWVersion $LabVIEWVersion `
    -LabVIEWMinorRevision 0 `
    -Major $Major `
    -Minor $Minor `
    -Patch $Patch `
    -Build $Build `
    -Commit $Commit `
    -ReleaseNotesFile $releaseNotes `
    -DisplayInformationJsonPath $DisplayInformationJsonPath `
    -VipmTimeoutSeconds 900
if ($LASTEXITCODE -ne 0) {
    throw "build_vip.ps1 failed with exit code $LASTEXITCODE."
}