#Requires -Version 7.0
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

param(
  [string]$FixturePath,
  [string]$ResultsRoot,
  [object]$ExpectedVersion,
  [string]$VipDiffOutputDir,
  [string]$VipDiffRequestsPath,
  [switch]$KeepExtract,
  [switch]$SkipResourceOverlay,
  [string]$ResourceOverlayRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim()
  } catch {
    return $StartPath
  }
}

function Convert-ToOrderedHashtable {
  param([System.Collections.IDictionary]$Table)
  if (-not $Table) {
    return $null
  }

  $ordered = [ordered]@{}
  foreach ($key in $Table.Keys) {
    $ordered[$key] = $Table[$key]
  }
  return $ordered
}

$repoRoot = Resolve-RepoRoot

if (-not $FixturePath) {
  $FixturePath = [System.Environment]::GetEnvironmentVariable('ICON_EDITOR_FIXTURE_PATH')
}

if (-not $FixturePath) {
  throw "Fixture VI Package path not provided. Pass -FixturePath or set ICON_EDITOR_FIXTURE_PATH."
}

if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) {
  throw "Fixture VI Package not found at '$FixturePath'. Ensure the fixture exists or supply a valid -FixturePath."
}

if (-not $ResultsRoot) {
  $ResultsRoot = Join-Path $repoRoot 'tests' 'results' '_agent' 'icon-editor-simulate'
}

$ResultsRoot = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $ResultsRoot -Force)).Path
$resolvedFixture = (Resolve-Path -LiteralPath $FixturePath).Path

$extractRoot = Join-Path $ResultsRoot '__fixture_extract'
if (Test-Path -LiteralPath $extractRoot) {
  Remove-Item -LiteralPath $extractRoot -Recurse -Force
}

Expand-Archive -Path $resolvedFixture -DestinationPath $extractRoot -Force

$specPath = Join-Path $extractRoot 'spec'
if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) {
  throw "Fixture spec not found at '$specPath'. The fixture appears to be invalid."
}

$specContent = Get-Content -LiteralPath $specPath
$versionLine = $specContent | Where-Object { $_ -match '^Version="([^"]+)"' } | Select-Object -First 1
if (-not $versionLine) {
  throw "Unable to parse version from fixture spec at '$specPath'."
}

$fixtureVersionRaw = [regex]::Match($versionLine, '^Version="([^"]+)"').Groups[1].Value
$fixtureVersionParts = $fixtureVersionRaw.Split('.')
if ($fixtureVersionParts.Count -lt 4) {
  throw "Fixture version '$fixtureVersionRaw' is not in major.minor.patch.build format."
}

$fixtureVersion = [ordered]@{
  major = [int]$fixtureVersionParts[0]
  minor = [int]$fixtureVersionParts[1]
  patch = [int]$fixtureVersionParts[2]
  build = [int]$fixtureVersionParts[3]
  raw   = $fixtureVersionRaw
}

$packagesRoot = Join-Path $extractRoot 'Packages'
$nestedVip = Get-ChildItem -LiteralPath $packagesRoot -Filter '*.vip' -Recurse -ErrorAction Stop | Select-Object -First 1
if (-not $nestedVip) {
  throw "Unable to locate nested system VIP inside fixture '${resolvedFixture}'."
}

$nestedExtract = Join-Path $extractRoot '__system_extract'
if (Test-Path -LiteralPath $nestedExtract) {
  Remove-Item -LiteralPath $nestedExtract -Recurse -Force
}

Expand-Archive -Path $nestedVip.FullName -DestinationPath $nestedExtract -Force

