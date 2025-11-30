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
<#
.SYNOPSIS
Runs the MissingInProject Pester suite end-to-end with optional VI Analyzer gating.

.DESCRIPTION
Invokes `Invoke-PesterTests.ps1` against either the compare-only or full
MissingInProject suite, mirrors artifacts into `<ResultsPath>/<label>`,
optionally cleans stale artifacts, and (when configured) runs the VI Analyzer
before performing the g-cli comparisons.

.PARAMETER Label
Optional label for this run. Defaults to `mip-<branch>-<sha>-<timestamp>`.

.PARAMETER ResultsPath
Root directory for suite artifacts (`tests/results` by default). Each run writes
`<ResultsPath>/<label>/...`, `latest-run.json`, `run-index.json`, and mirrors
the latest Pester outputs to the root.

.PARAMETER SkipNegative
Skip the "negative" MissingInProject tests (default behaviour). Use
`-IncludeNegative` to run those tests.

.PARAMETER IncludeNegative
Force the suite to run the negative coverage tests.

.PARAMETER LogPath
Path to a transcript or log file to attach to the MissingInProject report.

.PARAMETER AdditionalPesterArgs
Extra arguments passed to `Invoke-PesterTests.ps1`.

.PARAMETER CleanResults
If set, remove existing artifacts from `<ResultsPath>` before running.

.PARAMETER RequireCompareReport
Fail when the compare report (HTML) is missing or the LVCompare capture is
incomplete.

.PARAMETER TestSuite
Select `compare` (default) or `full` (dev-mode suite).

.PARAMETER ViAnalyzerConfigPath
Optional path to a `.viancfg` file. When provided (or when
`MIP_VIANALYZER_CONFIG` is set), the VI Analyzer wrapper runs before Pester and
the suite fails if it reports broken VIs.

.PARAMETER SkipViAnalyzer
Skip the analyzer gate even when a config path is available.

.PARAMETER ViAnalyzerVersion
LabVIEW version to use for the analyzer gate (defaults to 2021).

.PARAMETER ViAnalyzerBitness
LabVIEW bitness for the analyzer gate (defaults to 64-bit).
#>
[CmdletBinding()]
param(
  [string]$Label,
  [string]$ResultsPath = 'tests/results',
  [switch]$SkipNegative = $true,
  [switch]$IncludeNegative,
  [string]$LogPath,
  [string[]]$AdditionalPesterArgs,
  [switch]$CleanResults,
  [switch]$RequireCompareReport,
  [ValidateSet('compare','full')]
  [string]$TestSuite = 'compare',
  [string]$ViAnalyzerConfigPath,
  [switch]$SkipViAnalyzer,
  [int]$ViAnalyzerVersion = 2023,
  [ValidateSet(32,64)]
  [int]$ViAnalyzerBitness = 64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) { return (Resolve-Path -LiteralPath $root.Trim()).Path }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

$trueValues = @('1','true','yes','on')
$falseValues = @('0','false','no','off')

function Get-EnvBoolean {
  param(
    [string]$Name,
    [bool]$DefaultValue = $false
  )
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }
  $normalized = $value.Trim().ToLowerInvariant()
  if ($trueValues -contains $normalized) { return $true }
  if ($falseValues -contains $normalized) { return $false }
  return $DefaultValue
}

function Get-EnvInt {
  param(
    [string]$Name,
    [int]$DefaultValue = 0
  )
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }
  $parsed = 0
  if ([int]::TryParse($value, [ref]$parsed)) {
    return $parsed
  }
  return $DefaultValue
}

function ConvertTo-IntListFromString {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
  $list = New-Object System.Collections.Generic.List[int]
  foreach ($segment in ($Value -split '[,; ]+')) {
    if ([string]::IsNullOrWhiteSpace($segment)) { continue }
    $parsed = 0
    if ([int]::TryParse($segment.Trim(), [ref]$parsed)) {
      [void]$list.Add($parsed)
    }
  }
  return $list.ToArray()
}

