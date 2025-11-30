#Requires -Version 7.0

param(
  [string]$ReportPath,
  [string]$FixturePath,
  [string]$OutputPath,
  [switch]$UpdateDoc
)

Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim()
  } catch {
    return $StartPath
  }
}

function Ensure-FixtureReport {
  param(
    [string]$ReportPath,
    [string]$FixturePath,
    [string]$RepoRoot
  )

  if ($ReportPath -and (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    return $ReportPath
  }

  $defaultPath = Join-Path $RepoRoot 'tests' 'results' '_agent' 'icon-editor' 'fixture-report.json'
  $targetPath = $ReportPath
  if (-not $targetPath) {
    $targetPath = $defaultPath
  }

  if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    $describeScript = Join-Path $RepoRoot 'tools' 'icon-editor' 'Describe-IconEditorFixture.ps1'
    $describeParams = @{
      OutputPath = $targetPath
      KeepWork   = $false
    }
    if ($FixturePath) {
      $describeParams['FixturePath'] = $FixturePath
    }
    pwsh -NoLogo -NoProfile -File $describeScript @describeParams | Out-Null
  }

  return $targetPath
}

function Format-HashMatch {
  param([bool]$Match)
  if ($Match) { return 'match' }
  return 'mismatch'
}

function Render-CustomActions {
  param($CustomActions)
  $lines = @(
    '| Action | Fixture Hash | Repo Hash | Match |',
    '| --- | --- | --- | --- |'
  )

  foreach ($item in $CustomActions) {
    $fixtureHash = if ($item.fixture) { $item.fixture.hash } else { '_missing_' }
    $repoHash = if ($item.repo) { $item.repo.hash } else { '_missing_' }
    $lines += [string]::Format('| {0} | `{1}` | `{2}` | {3} |', $item.name, $fixtureHash, $repoHash, (Format-HashMatch $item.hashMatch))
  }

  return $lines
}

function Render-ArtifactList {
  param($Artifacts)
  foreach ($artifact in $Artifacts) {
    $sizeMB = [math]::Round($artifact.sizeBytes / 1MB, 2)
    [string]::Format('{0} - {1} MB (`{2}`)', $artifact.name, $sizeMB, $artifact.hash)
  }
}

function Render-FixtureOnlyAssets {
  param($Assets)
  if (-not $Assets -or $Assets.Count -eq 0) {
    return @('- None detected.')
  }

  $grouped = $Assets | Group-Object category
  $lines = @()
  foreach ($group in $grouped) {
    $lines += ("- {0} ({1} entries)" -f $group.Name, $group.Count)
    foreach ($asset in ($group.Group | Sort-Object name | Select-Object -First 5)) {
      $lines += ("  - `{0}` (`{1}`)" -f $asset.name, $asset.hash)
    }
    if ($group.Count -gt 5) {
      $lines += ("  - ... {0} more" -f ($group.Count - 5))
    }
  }
  return $lines
}

function Build-FixtureManifestFromSummary {
  param($Summary)
  $entries = @()
  foreach ($asset in ($Summary.fixtureOnlyAssets | Sort-Object category, name)) {
    $rel = if ($asset.category -eq 'script') { Join-Path 'scripts' $asset.name } else { Join-Path 'tests' $asset.name }
    $entries += [ordered]@{
      key       = ($asset.category + ':' + $rel).ToLower()
      category  = $asset.category
      path      = $rel
      sizeBytes = ($asset.sizeBytes ?? 0)
      hash      = $asset.hash
    }
  }
  return $entries
}

function Compute-ManifestDelta {
  param($BaseEntries, $NewEntries)
  $baseMap = @{}
  foreach ($e in $BaseEntries) { $baseMap[$e.key] = $e }
  $newMap = @{}
  foreach ($e in $NewEntries) { $newMap[$e.key] = $e }

  $added = @()
  $removed = @()
  $changed = @()

  foreach ($k in $newMap.Keys) {
    if (-not $baseMap.ContainsKey($k)) { $added += $newMap[$k]; continue }
    $b = $baseMap[$k]; $n = $newMap[$k]
    if (($b.hash -ne $n.hash) -or ([int64]$b.sizeBytes -ne [int64]$n.sizeBytes)) { $changed += $n }
  }
  foreach ($k in $baseMap.Keys) {
    if (-not $newMap.ContainsKey($k)) { $removed += $baseMap[$k] }
  }

  return [ordered]@{
    added   = $added
    removed = $removed
    changed = $changed
  }
}

function Get-SafeProperty {
  param($Object, [string]$PropertyName)
  if ($Object -and $Object.PSObject.Properties[$PropertyName]) {
    return $Object.$PropertyName
  }
  return $null
}

