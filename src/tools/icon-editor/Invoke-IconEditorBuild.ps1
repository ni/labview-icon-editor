Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
#Requires -Version 7.0

param(
  [string]$IconEditorRoot,
  [int]$Major = 0,
  [int]$Minor = 0,
  [int]$Patch = 0,
  [int]$Build = 0,
  [string]$Commit,
  [string]$CompanyName = 'LabVIEW Community CI/CD',
  [string]$AuthorName = 'LabVIEW Community CI/CD',
  [string]$MinimumSupportedLVVersion = '2023',
  [int]$LabVIEWMinorRevision = 3,
  [bool]$InstallDependencies = $true,
  [switch]$SkipPackaging,
  [switch]$RequirePackaging,
  [switch]$RunUnitTests,
  [switch]$SkipMissingInProject,
  [string]$ResultsRoot,
  [ValidateSet('g-cli','vipm')]
  [string]$BuildToolchain = 'g-cli',
  [string]$BuildProvider,
  [string]$PackageMinimumSupportedLVVersion = '2026',
  [int]$PackageLabVIEWMinorRevision = 0,
  [ValidateSet(32,64)][int]$PackageSupportedBitness = 64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try { return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim() } catch { return $StartPath }
}

$repoRoot = Resolve-RepoRoot
Import-Module (Join-Path $repoRoot 'tools' 'VendorTools.psm1') -Force
Import-Module (Join-Path $repoRoot 'tools' 'vendor' 'PackedLibraryBuild.psm1') -Force
Import-Module (Join-Path $repoRoot 'tools' 'vendor' 'IconEditorPackaging.psm1') -Force
Import-Module (Join-Path $repoRoot 'tools' 'icon-editor' 'IconEditorDevMode.psm1') -Force
Import-Module (Join-Path $repoRoot 'tools' 'icon-editor' 'VipmBuildHelpers.psm1') -Force

if (-not $IconEditorRoot) {
  $IconEditorRoot = Join-Path $repoRoot 'vendor' 'icon-editor'
}

if (-not (Test-Path -LiteralPath $IconEditorRoot -PathType Container)) {
  throw "Icon editor root not found at '$IconEditorRoot'. Vendor the labview-icon-editor repository first."
}

if (-not $ResultsRoot) {
  $ResultsRoot = Join-Path $repoRoot 'tests' 'results' '_agent' 'icon-editor'
}

$ResultsRoot = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $ResultsRoot -Force)).Path
$vipmBuildTelemetryRoot = Initialize-VipmBuildTelemetry -RepoRoot $repoRoot

$gCliPath = Resolve-GCliPath
if (-not $gCliPath) {
  throw "Unable to locate g-cli.exe. Update configs/labview-paths.local.json or set GCLI_EXE_PATH so the automation can find g-cli."
}

$gCliDirectory = Split-Path -Parent $gCliPath
$previousPath = $env:Path
$requiredLabVIEW = @(
  @{ Version = [int]$MinimumSupportedLVVersion; Bitness = 32 },
  @{ Version = [int]$MinimumSupportedLVVersion; Bitness = 64 }
)
if ([int]$PackageMinimumSupportedLVVersion -ne [int]$MinimumSupportedLVVersion -or $PackageSupportedBitness -notin @(32,64)) {
  $requiredLabVIEW += @{ Version = [int]$PackageMinimumSupportedLVVersion; Bitness = $PackageSupportedBitness }
}
$requiredLabVIEW = $requiredLabVIEW | Sort-Object Version, Bitness -Unique
$missingLabVIEW = @()
foreach ($requirement in $requiredLabVIEW) {
  $requiredPath = Find-LabVIEWVersionExePath -Version $requirement.Version -Bitness $requirement.Bitness
  if (-not $requiredPath) {
    $missingLabVIEW += $requirement
  }
}
if ($missingLabVIEW.Count -gt 0) {
  $missingText = ($missingLabVIEW | ForEach-Object { "LabVIEW {0} ({1}-bit)" -f $_.Version, $_.Bitness }) -join ', '
  throw ("Required LabVIEW installations not found: {0}. Install the missing versions or set `versions.<version>.<bitness>.LabVIEWExePath` in configs/labview-paths.local.json." -f $missingText)
}
$devModeWasToggled = $false
$devModeActive = $false
$devModeToggleTargets = New-Object System.Collections.Generic.List[object]

