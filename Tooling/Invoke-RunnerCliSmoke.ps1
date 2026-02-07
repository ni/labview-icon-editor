param(
  [string]$RepoRoot,
  [string]$RunnerCliPath,
  [string]$FixturePath,
  [string]$SummaryPath,
  [switch]$UseDotnetRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$RootHint)

  if (-not [string]::IsNullOrWhiteSpace($RootHint)) {
    return (Resolve-Path -Path $RootHint).Path
  }

  try {
    $gitRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
      return $gitRoot.Trim()
    }
  } catch {
    Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
  }

  return (Resolve-Path -Path (Split-Path -Path $PSScriptRoot -Parent)).Path
}

function Get-RunnerCliRid {
  if ($IsWindows) { return 'win-x64' }
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
  if ($IsMacOS) {
    if ($arch -eq [System.Runtime.InteropServices.Architecture]::Arm64) { return 'osx-arm64' }
    return 'osx-x64'
  }
  if ($arch -eq [System.Runtime.InteropServices.Architecture]::Arm64) { return 'linux-arm64' }
  return 'linux-x64'
}

function Resolve-RunnerCliPath {
  param(
    [string]$Root,
    [string]$PathHint
  )

  if (-not [string]::IsNullOrWhiteSpace($PathHint)) {
    $resolved = Resolve-Path -Path $PathHint -ErrorAction Stop
    return $resolved.Path
  }

  $rid = Get-RunnerCliRid
  $exeName = if ($IsWindows) { 'runner-cli.exe' } else { 'runner-cli' }

  $candidates = @(
    (Join-Path $Root "Tooling/runner-cli/publish/$rid/$exeName"),
    (Join-Path $Root "Tooling/runner-cli/RunnerCli/bin/Release/net8.0/$rid/$exeName")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -Path $candidate) {
      return (Resolve-Path -Path $candidate).Path
    }
  }

  return $null
}

function Invoke-RunnerCli {
  param(
    [string]$Root,
    [string]$CliPath,
    [switch]$DotnetRun,
    [string[]]$Arguments
  )

  if ($DotnetRun) {
    $projectPath = Join-Path $Root 'Tooling/runner-cli/RunnerCli/RunnerCli.csproj'
    if (-not (Test-Path -Path $projectPath)) {
      throw "Runner CLI project not found at $projectPath"
    }
    Write-Host "Running: dotnet run --project $projectPath --configuration Release -- $($Arguments -join ' ')"
    return & dotnet run --project $projectPath --configuration Release -- @Arguments 2>&1 | Out-String
  }

  if (-not $CliPath) {
    throw "Runner CLI path not resolved. Provide -RunnerCliPath or use -UseDotnetRun."
  }

  Write-Host "Running: $CliPath $($Arguments -join ' ')"
  return & $CliPath @Arguments 2>&1 | Out-String
}

$resolvedRepo = Resolve-RepoRoot -RootHint $RepoRoot
if (-not (Test-Path -Path $resolvedRepo)) {
  throw "Repo root not found at $resolvedRepo"
}

$fixture = if ([string]::IsNullOrWhiteSpace($FixturePath)) {
  Join-Path $resolvedRepo 'Tooling/pylavi/fixtures/pylavi-offenders.sample.json'
} else {
  $FixturePath
}

if (-not (Test-Path -Path $fixture)) {
  $fallbackFixture = $null
  try {
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
      $fallbackFixture = Join-Path ($gitRoot.Trim()) 'Tooling/pylavi/fixtures/pylavi-offenders.sample.json'
    }
  } catch {
    $fallbackFixture = $null
  }

  if ($fallbackFixture -and (Test-Path -Path $fallbackFixture)) {
    Write-Warning ("Pylavi fixture not found under repo root; using fallback fixture at {0}" -f $fallbackFixture)
    $fixture = $fallbackFixture
  } else {
    throw "Pylavi fixture not found at $fixture"
  }
}

$summaryPathValue = if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
  Join-Path $env:TEMP 'pylavi-summary.json'
} else {
  $SummaryPath
}

$cliPath = Resolve-RunnerCliPath -Root $resolvedRepo -PathHint $RunnerCliPath
$useDotnet = $UseDotnetRun.IsPresent -or -not $cliPath

Write-Host "Repo root: $resolvedRepo"
Write-Host "Fixture: $fixture"
Write-Host "Summary: $summaryPathValue"
Write-Host "Runner CLI: $($cliPath ?? '[dotnet run]')"

$versionJson = Invoke-RunnerCli -Root $resolvedRepo -CliPath $cliPath -DotnetRun:$useDotnet -Arguments @(
  'version-gate', '--repo-root', $resolvedRepo, '--json'
)

$version = $versionJson | ConvertFrom-Json
if (-not $version.Year) { throw 'version-gate JSON missing Year' }
if (-not $version.NumericVersion) { throw 'version-gate JSON missing NumericVersion' }

$summaryJson = Invoke-RunnerCli -Root $resolvedRepo -CliPath $cliPath -DotnetRun:$useDotnet -Arguments @(
  'pylavi', 'summarize', '--path', $fixture, '--json', '--output-path', $summaryPathValue
)

$report = $summaryJson | ConvertFrom-Json
if (-not $report.label) { throw 'pylavi summarize JSON missing label' }
if ($report.total_fails -lt 1) { throw 'pylavi summarize JSON missing total_fails' }
if (-not $report.top_offenders -or $report.top_offenders.Count -lt 1) { throw 'pylavi summarize JSON missing top_offenders' }
if (-not $report.top_absolute_offenders -or $report.top_absolute_offenders.Count -lt 1) { throw 'pylavi summarize JSON missing top_absolute_offenders' }

if (-not (Test-Path -Path $summaryPathValue)) {
  throw "pylavi summarize output file not found at $summaryPathValue"
}

$summaryOutput = Get-Content -Path $summaryPathValue -Raw | ConvertFrom-Json
if (-not $summaryOutput.label) { throw 'pylavi summarize output missing label' }
if (-not $summaryOutput.file -or ($summaryOutput.file -notlike '*pylavi-offenders.sample.json')) {
  throw 'pylavi summarize output missing file path'
}
if (-not $summaryOutput.has_findings) { throw 'pylavi summarize output missing has_findings' }

Write-Host 'Runner CLI smoke test passed.'