function Get-MipDevModeTargets {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [int]$DefaultVersion,
    [int]$DefaultBitness,
    [string]$Operation = 'MissingInProject'
  )

  $versions = ConvertTo-IntListFromString ([Environment]::GetEnvironmentVariable('MIP_DEV_MODE_VERSIONS'))
  $bitness  = ConvertTo-IntListFromString ([Environment]::GetEnvironmentVariable('MIP_DEV_MODE_BITNESS'))

  $modulePath = Join-Path $RepoRoot 'tools' 'icon-editor' 'IconEditorDevMode.psm1'
  $policyEntry = $null
  if (Test-Path -LiteralPath $modulePath -PathType Leaf) {
    Import-Module $modulePath -Force
    try {
      $policyEntry = Get-IconEditorDevModePolicyEntry -Operation $Operation -RepoRoot $RepoRoot
    } catch {
      Write-Verbose ("Failed to read icon-editor dev-mode policy: {0}" -f $_.Exception.Message)
    }
  }

  if ((-not $versions) -or $versions.Count -eq 0) {
    if ($policyEntry -and $policyEntry.Versions -and $policyEntry.Versions.Count -gt 0) {
      $versions = @($policyEntry.Versions)
    } elseif ($DefaultVersion -gt 0) {
      $versions = @($DefaultVersion)
    } else {
      $versions = @(2023)
    }
  }
  if ((-not $bitness) -or $bitness.Count -eq 0) {
    if ($policyEntry -and $policyEntry.Bitness -and $policyEntry.Bitness.Count -gt 0) {
      $bitness = @($policyEntry.Bitness)
    } elseif ($DefaultBitness -in 32,64) {
      $bitness = @($DefaultBitness)
    } else {
      $bitness = @(64)
    }
  }

  $versions = @($versions | ForEach-Object { [int]$_ } | Sort-Object -Unique)
  $bitness  = @($bitness | ForEach-Object { [int]$_ } | Where-Object { $_ -in 32,64 } | Sort-Object -Unique)
  if ($bitness.Count -eq 0) { $bitness = @(64) }

  return [pscustomobject]@{
    Versions = $versions
    Bitness  = $bitness
  }
}

