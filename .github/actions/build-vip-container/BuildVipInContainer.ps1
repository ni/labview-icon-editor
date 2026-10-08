param(
    [Parameter(Mandatory)] [int]$LabVIEWVersion,
    [Parameter(Mandatory)] [int]$Major,
    [Parameter(Mandatory)] [int]$Minor,
    [Parameter(Mandatory)] [int]$Patch,
    [Parameter(Mandatory)] [int]$Build,
    [Parameter(Mandatory)] [string]$Commit,
    [Parameter(Mandatory)] [string]$VipmInstallerUrl
)

$ErrorActionPreference = 'Stop'
$repoRoot = 'C:\workspace'
$builds = Join-Path $repoRoot 'builds'
$labviewPath = "C:\Program Files\National Instruments\LabVIEW $LabVIEWVersion\LabVIEW.exe"
$buildSpecScript = 'C:\actions\scripts\build-spec-docker-windows\build-spec.ps1'
$vipm = 'C:\Program Files\JKI\VI Package Manager\support\vipm.exe'

if (-not (Test-Path -LiteralPath $labviewPath)) {
    throw "LabVIEW $LabVIEWVersion is missing from the container image at $labviewPath."
}
if (-not (Test-Path -LiteralPath $buildSpecScript)) {
    throw "NI Windows Docker build script not found at $buildSpecScript."
}

if (-not (Test-Path -LiteralPath $vipm)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installer = Join-Path $env:TEMP 'vipm-setup.exe'
    Invoke-WebRequest -Uri $VipmInstallerUrl -OutFile $installer -UseBasicParsing
    $process = Start-Process -FilePath $installer -ArgumentList '/quiet', '/norestart' -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "VIPM installer failed with exit code $($process.ExitCode)." }
}
if (-not (Test-Path -LiteralPath $vipm)) {
    throw "vipm.exe not found at $vipm after installation."
}

$vipmSettings = Join-Path $env:ProgramData 'JKI\VIPM\Settings.ini'
if (-not (Test-Path -LiteralPath $vipmSettings)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $vipmSettings) -Force | Out-Null
    New-Item -ItemType File -Path $vipmSettings -Force | Out-Null
}

$refreshed = $false
foreach ($attempt in 1..3) {
    & $vipm package-list-refresh
    if ($LASTEXITCODE -eq 0) { $refreshed = $true; break }
    Write-Warning "vipm package-list-refresh attempt $attempt failed ($LASTEXITCODE)."
    Start-Sleep -Seconds (15 * $attempt)
}
if (-not $refreshed) { throw 'vipm package-list-refresh failed after 3 attempts.' }
Start-Sleep -Seconds 30

# The runner VIPC targets LabVIEW 20.0 and includes unrelated test/runner packages.
foreach ($package in @('wiresmith_technology_lib_g_cli', 'sas_workshops_lib_vipb_builder_for_g_cli')) {
    & $vipm install $package --labview-version $LabVIEWVersion --labview-bitness 64
    if ($LASTEXITCODE -ne 0) { throw "vipm install $package failed ($LASTEXITCODE)." }
}

$gcli = (Get-Command g-cli -ErrorAction SilentlyContinue).Source
if (-not $gcli) {
    $gcli = @("$env:ProgramFiles\G-CLI\g-cli.exe", "${env:ProgramFiles(x86)}\G-CLI\g-cli.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $gcli) {
    throw 'g-cli.exe was not found after installing the G-CLI and VIPB Builder VIPM packages.'
}
$env:PATH = "$(Split-Path -Parent $gcli);$env:PATH"
& $gcli --version
if ($LASTEXITCODE -ne 0) { throw 'g-cli failed its version check.' }

$buildSpecArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $buildSpecScript,
    '-LabVIEWPath', $labviewPath,
    '-ProjectPath', (Join-Path $repoRoot 'lv_icon_editor.lvproj'),
    '-TargetName', 'My Computer',
    '-BuildSpecName', 'Editor Packed Library',
    '-Version', "$Major.$Minor.$Patch.$Build"
)
& powershell.exe @buildSpecArgs
if ($LASTEXITCODE -ne 0) { throw "x64 PPL build failed ($LASTEXITCODE)." }

$pplPath = Join-Path $builds 'lv_icon.lvlibp'
if (-not (Test-Path -LiteralPath $pplPath)) { throw "Expected PPL not found at $pplPath." }
Rename-Item -LiteralPath $pplPath -NewName 'lv_icon_x64.lvlibp'

foreach ($item in Get-ChildItem -LiteralPath $builds -Force) {
    if ($item.Name -ne 'lv_icon_x64.lvlibp') {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }
}

$vipbPath = Join-Path $repoRoot 'Tooling/deployment/NI Icon editor.vipb'
[xml]$vipb = Get-Content -LiteralPath $vipbPath -Raw
$vipcNode = $vipb.VI_Package_Builder_Settings.Advanced_Settings.SelectSingleNode('VI_Package_Configuration_File')
if ($vipcNode -and -not [string]::IsNullOrWhiteSpace($vipcNode.InnerText)) {
    $vipcPath = Join-Path (Split-Path -Parent $vipbPath) $vipcNode.InnerText
    if (-not (Test-Path -LiteralPath $vipcPath)) {
        $vipcNode.InnerText = ''
        $vipb.Save($vipbPath)
    }
}

$buildVipScript = Join-Path $repoRoot '.github/actions/build-vip/build_vip.ps1'
$buildVipArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $buildVipScript,
    '-SkipPreflight',
    '-SupportedBitness', '64',
    '-RepoRoot', $repoRoot,
    '-VIPBPath', 'Tooling/deployment/NI Icon editor.vipb',
    '-LabVIEWVersion', $LabVIEWVersion.ToString(),
    '-LabVIEWMinorRevision', '0',
    '-Major', $Major.ToString(),
    '-Minor', $Minor.ToString(),
    '-Patch', $Patch.ToString(),
    '-Build', $Build.ToString(),
    '-Commit', $Commit,
    '-ReleaseNotesFile', (Join-Path $repoRoot 'Tooling/deployment/release_notes.md'),
    '-DisplayInformationJsonPath', 'C:\vipb-display-info.json',
    '-VipmTimeoutSeconds', '900'
)
& powershell.exe @buildVipArgs
if ($LASTEXITCODE -ne 0) { throw "VI Package build failed ($LASTEXITCODE)." }