$repoRoot = Resolve-RepoRoot
$resolvedReportPath = Ensure-FixtureReport -ReportPath $ReportPath -FixturePath $FixturePath -RepoRoot $repoRoot
$summary = Get-Content -LiteralPath $resolvedReportPath -Raw | ConvertFrom-Json -Depth 10

$fixture = Get-SafeProperty $summary 'fixture'
if (-not $fixture) {
  $fixture = [pscustomobject]@{
    package = [pscustomobject]@{ Version = 'unknown' }
    description = [pscustomobject]@{ License = 'unknown' }
  }
}
$systemPackage = Get-SafeProperty $summary 'systemPackage'
if (-not $systemPackage) {
  $systemPackage = [pscustomobject]@{
    package = [pscustomobject]@{ Version = 'unknown' }
  }
}
$manifest = Get-SafeProperty $summary 'manifest'
if (-not $manifest) {
  $manifest = [pscustomobject]@{
    packageSmoke = [pscustomobject]@{ status = 'unknown'; vipCount = 0 }
    simulation   = [pscustomobject]@{ enabled = $false }
    unitTestsRun = $false
  }
} else {
  if (-not $manifest.packageSmoke) { $manifest.packageSmoke = [pscustomobject]@{ status = 'unknown'; vipCount = 0 } }
  if (-not $manifest.simulation) { $manifest.simulation = [pscustomobject]@{ enabled = $false } }
}
$stakeholder = Get-SafeProperty $summary 'stakeholder'
if (-not $stakeholder) {
  $stakeholder = [pscustomobject]@{
    generatedAt        = $summary.generatedAt
    smokeStatus        = 'unknown'
    runnerDependencies = [pscustomobject]@{ matchesRepo = $false }
    customActions      = @()
    fixtureOnlyAssets  = @()
  }
} else {
  if (-not $stakeholder.runnerDependencies) { $stakeholder.runnerDependencies = [pscustomobject]@{ matchesRepo = $false } }
  if (-not $stakeholder.customActions) { $stakeholder.customActions = @() }
  if (-not $stakeholder.fixtureOnlyAssets) { $stakeholder.fixtureOnlyAssets = @() }
}
$runnerDependencies = Get-SafeProperty $summary 'runnerDependencies'
if (-not $runnerDependencies) { $runnerDependencies = [pscustomobject]@{ hashMatch = $true } }
$customActionComparisons = Get-SafeProperty $summary 'customActions'
if (-not $customActionComparisons) { $customActionComparisons = @() }
$fixtureOnlyAssets = Get-SafeProperty $summary 'fixtureOnlyAssets'
if (-not $fixtureOnlyAssets) { $fixtureOnlyAssets = @() }

$fixtureVersion = $fixture.package?.Version ?? 'unknown'
$systemVersion = $systemPackage.package?.Version ?? 'unknown'
$fixtureLicense = $fixture.description?.License ?? 'unknown'
$generatedAt = Get-SafeProperty $summary 'generatedAt'
$fixturePathFull = $summary.source?.fixturePath
try {
  $fixturePath = [System.IO.Path]::GetRelativePath($repoRoot, $fixturePathFull)
} catch {
  $fixturePath = $fixturePathFull
}

$lines = @()
$lines += "## Package layout highlights"
$lines += ""
$lines += [string]::Format('- Fixture version `{0}` (system `{1}`), license `{2}`.', $fixtureVersion, $systemVersion, $fixtureLicense)
$lines += [string]::Format('- Fixture path: `{0}`', $fixturePath)
$lines += [string]::Format('- Package smoke status: **{0}** (VIPs: {1})', $manifest.packageSmoke.status, $manifest.packageSmoke.vipCount)
$stakeholderGeneratedAt = Get-SafeProperty $stakeholder 'generatedAt'
$lines += [string]::Format('- Report generated: `{0}`', $stakeholderGeneratedAt ?? $generatedAt)
$lines += "- Artifacts:"
foreach ($item in (Render-ArtifactList $summary.artifacts)) {
  $lines += ("  - {0}" -f $item)
}
$lines += ""
$lines += "## Stakeholder summary"
$lines += ""
$lines += [string]::Format('- Smoke status: **{0}**', $stakeholder.smokeStatus)
$lines += [string]::Format('- Runner dependencies: {0}', $stakeholder.runnerDependencies.matchesRepo ? 'match' : 'mismatch')
$lines += [string]::Format('- Custom actions: {0} entries (all match: {1})', ($stakeholder.customActions | Measure-Object).Count, (($stakeholder.customActions | Where-Object { $_.matchStatus -ne 'match' } | Measure-Object).Count -eq 0))
$lines += [string]::Format('- Fixture-only assets discovered: {0}', ($stakeholder.fixtureOnlyAssets | Measure-Object).Count)
$lines += ""
$lines += "## Comparison with repository sources"
$lines += ""
$lines += "- Custom action hashes:"
$lines += Render-CustomActions $customActionComparisons
$lines += ""
$lines += ("- Runner dependencies hash match: {0}" -f (Format-HashMatch $runnerDependencies.hashMatch))
$lines += ""
$lines += "## Fixture-only assets"
$lines += ""
$lines += Render-FixtureOnlyAssets $fixtureOnlyAssets
$lines += ""
$lines += "## Fixture-only manifest delta"
$lines += ""
$baselinePath = $env:ICON_EDITOR_BASELINE_MANIFEST_PATH
$baselinePathResolved = $null
if ($baselinePath) {
  if ([System.IO.Path]::IsPathRooted($baselinePath)) {
    $baselinePathResolved = $baselinePath
  } else {
    $baselinePathResolved = Join-Path $repoRoot $baselinePath
  }
}