function Add-DevModeTarget {
  param(
    [int]$Version,
    [int[]]$Bitness
  )

  $existing = $null
  foreach ($entry in $devModeToggleTargets) {
    if ($entry.Version -eq $Version) {
      $existing = $entry
      break
    }
  }

  $bitnessList = ($Bitness | Sort-Object -Unique)

  if ($existing) {
    $existing.Bitness = (@($existing.Bitness) + $bitnessList) | Sort-Object -Unique
  } else {
    $devModeToggleTargets.Add([pscustomobject]@{
      Version = $Version
      Bitness = $bitnessList
    }) | Out-Null
  }
}

$logsRoot = Join-Path $repoRoot 'tests' 'results' '_agent' 'icon-editor' 'logs'
function Get-LatestIconEditorLog {
  param()
  if (-not (Test-Path -LiteralPath $logsRoot -PathType Container)) { return $null }
  return Get-ChildItem -LiteralPath $logsRoot -Filter '*.log' | Sort-Object LastWriteTime | Select-Object -Last 1
}

function Capture-IconEditorMissingItems {
  param(
    [string]$ResultsRootPath,
    [string]$ProjectRoot
  )

  $inspectScript = Join-Path $repoRoot 'tools' 'icon-editor' 'Inspect-MissingProjectItems.ps1'
  if (-not (Test-Path -LiteralPath $inspectScript -PathType Leaf)) {
    return $null
  }

  $missingPath = Join-Path $ResultsRootPath 'missing-items.json'
  try {
    & $inspectScript -ProjectPath (Join-Path $ProjectRoot 'lv_icon_editor.lvproj') -OutputPath $missingPath | Out-Null
    return $missingPath
  } catch {
    Write-Warning ("Failed to capture missing project items: {0}" -f $_.Exception.Message)
    return $null
  }
}

