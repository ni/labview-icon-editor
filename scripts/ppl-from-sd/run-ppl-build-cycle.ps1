[CmdletBinding()]
param(
    [string]$RepositoryPath = '.',
    [string]$SdRoot,
    [string]$LabVIEWVersion = '2023',
    [ValidateSet('32','64')][string]$Bitness = '64',
    [switch]$SkipMissingCheck,
    [bool]$ReplacePluginsFolder = $true,
    [switch]$DevModeForce,
    [switch]$RunUnitTestsAfterMissingCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-PathSafe {
    param([Parameter(Mandatory)][string]$Path)
    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

$repo = Resolve-PathSafe $RepositoryPath
if (-not $SdRoot) {
    $pplRoot = Join-Path $repo 'builds/ppl-from-sd'
    $latest = Get-ChildItem -Path $pplRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { throw "No extracted SD found under $pplRoot" }
    $SdRoot = $latest.FullName
}
$SdRoot = Resolve-PathSafe $SdRoot

$pfResource = "C:/Program Files/National Instruments/LabVIEW $LabVIEWVersion/resource/plugins"
$pfCacheGlob = "$env:LOCALAPPDATA/National Instruments/LabVIEW $LabVIEWVersion/*lv_icon*.lvlibp"
$backupRoot = Join-Path $SdRoot 'builds/tmp-ppl-pf-backup'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$backups = @()
$bindScript = Join-Path $SdRoot 'scripts/bind-development-mode/BindDevelopmentMode.ps1'
if (-not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    $candidate = Get-ChildItem -Path (Join-Path $SdRoot 'scripts') -Filter BindDevelopmentMode.ps1 -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $bindScript = $candidate.FullName }
}
if (-not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    throw "Dev-mode bind script not found in extracted tree (looked under $SdRoot\scripts)"
}

function Backup-And-ReplaceFile {
    param([string]$TargetPath, [string]$SourcePath)
    if (Test-Path -LiteralPath $TargetPath) {
        $dest = Join-Path $backupRoot ([IO.Path]::GetFileName($TargetPath))
        Move-Item -LiteralPath $TargetPath -Destination $dest -Force
        $script:backups += @{ target = $TargetPath; backup = $dest }
    }
    if ($SourcePath -and (Test-Path -LiteralPath $SourcePath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
    }
}

Write-Host "[ppl-cycle] Repo: $repo"
Write-Host "[ppl-cycle] SD root: $SdRoot"

# 1) Kill LabVIEW
Write-Host "[ppl-cycle] Killing LabVIEW $LabVIEWVersion ($Bitness-bit)"
& "$repo/scripts/close-labview/Close_LabVIEW.ps1" -Package_LabVIEW_Version $LabVIEWVersion -SupportedBitness $Bitness -KillLabVIEW -KillTimeoutSeconds 10 -TimeoutSeconds 30 | Out-Null

# Bind dev mode to force <resource> resolution into the SD tree
Write-Host "[ppl-cycle] Binding dev-mode to SD root ($Bitness-bit)"
$bindArgs = @('-NoProfile','-File', $bindScript, '-RepositoryPath', $SdRoot, '-Mode', 'bind', '-Bitness', $Bitness, '-LabVIEWVersion', $LabVIEWVersion)
if ($DevModeForce) { $bindArgs += '-Force' }
& pwsh @bindArgs | Write-Output

# 2) Clear cached lvlibp
Write-Host "[ppl-cycle] Clearing cached lv_icon lvlibp"
Get-ChildItem -Path $pfCacheGlob -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item "C:/Program Files/National Instruments/LabVIEW $LabVIEWVersion/resource/plugins/lv_icon.lvlibp" -Force -ErrorAction SilentlyContinue

# 3) Backup PF duplicates and replace with SD copies
$sdPlugins = Join-Path $SdRoot 'resource/plugins'
Backup-And-ReplaceFile -TargetPath (Join-Path $pfResource 'lv_icon.vi') -SourcePath (Join-Path $sdPlugins 'lv_icon.vi')
Backup-And-ReplaceFile -TargetPath (Join-Path $pfResource 'lv_IconEditor.lvlib') -SourcePath (Join-Path $sdPlugins 'lv_IconEditor.lvlib')
Backup-And-ReplaceFile -TargetPath (Join-Path $pfResource 'NIIconEditor/lv_icon.lvlibp') -SourcePath $null
if ($ReplacePluginsFolder) {
    $pfNiIconEditor = Join-Path $pfResource 'NIIconEditor'
    if (Test-Path -LiteralPath $pfNiIconEditor) {
        $dest = Join-Path $backupRoot 'NIIconEditor'
        Move-Item -LiteralPath $pfNiIconEditor -Destination $dest -Force
        $backups += @{ target = $pfNiIconEditor; backup = $dest }
    }
    if (Test-Path -LiteralPath (Join-Path $sdPlugins 'NIIconEditor')) {
        Copy-Item -LiteralPath (Join-Path $sdPlugins 'NIIconEditor') -Destination $pfResource -Recurse -Force
    }
}

try {
    # 4) Optional missing-check
    if (-not $SkipMissingCheck) {
        Write-Host "[ppl-cycle] Running missing-check"
        dotnet run --project "$repo/Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj" -- missing-check --repo "$SdRoot" --bitness $Bitness --project lv_icon_editor.lvproj --lv-version $LabVIEWVersion --timeout-sec 300
    }

    # 4.5) Optional unit tests immediately after missing-check
    if ($RunUnitTestsAfterMissingCheck) {
        $testScript = Join-Path $SdRoot 'scripts/test/Test.ps1'
        if (-not (Test-Path -LiteralPath $testScript -PathType Leaf)) {
            $candidate = Get-ChildItem -Path (Join-Path $SdRoot 'scripts') -Filter Test.ps1 -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidate) { $testScript = $candidate.FullName }
        }
        if (-not (Test-Path -LiteralPath $testScript -PathType Leaf)) {
            throw "Unit test script not found in extracted tree (looked under $SdRoot\\scripts)"
        }
        Write-Host "[ppl-cycle] Running unit tests after missing-check"
        pwsh -NoProfile -File $testScript -RepositoryPath $SdRoot -SupportedBitness $Bitness | Write-Output
    }

    # 5) Build
    Write-Host "[ppl-cycle] Running lvbuildspec"
    Set-Location $SdRoot
    & g-cli --lv-ver $LabVIEWVersion --arch $Bitness lvbuildspec -- -v 0.1.0.0 -p "$SdRoot/lv_icon_editor.lvproj" -b "Editor Packed Library"
    $buildExit = $LASTEXITCODE
}
finally {
    Set-Location $repo
    # 6) Restore PF backups
    Write-Host "[ppl-cycle] Restoring backups"
    foreach ($b in $backups) {
        Move-Item -LiteralPath $b.backup -Destination $b.target -Force
    }

    Write-Host "[ppl-cycle] Unbinding dev-mode"
    $unbindArgs = @('-NoProfile','-File', $bindScript, '-RepositoryPath', $SdRoot, '-Mode', 'unbind', '-Bitness', $Bitness, '-LabVIEWVersion', $LabVIEWVersion)
    if ($DevModeForce) { $unbindArgs += '-Force' }
    & pwsh @unbindArgs | Write-Output

    # 7) Kill LabVIEW after build
    Write-Host "[ppl-cycle] Killing LabVIEW post-build"
    & "$repo/scripts/close-labview/Close_LabVIEW.ps1" -Package_LabVIEW_Version $LabVIEWVersion -SupportedBitness $Bitness -KillLabVIEW -KillTimeoutSeconds 10 -TimeoutSeconds 30 | Out-Null
}

if ($buildExit -ne 0) {
    Write-Error "PPL build failed with exit code $buildExit"
} else {
    Write-Host "[ppl-cycle] Build succeeded."
}