if (-not $baselinePathResolved -or -not (Test-Path -LiteralPath $baselinePathResolved -PathType Leaf)) {
  $lines += "- Baseline manifest not provided; skipping delta."
} else {
  try {
    $baseline = Get-Content -LiteralPath $baselinePathResolved -Raw | ConvertFrom-Json -Depth 6
    $currentEntries = Build-FixtureManifestFromSummary -Summary $summary
    $delta = Compute-ManifestDelta -BaseEntries $baseline.entries -NewEntries $currentEntries
    $lines += [string]::Format('- Added: {0}, Removed: {1}, Changed: {2}', ($delta.added | Measure-Object).Count, ($delta.removed | Measure-Object).Count, ($delta.changed | Measure-Object).Count)
    foreach ($tuple in @(@('Added', $delta.added), @('Removed', $delta.removed), @('Changed', $delta.changed))) {
      $label = $tuple[0]; $items = $tuple[1]
      if (($items | Measure-Object).Count -gt 0) {
        $lines += ([string]::Format('- {0}:', $label))
        foreach ($e in ($items | Sort-Object key | Select-Object -First 5)) { $lines += ([string]::Format('  - `{0}`', $e.key)) }
        if (($items | Measure-Object).Count -gt 5) {
          $more = ((($items | Measure-Object).Count) - 5)
          $lines += ([string]::Format('  - (+{0} more)', $more))
        }
      }
    }
  } catch {
    $lines += ("- Failed to compute delta: {0}" -f $_.Exception.Message)
  }
}
$lines += ""
$lines += "## Changed VI comparison (requests)"
$lines += ""
$lines += "- When changed VI assets are detected, Validate publishes an 'icon-editor-fixture-vi-diff-requests' artifact"
$lines += "  with the list of base/head paths for LVCompare."
$lines += "- Local runs can generate requests via tools/icon-editor/Prepare-FixtureViDiffs.ps1."
$lines += ""
$lines += "## Simulation metadata"
$lines += ""
$lines += [string]::Format('- Simulation enabled: {0}', $manifest.simulation.enabled)
$lines += [string]::Format('- Unit tests executed: {0}', $manifest.unitTestsRun)

$markdown = ($lines -join "`n")

if ($OutputPath) {
  $markdown | Set-Content -LiteralPath $OutputPath -Encoding utf8
}

if ($UpdateDoc.IsPresent) {
  $docPath = Join-Path $repoRoot 'docs' 'ICON_EDITOR_PACKAGE.md'
  $startMarker = '<!-- icon-editor-report:start -->'
  $endMarker = '<!-- icon-editor-report:end -->'
  $docContent = Get-Content -LiteralPath $docPath -Raw
  if (-not ($docContent.Contains($startMarker) -and $docContent.Contains($endMarker))) {
    throw "Markers not found in $docPath. Expected $startMarker ... $endMarker."
  }
  $replaceScript = {
    param([System.Text.RegularExpressions.Match]$match, [string]$replacementText)
    return $replacementText
  }
  $pattern = [System.Text.RegularExpressions.Regex]::Escape($startMarker) + '.*?' + [System.Text.RegularExpressions.Regex]::Escape($endMarker)
  $regex = [System.Text.RegularExpressions.Regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $updated = $regex.Replace($docContent, { param($m) "$startMarker`n$markdown`n$endMarker" })
  $updatedLines = @($updated -split "`r?`n")
  while ($updatedLines.Count -gt 1 -and [string]::IsNullOrWhiteSpace($updatedLines[-1])) {
    $updatedLines = $updatedLines[0..($updatedLines.Count - 2)]
  }
  $updatedLines += ''
  Set-Content -LiteralPath $docPath -Value $updatedLines -Encoding utf8
}

if (-not $OutputPath) {
  Write-Output $markdown
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