$resourceRoot = $ResourceOverlayRoot
if (-not $resourceRoot) {
  $resourceRoot = Join-Path $repoRoot 'vendor/icon-editor/resource'
}
if (-not $SkipResourceOverlay.IsPresent -and $resourceRoot -and (Test-Path -LiteralPath $resourceRoot -PathType Container)) {
  $resourceDest = Join-Path $nestedExtract 'File Group 0\National Instruments\LabVIEW Icon Editor\resource'
  if (-not (Test-Path -LiteralPath $resourceDest -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $resourceDest -Force)
  }
  $robocopyCommand = $null
  try {
    $robocopyCommand = Get-Command 'robocopy' -ErrorAction SilentlyContinue
  } catch {
    $robocopyCommand = $null
  }

  $useFallback = $false
  if ($robocopyCommand) {
    $quotedSource = '"{0}"' -f $resourceRoot
    $quotedDest = '"{0}"' -f $resourceDest
    $robocopyArgs = @($quotedSource, $quotedDest, '/E')
    $rc = Start-Process -FilePath $robocopyCommand.Source -ArgumentList $robocopyArgs -NoNewWindow -PassThru -Wait
    if ($rc.ExitCode -gt 3) {
      Write-Warning "Failed to mirror resource directory with robocopy (exit code $($rc.ExitCode)); using Copy-Item fallback."
      $useFallback = $true
    }
  } else {
    Write-Host '::notice::robocopy not found; using Copy-Item fallback for resource overlay.'
    $useFallback = $true
  }

  if ($useFallback) {
    if (-not (Test-Path -LiteralPath $resourceDest -PathType Container)) {
      [void](New-Item -ItemType Directory -Path $resourceDest -Force)
    }
    Get-ChildItem -LiteralPath $resourceRoot -Force | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $resourceDest -Recurse -Force -ErrorAction Stop
    }
  }
} elseif ($SkipResourceOverlay.IsPresent) {
  Write-Host '::notice::Skipping resource overlay by request.'
} else {
  Write-Host '::notice::vendor/icon-editor/resource not found; skipping resource overlay.'
}

$installRoot = Join-Path $nestedExtract 'File Group 0\National Instruments\LabVIEW Icon Editor\install'
$lvlibpFiles = @()
if (Test-Path -LiteralPath $installRoot -PathType Container) {
  $lvlibpFiles = Get-ChildItem -LiteralPath $installRoot -Filter '*.lvlibp' -File -Recurse -ErrorAction SilentlyContinue
}
if (-not $lvlibpFiles -or $lvlibpFiles.Count -eq 0) {
  $legacyTemp = Join-Path $nestedExtract 'File Group 0\National Instruments\LabVIEW Icon Editor\install\temp'
  if (Test-Path -LiteralPath $legacyTemp -PathType Container) {
    $lvlibpFiles = Get-ChildItem -LiteralPath $legacyTemp -Filter '*.lvlibp' -File -ErrorAction SilentlyContinue
  }
}
if (-not $lvlibpFiles -or $lvlibpFiles.Count -eq 0) {
  $resourcePlugins = Join-Path $nestedExtract 'File Group 0\National Instruments\LabVIEW Icon Editor\resource\plugins'
  if (Test-Path -LiteralPath $resourcePlugins -PathType Container) {
    $lvlibpFiles = Get-ChildItem -LiteralPath $resourcePlugins -Filter '*.lvlibp' -File -Recurse -ErrorAction SilentlyContinue
  }
}
if (-not $lvlibpFiles -or $lvlibpFiles.Count -eq 0) {
  Write-Warning "Unable to locate lvlibp artifacts inside system VIP under '$installRoot'. Packaging outputs may be incomplete; continuing without lvlibp artifacts."
  $lvlibpFiles = @()
}

$artifacts = @()

function Register-Artifact {
  param(
    [string]$SourcePath,
    [string]$DestinationPath,
    [string]$Kind
  )

  Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
  $info = Get-Item -LiteralPath $DestinationPath
  return [ordered]@{
    name      = $info.Name
    path      = $info.FullName
    sizeBytes = $info.Length
    kind      = $Kind
  }
}

$fixtureDest = Join-Path $ResultsRoot (Split-Path -Leaf $resolvedFixture)
$artifacts += Register-Artifact -SourcePath $resolvedFixture -DestinationPath $fixtureDest -Kind 'vip'

$systemVipName = Split-Path -Leaf $nestedVip.FullName
$systemDest = Join-Path $ResultsRoot $systemVipName
$artifacts += Register-Artifact -SourcePath $nestedVip.FullName -DestinationPath $systemDest -Kind 'vip'

$seenDestinations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $lvlibpFiles) {
  $dest = Join-Path $ResultsRoot $file.Name
  if ($seenDestinations.Add($dest)) {
    $artifacts += Register-Artifact -SourcePath $file.FullName -DestinationPath $dest -Kind 'lvlibp'
  }
}

$expectedVersionValue = $ExpectedVersion
if ($expectedVersionValue -is [string] -and -not [string]::IsNullOrWhiteSpace($expectedVersionValue)) {
  try {
    $expectedVersionValue = $expectedVersionValue | ConvertFrom-Json -AsHashtable -Depth 6
  } catch {
    $expectedVersionValue = $null
  }
} elseif ($expectedVersionValue -is [pscustomobject]) {
  $expectedVersionValue = $expectedVersionValue | ConvertTo-Json | ConvertFrom-Json -AsHashtable -Depth 6
} elseif ($expectedVersionValue -and $expectedVersionValue -isnot [System.Collections.IDictionary]) {
  $expectedVersionValue = $null
}