try {
  if ($previousPath -notlike "$gCliDirectory*") {
    $env:Path = "$gCliDirectory;$previousPath"
  }

  if (-not $Commit) {
    try {
      $Commit = (git -C $repoRoot rev-parse --short HEAD).Trim()
    } catch {
      $Commit = 'vendored'
    }
  }

  $actionsRoot = Join-Path $IconEditorRoot '.github' 'actions'

  $unitTestScript     = Join-Path $actionsRoot 'run-unit-tests' 'RunUnitTests.ps1'
  $unitReadyHelper    = if ($env:ICON_EDITOR_UNIT_READY_HELPER) { $env:ICON_EDITOR_UNIT_READY_HELPER } else { Join-Path $repoRoot 'tools' 'icon-editor' 'Prepare-UnitTestState.ps1' }
  $buildLvlibpScript  = Join-Path $actionsRoot 'build-lvlibp' 'Build_lvlibp.ps1'
  $closeLabviewScript = Join-Path $actionsRoot 'close-labview' 'Close_LabVIEW.ps1'
  $renameScript       = Join-Path $actionsRoot 'rename-file' 'Rename-file.ps1'
  $modifyVipbScript   = Join-Path $repoRoot '.github' 'actions' 'modify-vipb-display-info' 'Update-VipbDisplayInfo.ps1'
  if ($env:ICON_EDITOR_UPDATE_VIPB_HELPER) {
    $overrideScript = $env:ICON_EDITOR_UPDATE_VIPB_HELPER
    if (Test-Path -LiteralPath $overrideScript -PathType Leaf) {
      $modifyVipbScript = (Resolve-Path -LiteralPath $overrideScript).ProviderPath
    }
  }
  $buildVipScript     = Join-Path $actionsRoot 'build-vi-package' 'build_vip.ps1'
  $packageSmokeScript = Join-Path $repoRoot 'tools' 'icon-editor' 'Test-IconEditorPackage.ps1'
  $missingInProjectScript = Join-Path $actionsRoot 'missing-in-project' 'Invoke-MissingInProjectCLI.ps1'

  foreach ($required in @($buildLvlibpScript, $closeLabviewScript, $renameScript, $modifyVipbScript, $buildVipScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Expected script '$required' was not found."
    }
  }

  function Invoke-IconEditorAction {
    param(
      [string]$ScriptPath,
      [string[]]$Arguments
    )

    Invoke-IconEditorDevModeScript -ScriptPath $ScriptPath -ArgumentList $Arguments -RepoRoot $repoRoot -IconEditorRoot $IconEditorRoot
  }

  function Invoke-MissingInProjectCheck {
    param(
      [string[]]$BitnessTargets
    )

    if ($SkipMissingInProject) {
      Write-Host 'Skipping missing-in-project check.' -ForegroundColor Yellow
      return
    }

    if (-not (Test-Path -LiteralPath $missingInProjectScript -PathType Leaf)) {
      throw "Invoke-MissingInProjectCLI.ps1 not found at '$missingInProjectScript'."
    }

    $projectFile = Join-Path $IconEditorRoot 'lv_icon_editor.lvproj'
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
      throw "Icon editor project not found at '$projectFile'."
    }

    $bitnessList = if ($BitnessTargets -and $BitnessTargets.Count -gt 0) { $BitnessTargets } else { @('32','64') }
    $bitnessList = $bitnessList | ForEach-Object { $_.ToString() } | Sort-Object -Unique

    $missingResultsRoot = Join-Path $repoRoot 'tests' 'results' '_agent' 'missing-in-project'
    $previousRepoRoot = $env:MIP_REPO_ROOT
    $previousResultsRoot = $env:MIP_RESULTS_ROOT

    try {
      $env:MIP_REPO_ROOT = $repoRoot
      $env:MIP_RESULTS_ROOT = $missingResultsRoot

      foreach ($arch in $bitnessList) {
        Write-Host ("Running MissingInProject check for LabVIEW {0} ({1}-bit)..." -f $MinimumSupportedLVVersion, $arch) -ForegroundColor Cyan
        $arguments = @(
          '-LVVersion', "$MinimumSupportedLVVersion",
          '-Arch', $arch,
          '-ProjectFile', $projectFile
        )
        Invoke-IconEditorAction -ScriptPath $missingInProjectScript -Arguments $arguments
      }
    } finally {
      if ($null -ne $previousRepoRoot) {
        $env:MIP_REPO_ROOT = $previousRepoRoot
      } else {
        Remove-Item Env:MIP_REPO_ROOT -ErrorAction SilentlyContinue
      }
      if ($null -ne $previousResultsRoot) {
        $env:MIP_RESULTS_ROOT = $previousResultsRoot
      } else {
        Remove-Item Env:MIP_RESULTS_ROOT -ErrorAction SilentlyContinue
      }
    }
  }

  if ($SkipPackaging.IsPresent -and $RequirePackaging.IsPresent) {
    throw 'Specify either -SkipPackaging or -RequirePackaging, not both.'
  }

  $packagingRequested = -not $SkipPackaging.IsPresent
  if ($RequirePackaging.IsPresent) {
    $packagingRequested = $true
  }

  $buildStart = Get-Date

  $previousDevState = Get-IconEditorDevModeState -RepoRoot $repoRoot
  $devModeWasToggled = $false
  $devModeActive = $false
  if ($InstallDependencies -and (-not $previousDevState.Active)) {
    Write-Host 'Enabling icon editor development mode...' -ForegroundColor Cyan

    $packedLibBitnessTargets = @(32, 64)
    Enable-IconEditorDevelopmentMode `
      -RepoRoot $repoRoot `
      -IconEditorRoot $IconEditorRoot `
      -Operation 'BuildPackage' `
      -Versions @([int]$MinimumSupportedLVVersion) `
      -Bitness $packedLibBitnessTargets | Out-Null
    Add-DevModeTarget -Version ([int]$MinimumSupportedLVVersion) -Bitness $packedLibBitnessTargets

    if ([int]$PackageMinimumSupportedLVVersion -ne [int]$MinimumSupportedLVVersion -or $PackageSupportedBitness -notin $packedLibBitnessTargets) {
      Enable-IconEditorDevelopmentMode `
        -RepoRoot $repoRoot `
        -IconEditorRoot $IconEditorRoot `
        -Operation 'BuildPackage' `
        -Versions @([int]$PackageMinimumSupportedLVVersion) `
        -Bitness @($PackageSupportedBitness) | Out-Null
      Add-DevModeTarget -Version ([int]$PackageMinimumSupportedLVVersion) -Bitness @($PackageSupportedBitness)
    }

    $devModeWasToggled = $true
    $devModeActive = $true
  } elseif ($previousDevState.Active) {
    $devModeActive = $true
  }

  $pluginsPath = Join-Path $IconEditorRoot 'resource' 'plugins'
  $baseArtifactName = 'lv_icon.lvlibp'
  $renameToX86 = 'lv_icon_x86.lvlibp'
  $renameToX64 = 'lv_icon_x64.lvlibp'

  Write-Host 'Building icon editor packed libraries...' -ForegroundColor Cyan

  $buildTargets = @(
    [ordered]@{
      Label = '32-bit'
      BuildArguments = @(
        '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
        '-SupportedBitness','32',
        '-RelativePath', $IconEditorRoot,
        '-Major', "$Major",
        '-Minor', "$Minor",
        '-Patch', "$Patch",
        '-Build', "$Build",
        '-Commit', $Commit
      )
      CloseArguments = @(
        '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
        '-SupportedBitness','32'
      )
      RenameArguments = @(
        '-CurrentFilename', '{{BaseArtifactPath}}',
        '-NewFilename', $renameToX86
      )
    },
    [ordered]@{
      Label = '64-bit'
      BuildArguments = @(
        '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
        '-SupportedBitness','64',
        '-RelativePath', $IconEditorRoot,
        '-Major', "$Major",
        '-Minor', "$Minor",
        '-Patch', "$Patch",
        '-Build', "$Build",
        '-Commit', $Commit
      )
      CloseArguments = @(
        '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
        '-SupportedBitness','64'
      )
      RenameArguments = @(
        '-CurrentFilename', '{{BaseArtifactPath}}',
        '-NewFilename', $renameToX64
      )
    }
  )

  $actionInvoker = {
    param(
      [string]$ScriptPath,
      [string[]]$Arguments
    )
    Invoke-IconEditorAction -ScriptPath $ScriptPath -Arguments $Arguments
  }

  $onBuildError = {
    param(
      [hashtable]$Target,
      [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $label = if ($Target.ContainsKey('Label')) { $Target.Label } else { 'unknown target' }
    $diagnostics = [ordered]@{
      LogPath      = (Get-LatestIconEditorLog)?.FullName
      MissingItems = Capture-IconEditorMissingItems -ResultsRootPath $ResultsRoot -ProjectRoot $IconEditorRoot
    }

    $message = "Failed to build icon editor packed library ($label)."
    if ($diagnostics.LogPath) {
      $message += " See $($diagnostics.LogPath) for g-cli output."
    }
    if ($diagnostics.MissingItems) {
      $message += " Missing item details captured at $($diagnostics.MissingItems)."
    }

    return [System.InvalidOperationException]::new($message, $ErrorRecord.Exception)
  }

  Invoke-LVPackedLibraryBuild `
    -InvokeAction $actionInvoker `
    -BuildScriptPath $buildLvlibpScript `
    -CloseScriptPath $closeLabviewScript `
    -RenameScriptPath $renameScript `
    -ArtifactDirectory $pluginsPath `
    -BaseArtifactName $baseArtifactName `
    -CleanupPatterns @('lv_icon*.lvlibp') `
    -Targets $buildTargets `
    -OnBuildError $onBuildError

  $displayInfo = [ordered]@{
    'Package Version' = [ordered]@{
      major = $Major
      minor = $Minor
      patch = $Patch
      build = $Build
    }
    'Product Name'                   = ''
    'Company Name'                   = $CompanyName
    'Author Name (Person or Company)' = $AuthorName
    'Product Homepage (URL)'         = ''
    'Legal Copyright'                = ''
    'License Agreement Name'         = ''
    'Product Description Summary'    = ''
    'Product Description'            = ''
    'Release Notes - Change Log'     = ''
  }

  $displayInfoJson = $displayInfo | ConvertTo-Json -Depth 3
  $vipArtifacts = New-Object System.Collections.Generic.List[object]
  $packageSmokeSummary = $null

  if ($packagingRequested) {
    Write-Host 'Packaging icon editor VIP...' -ForegroundColor Cyan

    $vipbRelativePath = 'Tooling\deployment\NI_Icon_editor.vipb'
    $releaseNotesPath = Join-Path $IconEditorRoot 'Tooling\deployment\release_notes.md'

    $modifyVipbArguments = @(
      '-SupportedBitness','64',
      '-IconEditorRoot', $IconEditorRoot,
      '-VIPBPath', $vipbRelativePath,
      '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
      '-LabVIEWMinorRevision', "$LabVIEWMinorRevision",
      '-Major', "$Major",
      '-Minor', "$Minor",
      '-Patch', "$Patch",
      '-Build', "$Build",
      '-Commit', $Commit,
      '-ReleaseNotesFile', $releaseNotesPath,
      '-DisplayInformationJSON', $displayInfoJson
    )

    $vipArguments = @(
      '-SupportedBitness', "$PackageSupportedBitness",
      '-MinimumSupportedLVVersion', "$PackageMinimumSupportedLVVersion",
      '-LabVIEWMinorRevision', "$PackageLabVIEWMinorRevision",
      '-Major', "$Major",
      '-Minor', "$Minor",
      '-Patch', "$Patch",
      '-Build', "$Build",
      '-Commit', $Commit,
      '-ReleaseNotesFile', $releaseNotesPath,
      '-DisplayInformationJSON', $displayInfoJson,
      '-BuildToolchain', $BuildToolchain
    )
    if ($BuildProvider) {
      $vipArguments += @('-BuildProvider', $BuildProvider)
    }

    $closeArguments = @(
      '-MinimumSupportedLVVersion', "$PackageMinimumSupportedLVVersion",
      '-SupportedBitness', "$PackageSupportedBitness"
    )

    $packagingMetadata = [ordered]@{
      version = @{
        major  = $Major
        minor  = $Minor
        patch  = $Patch
        build  = $Build
        commit = $Commit
      }
      releaseNotes = $releaseNotesPath
      vipbPath     = $vipbRelativePath
    }

    $packagingResult = Invoke-VipmPackageBuild `
      -InvokeAction $actionInvoker `
      -ModifyScriptPath $modifyVipbScript `
      -ModifyArguments $modifyVipbArguments `
      -BuildScriptPath $buildVipScript `
      -BuildArguments $vipArguments `
      -CloseScriptPath $closeLabviewScript `
      -CloseArguments $closeArguments `
      -IconEditorRoot $IconEditorRoot `
      -ResultsRoot $ResultsRoot `
      -ArtifactCutoffUtc ($buildStart.ToUniversalTime()) `
      -TelemetryRoot $vipmBuildTelemetryRoot `
      -Metadata $packagingMetadata `
      -Toolchain $BuildToolchain `
      -Provider $BuildProvider

    foreach ($artifact in $packagingResult.Artifacts) {
      $vipArtifacts.Add($artifact) | Out-Null
    }
  } elseif ($RequirePackaging.IsPresent) {
    throw 'Packaging was required but could not be executed.'
  } else {
    Write-Host 'Packaging skipped by request.' -ForegroundColor Yellow
  }

  if (Test-Path -LiteralPath $packageSmokeScript -PathType Leaf) {
    $vipDestinations = @()
    foreach ($entry in $vipArtifacts) {
      if ($entry.DestinationPath) {
        $vipDestinations += $entry.DestinationPath
      } else {
        $vipDestinations += (Join-Path $ResultsRoot $entry.Name)
      }
    }

    try {
      $packageSmokeSummary = & $packageSmokeScript `
        -VipPath $vipDestinations `
        -ResultsRoot $ResultsRoot `
        -VersionInfo @{
          major  = $Major
          minor  = $Minor
          patch  = $Patch
          build  = $Build
          commit = $Commit
        } `
        -RequireVip:$packagingRequested
    } catch {
      if ($RequirePackaging.IsPresent -or $packagingRequested) {
        throw
      }

      Write-Warning "Package smoke test failed: $($_.Exception.Message)"
    }
  }

  $artifactMap = @(
    @{ Source = Join-Path $IconEditorRoot 'resource\plugins\lv_icon_x86.lvlibp'; Name = 'lv_icon_x86.lvlibp'; Kind = 'lvlibp' },
    @{ Source = Join-Path $IconEditorRoot 'resource\plugins\lv_icon_x64.lvlibp'; Name = 'lv_icon_x64.lvlibp'; Kind = 'lvlibp' }
  )

  foreach ($artifact in $artifactMap) {
    if (Test-Path -LiteralPath $artifact.Source -PathType Leaf) {
      Copy-Item -LiteralPath $artifact.Source -Destination (Join-Path $ResultsRoot $artifact.Name) -Force
    }
  }

  if ($RunUnitTests) {
    Invoke-MissingInProjectCheck -BitnessTargets @('32','64')
    if (-not (Test-Path -LiteralPath $unitReadyHelper -PathType Leaf)) {
      throw "Unit readiness helper '$unitReadyHelper' was not found."
    }
    Write-Host 'Validating icon editor unit-test prerequisites...' -ForegroundColor Cyan
    pwsh -NoLogo -NoProfile -File $unitReadyHelper -Validate

    if (-not (Test-Path -LiteralPath $unitTestScript -PathType Leaf)) {
      throw "Unit test script '$unitTestScript' not found."
    }

    Push-Location (Split-Path -Parent $unitTestScript)
    try {
      $unitTestProject = Join-Path $IconEditorRoot 'lv_icon_editor.lvproj'
      & $unitTestScript `
        -MinimumSupportedLVVersion $MinimumSupportedLVVersion `
        -SupportedBitness '64' `
        -ProjectPath $unitTestProject
    } finally {
      Pop-Location
    }

    $reportPath = Join-Path (Split-Path -Parent $unitTestScript) 'UnitTestReport.xml'
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
      Copy-Item -LiteralPath $reportPath -Destination (Join-Path $ResultsRoot 'UnitTestReport.xml') -Force
    }
  }

  if ($devModeActive -and $devModeWasToggled) {
    Write-Host 'Disabling icon editor development mode...' -ForegroundColor Cyan
    try {
      $targetsToDisable = if ($devModeToggleTargets.Count -gt 0) { $devModeToggleTargets } else { @([pscustomobject]@{ Version = [int]$MinimumSupportedLVVersion; Bitness = @(32,64) }) }
      foreach ($target in $targetsToDisable) {
        Disable-IconEditorDevelopmentMode `
          -RepoRoot $repoRoot `
          -IconEditorRoot $IconEditorRoot `
          -Operation 'BuildPackage' `
          -Versions @($target.Version) `
          -Bitness $target.Bitness | Out-Null
      }
      $devModeActive = $false
    } catch {
      Write-Warning "Failed to disable icon editor development mode: $($_.Exception.Message)"
    }
  }

  $manifest = [ordered]@{
    schema        = 'icon-editor/build@v1'
    generatedAt   = (Get-Date).ToString('o')
    iconEditorRoot = $IconEditorRoot
    resultsRoot   = $ResultsRoot
    version       = @{
      major = $Major
      minor = $Minor
      patch = $Patch
      build = $Build
      commit = $Commit
    }
    dependenciesApplied = [bool]$devModeWasToggled
    unitTestsRun        = [bool]$RunUnitTests
    packagingRequested  = [bool]$packagingRequested
    artifacts = @()
  }

  $manifest.packaging = [ordered]@{
    requestedToolchain       = $BuildToolchain
    requestedProvider        = $null
    packedLibVersion         = [int]$MinimumSupportedLVVersion
    packagingLabviewVersion  = [int]$PackageMinimumSupportedLVVersion
  }
  if ($BuildProvider) {
    $manifest.packaging.requestedProvider = $BuildProvider
  }

  if ($packageSmokeSummary) {
    $manifest.packageSmoke = $packageSmokeSummary
  }

  $devModeState = Get-IconEditorDevModeState -RepoRoot $repoRoot
  $manifest.developmentMode = [ordered]@{
    active    = $devModeState.Active
    updatedAt = $devModeState.UpdatedAt
    source    = $devModeState.Source
    toggled   = [bool]$devModeWasToggled
  }

  foreach ($artifact in $artifactMap) {
    $dest = Join-Path $ResultsRoot $artifact.Name
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
      $info = Get-Item -LiteralPath $dest
      $manifest.artifacts += [ordered]@{
        name = $artifact.Name
        path = $info.FullName
        sizeBytes = $info.Length
        kind = $artifact.Kind
      }
    }
  }

  foreach ($entry in $vipArtifacts) {
    $pathToRecord = if ($entry.DestinationPath -and (Test-Path -LiteralPath $entry.DestinationPath -PathType Leaf)) {
      $entry.DestinationPath
    } else {
      Join-Path $ResultsRoot $entry.Name
    }
    if (-not (Test-Path -LiteralPath $pathToRecord -PathType Leaf)) { continue }
    $info = Get-Item -LiteralPath $pathToRecord
    $manifest.artifacts += [ordered]@{
      name = $info.Name
      path = $info.FullName
      sizeBytes = $info.Length
      kind = 'vip'
    }
  }

  $manifestPath = Join-Path $ResultsRoot 'manifest.json'
  $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

  Write-Host "Icon Editor build completed. Artifacts captured in $ResultsRoot"
}
finally {
  if ($devModeWasToggled -and $devModeActive) {
    try {
      Write-Host 'Disabling icon editor development mode...' -ForegroundColor Cyan
      $targetsToDisable = if ($devModeToggleTargets.Count -gt 0) { $devModeToggleTargets } else { @([pscustomobject]@{ Version = [int]$MinimumSupportedLVVersion; Bitness = @(32,64) }) }
      foreach ($target in $targetsToDisable) {
        Disable-IconEditorDevelopmentMode `
          -RepoRoot $repoRoot `
          -IconEditorRoot $IconEditorRoot `
          -Operation 'BuildPackage' `
          -Versions @($target.Version) `
          -Bitness $target.Bitness | Out-Null
      }
    } catch {
      Write-Warning "Failed to disable icon editor development mode: $($_.Exception.Message)"
    }
  }
  $env:Path = $previousPath
}

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