function Invoke-MipDevModeRecovery {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation = 'MissingInProject'
  )

  if (-not $RepoRoot) { throw "Dev-mode recovery requires a repository root." }
  if (-not $Versions -or $Versions.Count -eq 0) { throw "Dev-mode recovery requires at least one LabVIEW version." }
  if (-not $Bitness -or $Bitness.Count -eq 0) { throw "Dev-mode recovery requires at least one LabVIEW bitness." }

  $result = [ordered]@{
    versions  = $Versions
    bitness   = $Bitness
    timestamp = (Get-Date).ToString('o')
  }

  $helperOverride = [Environment]::GetEnvironmentVariable('MIP_DEV_MODE_RECOVERY_HELPER')
  if ($helperOverride) {
    $helperPath = (Resolve-Path -LiteralPath $helperOverride -ErrorAction Stop).Path
    & $helperPath `
      -RepoRoot $RepoRoot `
      -Versions $Versions `
      -Bitness $Bitness `
      -Operation $Operation | Out-Null
    $result.helper = $helperPath
    $result.enabledDevMode = $true
    return [pscustomobject]$result
  }

  $modulePath = Join-Path $RepoRoot 'tools' 'icon-editor' 'IconEditorDevMode.psm1'
  if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "IconEditorDevMode module not found at '$modulePath'."
  }
  Import-Module $modulePath -Force
  $iconEditorRoot = Join-Path $RepoRoot 'vendor' 'icon-editor'
  if (-not (Test-Path -LiteralPath $iconEditorRoot -PathType Container)) {
    throw "Icon editor root not found at '$iconEditorRoot'."
  }

  if (Get-Command -Name Close-IconEditorLabVIEW -ErrorAction SilentlyContinue) {
    try {
      Close-IconEditorLabVIEW -RepoRoot $RepoRoot -IconEditorRoot $iconEditorRoot -Versions $Versions -Bitness $Bitness | Out-Null
      $result.closedLabVIEW = $true
    } catch {
      $result.closedLabVIEW = $false
      $result.closeError = $_.Exception.Message
      Write-Warning ("Dev-mode recovery: Close-IconEditorLabVIEW failed: {0}" -f $_.Exception.Message)
    }
  } else {
    Write-Warning "Dev-mode recovery: Close-IconEditorLabVIEW command not available; skipping graceful shutdown."
  }

  $enableScript = Join-Path $RepoRoot 'tools' 'icon-editor' 'Enable-DevMode.ps1'
  if (-not (Test-Path -LiteralPath $enableScript -PathType Leaf)) {
    throw "Enable-DevMode.ps1 not found at '$enableScript'."
  }
  & $enableScript `
    -RepoRoot $RepoRoot `
    -IconEditorRoot $iconEditorRoot `
    -Versions $Versions `
    -Bitness $Bitness `
    -Operation $Operation | Out-Null
  $result.enabledDevMode = $true
  return [pscustomobject]$result
}

$repoRoot = Resolve-RepoRoot
function New-MipLabel {
  param([string]$Root)
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
  $branch = [Environment]::GetEnvironmentVariable('MIP_LABEL_BRANCH')
  $sha = [Environment]::GetEnvironmentVariable('MIP_LABEL_SHA')
  if (-not $branch) {
    try {
      $branch = (git -C $Root rev-parse --abbrev-ref HEAD 2>$null).Trim()
    } catch { $branch = $null }
  }
  if (-not $sha) {
    try {
      $sha = (git -C $Root rev-parse --short HEAD 2>$null).Trim()
    } catch { $sha = $null }
  }
  if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'unknown' }
  if ([string]::IsNullOrWhiteSpace($sha)) { $sha = ([Guid]::NewGuid().ToString('N').Substring(0,7)) }
  $sanitize = { param($value) ($value -replace '[^A-Za-z0-9\-]+','-').Trim('-').ToLowerInvariant() }
  $branch = & $sanitize $branch
  if (-not $branch) { $branch = 'unknown' }
  $sha = & $sanitize $sha
  if (-not $sha) { $sha = ([Guid]::NewGuid().ToString('N').Substring(0,7)) }
  return "mip-{0}-{1}-{2}" -f $branch, $sha, $timestamp
}

if (-not $Label) {
  $Label = New-MipLabel -Root $repoRoot
}

$devModeOperationName = 'MissingInProject'
$devModeRetryEnabled = Get-EnvBoolean -Name 'MIP_DEV_MODE_RETRY_ON_BROKEN_VI' -DefaultValue $true
$devModeRetryDelaySeconds = [Math]::Max(0, (Get-EnvInt -Name 'MIP_DEV_MODE_RETRY_DELAY_SECONDS' -DefaultValue 5))
$viAnalyzerRetryInfo = [ordered]@{
  enabled   = $devModeRetryEnabled
  attempted = $false
  succeeded = $false
  targets   = $null
  note      = $null
  recovery  = $null
}

$compareTestsPath = Join-Path $repoRoot 'tests' 'IconEditorMissingInProject.CompareOnly.Tests.ps1'
$fullTestsPath    = Join-Path $repoRoot 'tests' 'IconEditorMissingInProject.DevMode.Tests.ps1'
$selectedTestsPath = switch ($TestSuite) {
  'full' { $fullTestsPath }
  default { $compareTestsPath }
}
if (-not (Test-Path -LiteralPath $selectedTestsPath -PathType Leaf)) {
  throw "Unable to locate MissingInProject test suite at '$selectedTestsPath'."
}

$resultsResolved = if ([System.IO.Path]::IsPathRooted($ResultsPath)) {
  $ResultsPath
} else {
  Join-Path $repoRoot $ResultsPath
}

$compareAnalyzerEnv = [Environment]::GetEnvironmentVariable('MIP_COMPARE_ANALYZER')
$compareAnalyzerScript = if ($compareAnalyzerEnv) { $compareAnalyzerEnv } else { Join-Path $repoRoot 'tools' 'report' 'Analyze-CompareReportImages.ps1' }
if (-not (Test-Path -LiteralPath $resultsResolved -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $resultsResolved -Force)
}

if ($CleanResults.IsPresent -and (Test-Path -LiteralPath $resultsResolved -PathType Container)) {
  Get-ChildItem -LiteralPath $resultsResolved -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$runResultsPath = Join-Path $resultsResolved $Label
if (Test-Path -LiteralPath $runResultsPath -PathType Container) {
  Remove-Item -LiteralPath $runResultsPath -Recurse -Force -ErrorAction SilentlyContinue
}
[void](New-Item -ItemType Directory -Path $runResultsPath -Force)

$roguePreflight = Get-EnvBoolean -Name 'MIP_ROGUE_PREFLIGHT' -DefaultValue $true
if ($roguePreflight) {
  $detectScript = Join-Path $repoRoot 'tools' 'Detect-RogueLV.ps1'
  if (Test-Path -LiteralPath $detectScript -PathType Leaf) {
    try {
      $rogueOutPath = Join-Path $runResultsPath 'rogue-lv-pre.json'
      $rogueJson = & $detectScript -ResultsDir $resultsResolved -LookBackSeconds 180 -RetryCount 1 -Quiet -OutputPath $rogueOutPath
    } catch { $rogueJson = $null }
    $rogue = $null
    try { if ($rogueJson) { $rogue = $rogueJson | ConvertFrom-Json } } catch {}
    $expectedVer = [Environment]::GetEnvironmentVariable('MIP_EXPECTED_LV_VER'); if ([string]::IsNullOrWhiteSpace($expectedVer)) { $expectedVer = '2023' }
    $expectedArch = [Environment]::GetEnvironmentVariable('MIP_EXPECTED_ARCH'); if ([string]::IsNullOrWhiteSpace($expectedArch)) { $expectedArch = '64' }
    $wrong = @()
    if ($rogue -and $rogue.PSObject.Properties['liveDetails']) {
      $lvDetails = $rogue.liveDetails.labview
      foreach ($d in $lvDetails) {
        $path = $null; try { $path = $d.executablePath } catch {}
        if (-not $path) { continue }
        $isExpected = $false
        if ($path -match [Regex]::Escape($expectedVer)) {
          $is32 = ($path -match '(?i)Program Files \(x86\)')
          if ($expectedArch -eq '32' -and $is32) { $isExpected = $true }
          if ($expectedArch -eq '64' -and -not $is32) { $isExpected = $true }
        }
        if (-not $isExpected) { $wrong += $path }
      }
    }
    if ($wrong.Count -gt 0) {
      $autoClose = Get-EnvBoolean -Name 'MIP_AUTOCLOSE_WRONG_LV' -DefaultValue $false
      if ($autoClose) {
        $closeScript = Join-Path $repoRoot 'tools' 'Close-LabVIEW.ps1'
        foreach ($p in ($wrong | Sort-Object -Unique)) {
          try { & $closeScript -LabVIEWExePath $p -Provider 'labviewcli' | Out-Null } catch { Write-Warning ("Rogue preflight: failed to close '{0}': {1}" -f $p, $_.Exception.Message) }
        }
      } else {
        throw ("Rogue LV preflight found non-expected LabVIEW instances: {0}. Set MIP_AUTOCLOSE_WRONG_LV=1 to auto-close or disable preflight via MIP_ROGUE_PREFLIGHT=0." -f (($wrong | Sort-Object -Unique) -join ', '))
      }
    }
  }
}

$latestArtifacts = @(
  'compare-report.html',
  'cli-compare-report.html',
  'pester-summary.txt',
  'pester-summary.json',
  'pester-results.xml',
  'pester-artifacts.json',
  'pester-failures.json',
  'pester-leak-report.json',
  'results-index.html',
  'pester-selected-files.txt'
)
foreach ($artifact in $latestArtifacts) {
  $existing = Join-Path $resultsResolved $artifact
  Remove-Item -LiteralPath $existing -Force -ErrorAction SilentlyContinue
}

$viAnalyzerResult = $null
$viAnalyzerConfigResolved = $null
if (-not $SkipViAnalyzer.IsPresent) {
  if (-not $ViAnalyzerConfigPath) {
    $envAnalyzerConfig = [Environment]::GetEnvironmentVariable('MIP_VIANALYZER_CONFIG')
    if ($envAnalyzerConfig) { $ViAnalyzerConfigPath = $envAnalyzerConfig }
  }
  if ($ViAnalyzerConfigPath) {
    $viAnalyzerConfigResolved = (Resolve-Path -LiteralPath $ViAnalyzerConfigPath -ErrorAction Stop).Path
  }
}
if ($viAnalyzerConfigResolved) {
  $viAnalyzerScriptPath = Join-Path $repoRoot 'tools' 'icon-editor' 'Invoke-VIAnalyzer.ps1'
  if (-not (Test-Path -LiteralPath $viAnalyzerScriptPath -PathType Leaf)) {
    throw "Invoke-VIAnalyzer.ps1 not found at '$viAnalyzerScriptPath'."
  }
  $viAnalyzerOutputRoot = Join-Path $resultsResolved 'vi-analyzer'
  $viAnalyzerArgs = @{
    ConfigPath     = $viAnalyzerConfigResolved
    OutputRoot     = $viAnalyzerOutputRoot
    LabVIEWVersion = $ViAnalyzerVersion
    Bitness        = $ViAnalyzerBitness
    PassThru       = $true
  }

  $maxAnalyzerAttempts = if ($devModeRetryEnabled) { 2 } else { 1 }
  for ($attempt = 1; $attempt -le $maxAnalyzerAttempts; $attempt++) {
    try {
      $viAnalyzerResult = & $viAnalyzerScriptPath @viAnalyzerArgs
    } catch {
      throw "VI Analyzer gate failed: $($_.Exception.Message)"
    }
    $versionMismatchCount = 0
    if ($viAnalyzerResult -and $viAnalyzerResult.PSObject.Properties['versionMismatchCount']) {
      $versionMismatchCount = [int]$viAnalyzerResult.versionMismatchCount
    }
    if ($viAnalyzerResult -and $versionMismatchCount -gt 0) {
      $mismatchList = if ($viAnalyzerResult.PSObject.Properties['versionMismatches']) { $viAnalyzerResult.versionMismatches } else { @() }
      $mismatch = $mismatchList | Select-Object -First 1
      $viPath = if ($mismatch.path) { $mismatch.path } elseif ($mismatch.vi) { $mismatch.vi } else { 'unknown VI' }
      $message = "VI Analyzer could not load '{0}' because it was saved in a newer LabVIEW version. Analyzer ran under LabVIEW {1} ({2}-bit). Use a matching LabVIEW version or resave the VI before rerunning."
      throw ($message -f $viPath, $ViAnalyzerVersion, $ViAnalyzerBitness)
    }

    if ($viAnalyzerResult -and $viAnalyzerResult.brokenViCount -gt 0) {
      $brokenSummary = ($viAnalyzerResult.brokenVis | ForEach-Object { $_.vi } | Where-Object { $_ }) -join ', '
      if (-not $brokenSummary) { $brokenSummary = 'unknown VI(s)' }

      $canRetry = $devModeRetryEnabled -and -not $viAnalyzerRetryInfo.attempted -and ($attempt -lt $maxAnalyzerAttempts)
      if ($canRetry) {
        try {
          $targets = Get-MipDevModeTargets -RepoRoot $repoRoot -DefaultVersion $ViAnalyzerVersion -DefaultBitness $ViAnalyzerBitness -Operation $devModeOperationName
          $viAnalyzerRetryInfo.attempted = $true
          $viAnalyzerRetryInfo.targets = @{
            versions = $targets.Versions
            bitness  = $targets.Bitness
          }
          $recoveryResult = Invoke-MipDevModeRecovery -RepoRoot $repoRoot -Versions $targets.Versions -Bitness $targets.Bitness -Operation $devModeOperationName
          $viAnalyzerRetryInfo.succeeded = $true
          $viAnalyzerRetryInfo.recovery = $recoveryResult
          $viAnalyzerRetryInfo.note = "Dev-mode recovery executed at $($recoveryResult.timestamp)"
          if ($devModeRetryDelaySeconds -gt 0) {
            Start-Sleep -Seconds $devModeRetryDelaySeconds
          }
          Write-Warning ("VI Analyzer detected broken VIs (attempt {0}); dev-mode recovery triggered before retrying." -f $attempt)
          continue
        } catch {
          $viAnalyzerRetryInfo.note = $_.Exception.Message
          throw ("VI Analyzer detected broken VIs ({0}). Dev-mode recovery failed: {1}. Review {2}" -f $brokenSummary, $_.Exception.Message, $viAnalyzerResult.reportPath)
        }
      }

      if ($viAnalyzerRetryInfo.attempted -and -not $viAnalyzerRetryInfo.succeeded -and -not $viAnalyzerRetryInfo.note) {
        $viAnalyzerRetryInfo.note = 'Dev-mode recovery attempted but did not clear the analyzer findings.'
      }
      throw ("VI Analyzer detected broken VIs ({0}). Review {1}" -f $brokenSummary, $viAnalyzerResult.reportPath)
    }

    break
  }
}

# Env toggle for negative coverage
$originalSkipValue = [Environment]::GetEnvironmentVariable('MIP_SKIP_NEGATIVE')
$skipNegativeState = $null
try {
  if ($IncludeNegative.IsPresent) {
    Remove-Item Env:MIP_SKIP_NEGATIVE -ErrorAction SilentlyContinue
  } elseif ($SkipNegative.IsPresent) {
    Set-Item Env:MIP_SKIP_NEGATIVE '1'
  } elseif ($originalSkipValue) {
    # leave as-is
  } else {
    Set-Item Env:MIP_SKIP_NEGATIVE '1'
  }

  $invokeScript = Join-Path $repoRoot 'Invoke-PesterTests.ps1'
  $pesterArgs = @(
    '-TestsPath', $selectedTestsPath,
    '-IntegrationMode', 'include',
    '-ResultsPath', $runResultsPath
  )
  if ($AdditionalPesterArgs) {
    $pesterArgs += $AdditionalPesterArgs
  }

  if ($PSBoundParameters['Verbose']) {
    Write-Verbose ("Invoke-Pester args: {0}" -f ($pesterArgs -join ' '))
  }

  $pwshExe = (Get-Command pwsh).Source
  $commandString = "$pwshExe -File Invoke-PesterTests.ps1 -TestsPath {0} -IntegrationMode include -ResultsPath {1}" -f $selectedTestsPath, $runResultsPath
  $startArgs = @('-NoLogo','-NoProfile','-File',$invokeScript) + $pesterArgs
  $proc = Start-Process -FilePath $pwshExe -ArgumentList $startArgs -Wait -PassThru
  $exitCode = $proc.ExitCode
  if ($exitCode -ne 0) {
    throw "MissingInProject suite failed with exit code $exitCode."
  }

$skipNegativeState = Get-EnvBoolean -Name 'MIP_SKIP_NEGATIVE' -DefaultValue $true
$summaryPath = Join-Path $runResultsPath 'pester-summary.txt'
  $summaryContent = if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
    Get-Content -LiteralPath $summaryPath -Raw
  } else {
    "(pester-summary.txt not found)"
  }

  $compareReportPath = Join-Path $runResultsPath 'compare-report.html'
  $compareManifestPath = $null
  $compareSummaryPath = $null
  if (Test-Path -LiteralPath $compareReportPath -PathType Leaf) {
    if (Test-Path -LiteralPath $compareAnalyzerScript -PathType Leaf) {
      try {
        $compareManifestPath = & $compareAnalyzerScript `
          -ReportHtmlPath $compareReportPath `
          -RunDir $runResultsPath `
          -RootDir $resultsResolved
        $compareSummaryPath = Join-Path $resultsResolved 'compare-image-summary.json'
      } catch {
        if ($RequireCompareReport) {
          throw "Compare report analysis failed: $($_.Exception.Message)"
        } else {
          Write-Warning "Compare report analyzer failed: $($_.Exception.Message)"
        }
      }
    } elseif ($RequireCompareReport) {
      throw "Compare image analyzer missing at '$compareAnalyzerScript'."
    }
  } else {
    if ($RequireCompareReport) {
      # Optional fallback compare if explicit base/head provided via env
      $envBase = [Environment]::GetEnvironmentVariable('MIP_COMPARE_BASE')
      $envHead = [Environment]::GetEnvironmentVariable('MIP_COMPARE_HEAD')
      if ($envBase -and $envHead) {
        $runnerOverride = [Environment]::GetEnvironmentVariable('MIP_COMPARE_RUNNER')
        $runnerScript = if ($runnerOverride) { $runnerOverride } else { Join-Path $repoRoot 'tools' 'Run-HeadlessCompare.ps1' }
        if (Test-Path -LiteralPath $runnerScript -PathType Leaf) {
          try {
            & $runnerScript -BaseVi $envBase -HeadVi $envHead -OutputRoot $runResultsPath -RenderReport | Out-Null
          } catch {
            Write-Warning ("Fallback compare failed: {0}" -f $_.Exception.Message)
          }
        }
      }
      if (Test-Path -LiteralPath $compareReportPath -PathType Leaf) {
        if (Test-Path -LiteralPath $compareAnalyzerScript -PathType Leaf) {
          try {
            $compareManifestPath = & $compareAnalyzerScript `
              -ReportHtmlPath $compareReportPath `
              -RunDir $runResultsPath `
              -RootDir $resultsResolved
            $compareSummaryPath = Join-Path $resultsResolved 'compare-image-summary.json'
          } catch {
            Write-Warning ("Compare report analyzer (post-fallback) failed: {0}" -f $_.Exception.Message)
          }
        }
      } else {
        throw "compare-report.html not found under '$runResultsPath'."
      }
    }
  }

  if ($RequireCompareReport) {
    if (-not $compareManifestPath -or -not (Test-Path -LiteralPath $compareManifestPath -PathType Leaf)) {
      throw 'Compare image manifest not produced; failing gate.'
    }
    $manifest = Get-Content -LiteralPath $compareManifestPath -Raw | ConvertFrom-Json
    $totals = $manifest.totals
    $failures = @()
    if (-not $totals -or $totals.references -le 0) { $failures += 'no image references in report' }
    if (-not $totals -or $totals.existing -le 0) { $failures += 'no image files generated' }
    if ($totals.missing -gt 0) { $failures += "missing image files ($($totals.missing))" }
    if ($totals.zeroSize -gt 0) { $failures += "zero-byte image files ($($totals.zeroSize))" }
    if ($totals.stale -gt 0) { $failures += "stale image timestamps ($($totals.stale))" }
    if ($totals.largeSize -gt 0) { Write-Warning "Large images detected ($($totals.largeSize))" }
    $allRefs = if ($totals) { [int]$totals.references } else { 0 }
    $dupGroups = @()
    if ($manifest.duplicates) {
      $dupGroups = $manifest.duplicates
      foreach ($dup in $dupGroups) {
        if ($dup.count -ge $allRefs -and $allRefs -gt 0) {
          $failures += 'all images share identical content'
          break
        }
      }
    }
    if ($failures.Count -gt 0) {
      throw ("Compare report gate failed: {0}" -f ($failures -join '; '))
    }
  }

  $envLog = $null
  if (-not $LogPath) {
    $envLog = [Environment]::GetEnvironmentVariable('INVOCATION_LOG_PATH')
    if ($envLog) { $LogPath = $envLog }
  }

  $warningsText = ''

  $extraMetadata = @{
    resultsPath     = $runResultsPath
    includeNegative = $IncludeNegative.IsPresent
    skipNegative    = -not $IncludeNegative.IsPresent
  }
  if ($viAnalyzerResult) {
    $versionMismatchCount = if ($viAnalyzerResult.PSObject.Properties['versionMismatchCount']) { [int]$viAnalyzerResult.versionMismatchCount } else { 0 }
    $extraMetadata.viAnalyzer = @{
      reportPath     = $viAnalyzerResult.reportPath
      brokenViCount  = $viAnalyzerResult.brokenViCount
      runDir         = $viAnalyzerResult.runDir
      versionMismatchCount = $versionMismatchCount
      configPath     = $viAnalyzerConfigResolved
      labviewVersion = $ViAnalyzerVersion
      bitness        = $ViAnalyzerBitness
    }
    if ($viAnalyzerResult.configSourcePath) {
      $extraMetadata.viAnalyzer.configSourcePath = $viAnalyzerResult.configSourcePath
    }
    if ($versionMismatchCount -gt 0 -and $viAnalyzerResult.PSObject.Properties['versionMismatches']) {
      $extraMetadata.viAnalyzer.versionMismatches = $viAnalyzerResult.versionMismatches
    }
    if ($viAnalyzerRetryInfo.enabled -or $viAnalyzerRetryInfo.attempted) {
      $retryMeta = [ordered]@{
        enabled    = $viAnalyzerRetryInfo.enabled
        attempted  = $viAnalyzerRetryInfo.attempted
        succeeded  = $viAnalyzerRetryInfo.succeeded
        targets    = $viAnalyzerRetryInfo.targets
        delaySeconds = $devModeRetryDelaySeconds
        note       = $viAnalyzerRetryInfo.note
      }
      if ($viAnalyzerRetryInfo.recovery) {
        $retryMeta.recovery = $viAnalyzerRetryInfo.recovery
      }
      $extraMetadata.viAnalyzer.retry = $retryMeta
    }
  }
  if ($AdditionalPesterArgs) {
    $extraMetadata.additionalArgs = ($AdditionalPesterArgs -join ' ')
  }
  if ($envLog) {
    $extraMetadata.logPath = $envLog
  }
  if ($compareManifestPath) {
    $extraMetadata.compareImageManifest = $compareManifestPath
  }
  if ($compareSummaryPath -and (Test-Path -LiteralPath $compareSummaryPath -PathType Leaf)) {
    $extraMetadata.compareImageSummary = $compareSummaryPath
  }

  $reportArgs = @{
    Kind          = 'missing-in-project'
    Label         = $Label
    Command       = $commandString
    Summary       = $summaryContent.Trim()
    Warnings      = $warningsText
    TranscriptPath = $LogPath
    TelemetryPath = $summaryPath
    Aborted       = $false
    Extra         = $extraMetadata
  }
  $reportScript = Join-Path $repoRoot 'tools/report/Write-RunReport.ps1'
  $reportPath = & $reportScript @reportArgs
  if ($reportPath) {
    Write-Host ("MissingInProject report: {0}" -f $reportPath) -ForegroundColor DarkGray
  }

  foreach ($artifact in $latestArtifacts) {
    $source = Join-Path $runResultsPath $artifact
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      $destination = Join-Path $resultsResolved $artifact
      Copy-Item -LiteralPath $source -Destination $destination -Force
    }
  }

  $latestPointerPath = Join-Path $resultsResolved 'latest-run.json'
  $latestPointer = @{
    label = $Label
    runPath = $runResultsPath
    summaryPath = $summaryPath
    reportPath = $reportPath
    updatedAt = (Get-Date).ToString('o')
  }
  $latestPointer | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $latestPointerPath -Encoding utf8

  $indexPath = Join-Path $resultsResolved 'run-index.json'
  $existingIndex = @()
  if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    try {
      $existingIndex = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
    } catch {
      $existingIndex = @()
    }
  }
  if ($existingIndex -isnot [System.Collections.IEnumerable]) {
    $existingIndex = @()
  }
  $newEntry = [ordered]@{
    label      = $Label
    runPath    = $runResultsPath
    summary    = $summaryPath
    reportPath = $reportPath
    timestamp  = (Get-Date).ToString('o')
  }
  $indexList = @($newEntry)
  if ($existingIndex) {
    $indexList += $existingIndex
  }
  $maxEntries = 20
  if ($indexList.Count -gt $maxEntries) {
    $indexList = $indexList[0..($maxEntries - 1)]
  }
  $indexList | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $indexPath -Encoding utf8

  $sessionIndexPath = Join-Path $runResultsPath 'missing-in-project-session.json'
  $additionalArgsArray = if ($AdditionalPesterArgs) { @($AdditionalPesterArgs) } else { @() }
  $sessionPayload = [ordered]@{
    schema         = 'missing-in-project/run@v1'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    label          = $Label
    suite          = [ordered]@{
      testsPath      = $selectedTestsPath
      resultsRoot    = $runResultsPath
      summaryPath    = $summaryPath
      includeNegative = -not $skipNegativeState
      command        = $commandString
      additionalArgs = $additionalArgsArray
    }
    viAnalyzer     = [ordered]@{
      invoked        = [bool]$viAnalyzerConfigResolved
      configPath     = $viAnalyzerConfigResolved
      labviewVersion = $ViAnalyzerVersion
      bitness        = $ViAnalyzerBitness
      reportPath     = if ($viAnalyzerResult -and $viAnalyzerResult.PSObject.Properties['reportPath']) { $viAnalyzerResult.reportPath } else { $null }
      cliLogPath     = if ($viAnalyzerResult -and $viAnalyzerResult.PSObject.Properties['cliLogPath']) { $viAnalyzerResult.cliLogPath } else { $null }
      brokenViCount  = if ($viAnalyzerResult -and $viAnalyzerResult.PSObject.Properties['brokenViCount']) { [int]$viAnalyzerResult.brokenViCount } else { $null }
    }
    compare        = [ordered]@{
      requested     = $RequireCompareReport.IsPresent
      reportPath    = if (Test-Path -LiteralPath $compareReportPath -PathType Leaf) { $compareReportPath } else { $null }
      manifestPath  = $compareManifestPath
      summaryPath   = $compareSummaryPath
    }
    reports        = [ordered]@{
      missingInProject = $reportPath
      latestPointer    = $latestPointerPath
      runIndex         = $indexPath
    }
  }
  if ($viAnalyzerResult -and $viAnalyzerResult.PSObject.Properties['configSourcePath']) {
    $sessionPayload.viAnalyzer.configSourcePath = $viAnalyzerResult.configSourcePath
  }
  if ($viAnalyzerRetryInfo.enabled -or $viAnalyzerRetryInfo.attempted) {
    $sessionPayload.viAnalyzer.retry = [ordered]@{
      enabled   = $viAnalyzerRetryInfo.enabled
      attempted = $viAnalyzerRetryInfo.attempted
      succeeded = $viAnalyzerRetryInfo.succeeded
      note      = $viAnalyzerRetryInfo.note
      targets   = $viAnalyzerRetryInfo.targets
    }
  }
  $sessionPayload | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $sessionIndexPath -Encoding utf8
  Write-Host ("MissingInProject session index: {0}" -f $sessionIndexPath) -ForegroundColor DarkGray
}
finally {
  if ($originalSkipValue) {
    Set-Item Env:MIP_SKIP_NEGATIVE $originalSkipValue
  } else {
    Remove-Item Env:MIP_SKIP_NEGATIVE -ErrorAction SilentlyContinue
  }
}
  if ($compareManifestPath) {
    Copy-Item -LiteralPath $compareManifestPath -Destination (Join-Path $resultsResolved 'compare-image-manifest.json') -Force -ErrorAction SilentlyContinue
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