$packageSmokeScript = Join-Path $repoRoot 'tools' 'icon-editor' 'Test-IconEditorPackage.ps1'
$packageSmokeSummary = $null
if (Test-Path -LiteralPath $packageSmokeScript -PathType Leaf) {
  $fixtureCommit = 'fixture'
  if ($expectedVersionValue -and ($expectedVersionValue.Keys -contains 'commit') -and $expectedVersionValue['commit']) {
    $fixtureCommit = $expectedVersionValue['commit']
  }

  $fixtureVersionInfo = [ordered]@{
    major  = $fixtureVersion.major
    minor  = $fixtureVersion.minor
    patch  = $fixtureVersion.patch
    build  = $fixtureVersion.build
    commit = $fixtureCommit
  }

  $vipTargets = @($systemDest)
  $packageSmokeSummary = & $packageSmokeScript `
    -VipPath $vipTargets `
    -ResultsRoot $ResultsRoot `
    -VersionInfo $fixtureVersionInfo `
    -RequireVip
}

$expectedVersionOrdered = Convert-ToOrderedHashtable $expectedVersionValue
if ($expectedVersionOrdered) {
  $hasNumericParts =
    $expectedVersionOrdered.Contains('major') -and
    $expectedVersionOrdered.Contains('minor') -and
    $expectedVersionOrdered.Contains('patch') -and
    $expectedVersionOrdered.Contains('build')
  if ($hasNumericParts -and -not $expectedVersionOrdered.Contains('raw')) {
    $expectedVersionOrdered['raw'] = '{0}.{1}.{2}.{3}' -f `
      $expectedVersionOrdered['major'], `
      $expectedVersionOrdered['minor'], `
      $expectedVersionOrdered['patch'], `
      $expectedVersionOrdered['build']
  }
}

$vipDiffInfo = $null
if ($VipDiffOutputDir) {
  $prepareVipScript = Join-Path $repoRoot 'tools' 'icon-editor' 'Prepare-VipViDiffRequests.ps1'
  if (-not (Test-Path -LiteralPath $prepareVipScript -PathType Leaf)) {
    throw "Prepare-VipViDiffRequests.ps1 not found at '$prepareVipScript'."
  }
  $effectiveRequestsPath = if ($VipDiffRequestsPath) { $VipDiffRequestsPath } else { Join-Path $VipDiffOutputDir 'vi-diff-requests.json' }
  $vipDiffInfo = & $prepareVipScript `
    -ExtractRoot $nestedExtract `
    -RepoRoot $repoRoot `
    -OutputDir $VipDiffOutputDir `
    -RequestsPath $effectiveRequestsPath `
    -Category 'vip'
}

$manifest = [ordered]@{
  schema              = 'icon-editor/build@v1'
  generatedAt         = (Get-Date).ToString('o')
  resultsRoot         = $ResultsRoot
  packagingRequested  = $true
  dependenciesApplied = $false
  unitTestsRun        = $false
  simulation          = [ordered]@{
    enabled     = $true
    fixturePath = $resolvedFixture
  }
  version             = [ordered]@{
    fixture  = $fixtureVersion
  }
  artifacts           = @()
}

if ($expectedVersionOrdered) {
  $manifest.version.expected = $expectedVersionOrdered
}

foreach ($artifact in $artifacts) {
  $manifest.artifacts += $artifact
}

if ($packageSmokeSummary) {
  $manifest.packageSmoke = $packageSmokeSummary
}

if ($vipDiffInfo) {
  $manifest.vipDiff = [ordered]@{
    requestsPath = $vipDiffInfo.requestsPath
    count        = $vipDiffInfo.count
    generatedAt  = $vipDiffInfo.generatedAt
    headRoot     = $vipDiffInfo.headRoot
  }
}

$manifestPath = Join-Path $ResultsRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if (-not $KeepExtract.IsPresent) {
  if (Test-Path -LiteralPath $nestedExtract) {
    Remove-Item -LiteralPath $nestedExtract -Recurse -Force
  }
  if (Test-Path -LiteralPath $extractRoot) {
    Remove-Item -LiteralPath $extractRoot -Recurse -Force
  }
}

return [pscustomobject]$manifest

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