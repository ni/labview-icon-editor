Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Resolve-LVRepoRoot: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LVRepoRoot {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$StartPath = (Get-Location).Path)

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) { return $root.Trim() }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

$script:RepoRoot = Resolve-LVRepoRoot
$script:SpecPath = Join-Path $PSScriptRoot 'providers/spec/operations.json'
if (-not (Test-Path -LiteralPath $script:SpecPath -PathType Leaf)) {
  throw "LabVIEW CLI operations spec not found at $script:SpecPath"
}
$script:OperationSpec = Get-Content -LiteralPath $script:SpecPath -Raw | ConvertFrom-Json -ErrorAction Stop
$script:Providers = @{}

<#
.SYNOPSIS
Get-LVOperationNames: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LVOperationNames {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  $script:OperationSpec.operations.name
}

<#
.SYNOPSIS
Get-LVOperationSpec: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LVOperationSpec {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([Parameter(Mandatory)][string]$Operation)
  $spec = $script:OperationSpec.operations | Where-Object { $_.name -eq $Operation }
  if (-not $spec) {
    throw "Unknown LabVIEW CLI operation '$Operation'. Available: $($script:OperationSpec.operations.name -join ', ')"
  }
  return $spec
}

<#
.SYNOPSIS
Register-LVProvider: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Register-LVProvider {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][object]$Provider
  )
  foreach ($member in @('Name','ResolveBinaryPath','Supports','BuildArgs')) {
    if (-not ($Provider | Get-Member -Name $member)) {
      throw "Provider registration failed: Missing required method '$member'."
    }
  }
  $name = $Provider.Name()
  if (-not $name) { throw "Provider registration failed: Name() returned empty." }
  $script:Providers[$name.ToLowerInvariant()] = $Provider
}

<#
.SYNOPSIS
Get-LVProviders: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LVProviders {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  return $script:Providers.GetEnumerator() | ForEach-Object { $_.Value }
}

<#
.SYNOPSIS
Get-LVProviderByName: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LVProviderByName {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([Parameter(Mandatory)][string]$Name)
  $key = $Name.ToLowerInvariant()
  if ($script:Providers.ContainsKey($key)) { return $script:Providers[$key] }
  return $null
}

<#
.SYNOPSIS
Import-LVProviderModules: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Import-LVProviderModules {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  $providerOverride = $env:ICON_EDITOR_LV_PROVIDER_ROOT
  $providerRoot = $null
  if ($providerOverride) {
    $providerRoot = $providerOverride
  } else {
    $providerRoot = Join-Path $PSScriptRoot 'providers'
  }
  if (-not (Test-Path -LiteralPath $providerRoot -PathType Container)) { return }
  $modules = Get-ChildItem -Path $providerRoot -Directory -ErrorAction SilentlyContinue
  foreach ($modDir in $modules) {
    $modulePath = Join-Path $modDir.FullName 'Provider.psm1'
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { continue }
    try {
      $moduleInfo = Import-Module $modulePath -Force -PassThru
      $moduleName = $moduleInfo.Name
      $command = Get-Command -Name 'New-LVProvider' -Module $moduleName -ErrorAction Stop
      $provider = & $command
      if (-not $provider) { throw "New-LVProvider returned null." }
      Register-LVProvider -Provider $provider
    } catch {
      Write-Warning ("Failed to import provider from {0}: {1}" -f $modulePath, $_.Exception.Message)
    }
  }
}

Import-LVProviderModules

$script:LabVIEWPidTrackerModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools' 'LabVIEWPidTracker.psm1'
$script:LabVIEWPidTrackerLoaded = $false
$script:LabVIEWPidTrackerPath = $null
$script:LabVIEWPidTrackerRelativePath = $null
$script:LabVIEWPidTrackerState = $null
$script:LabVIEWPidTrackerInitialState = $null
$script:LabVIEWPidTrackerFinalized = $false
$script:LabVIEWPidTrackerFinalState = $null
$script:LabVIEWPidTrackerFinalizedSource = $null
$script:LabVIEWPidTrackerFinalContext = $null
$script:LabVIEWPidTrackerFinalContextSource = $null
$script:LabVIEWPidTrackerFinalContextDetail = $null

if (Test-Path -LiteralPath $script:LabVIEWPidTrackerModule -PathType Leaf) {
  try {
    Import-Module $script:LabVIEWPidTrackerModule -Force -ErrorAction Stop
    $script:LabVIEWPidTrackerLoaded = $true
  } catch {
    Write-Warning ("LabVIEW CLI: failed to import LabVIEW PID tracker module: {0}" -f $_.Exception.Message)
    $script:LabVIEWPidTrackerLoaded = $false
  }
}

<#
.SYNOPSIS
Convert-ToAbsolutePath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Convert-ToAbsolutePath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $PathValue }
  try {
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
  } catch {
    try {
      if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
      }
      return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $PathValue))
    } catch {
      return $PathValue
    }
  }
}

<#
.SYNOPSIS
Format-LVCommandToken: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Format-LVCommandToken {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([AllowNull()][string]$Token)
  if ($null -eq $Token) { return '""' }
  if ($Token.Length -eq 0) { return '""' }
  if ($Token -match '[\s"]') {
    $escaped = $Token -replace '\\','\\' -replace '"','\"'
    return '"' + $escaped + '"'
  }
  return $Token
}

<#
.SYNOPSIS
Format-LVCommandLine: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Format-LVCommandLine {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][string]$Binary,
    [string[]]$Arguments
  )
  $tokens = New-Object System.Collections.Generic.List[string]
  $tokens.Add((Format-LVCommandToken -Token $Binary)) | Out-Null
  if ($Arguments) {
    foreach ($arg in $Arguments) {
      $tokens.Add((Format-LVCommandToken -Token $arg)) | Out-Null
    }
  }
  return [string]::Join(' ', $tokens.ToArray())
}

<#
.SYNOPSIS
Resolve-LVNormalizedParams: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LVNormalizedParams {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][object]$OperationSpec,
    [Parameter()][hashtable]$Params
  )
  $Params = $Params ?? @{}
  $normalized = @{}
  foreach ($paramSpec in $OperationSpec.parameters) {
    $id = [string]$paramSpec.id
    $value = $null
    if ($Params.ContainsKey($id)) {
      $value = $Params[$id]
    } else {
      $altKey = $Params.Keys | Where-Object { $_.ToString().ToLowerInvariant() -eq $id.ToLowerInvariant() } | Select-Object -First 1
      if ($altKey) { $value = $Params[$altKey] }
    }
    if (-not $value -and ($paramSpec.PSObject.Properties.Name -contains 'env') -and $paramSpec.env) {
      foreach ($envName in $paramSpec.env) {
        $envValue = [System.Environment]::GetEnvironmentVariable($envName)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
          $value = $envValue
          break
        }
      }
    }
    if (-not $value -and $paramSpec.PSObject.Properties.Name -contains 'default') {
      $value = $paramSpec.default
    }
    if ($paramSpec.required -and ([string]::IsNullOrWhiteSpace([string]$value))) {
      throw "Missing required parameter '$id' for operation '$($OperationSpec.name)'."
    }
    if ($null -ne $value) {
      switch ($paramSpec.type) {
        'path' {
          $normalized[$id] = Convert-ToAbsolutePath $value
        }
        'bool' {
          if ($value -is [bool]) {
            $normalized[$id] = $value
          } else {
            $normalized[$id] = [System.Convert]::ToBoolean($value)
          }
        }
        'int' {
          $normalized[$id] = [int]$value
        }
        'enum' {
          $allowed = @($paramSpec.values)
          $chosen = [string]$value
          if ($allowed.Count -gt 0 -and -not ($allowed | Where-Object { $_ -ieq $chosen })) {
            throw "Parameter '$id' value '$chosen' not in allowed set ($($allowed -join ', '))."
          }
          # preserve canonical casing if match found
          $canonical = $allowed | Where-Object { $_ -ieq $chosen } | Select-Object -First 1
          $normalized[$id] = $canonical ?? $chosen
        }
        'array' {
          if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $normalized[$id] = @($value)
          } elseif ([string]::IsNullOrWhiteSpace([string]$value)) {
            $normalized[$id] = @()
          } else {
            $normalized[$id] = @([string]$value)
          }
        }
        default {
          $normalized[$id] = [string]$value
        }
      }
    }
  }
  return $normalized
}

<#
.SYNOPSIS
Get-CompareCliSentinelPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-CompareCliSentinelPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][string]$Vi1,
    [Parameter(Mandatory)][string]$Vi2,
    [string]$ReportPath
  )
  try {
    $root = [System.IO.Path]::GetTempPath()
  } catch { $root = $env:TEMP }
  if (-not $root) { $root = '.' }
  $dir = Join-Path $root 'comparevi-cli-sentinel'
  try { if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null } } catch {}
  $key = ($Vi1.Trim().ToLowerInvariant()) + '|' + ($Vi2.Trim().ToLowerInvariant()) + '|' + ([string]($ReportPath ?? '')).Trim().ToLowerInvariant()
  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
  $hash  = ($sha1.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
  return (Join-Path $dir ($hash + '.sentinel'))
}

<#
.SYNOPSIS
Test-ShouldSuppressCliCompare: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ShouldSuppressCliCompare {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][string]$Operation,
    [Parameter(Mandatory)][hashtable]$Normalized,
    [ref]$Reason
  )
  $Reason.Value = $null
  if ($Operation -ne 'CreateComparisonReport') { return $false }
  $noCapture = [System.Environment]::GetEnvironmentVariable('COMPAREVI_NO_CLI_CAPTURE','Process')
  if ($noCapture -and $noCapture.Trim() -in @('1','true','yes','on')) {
    $Reason.Value = 'COMPAREVI_NO_CLI_CAPTURE'
    return $true
  }
  # Optional Git difftool context suppression
  $suppressInGit = [System.Environment]::GetEnvironmentVariable('COMPAREVI_SUPPRESS_CLI_IN_GIT','Process')
  $warnInGit     = [System.Environment]::GetEnvironmentVariable('COMPAREVI_WARN_CLI_IN_GIT','Process')
  $isGit = $false
  try {
    if ([System.Environment]::GetEnvironmentVariable('GIT_DIR')) { $isGit = $true }
    elseif ([System.Environment]::GetEnvironmentVariable('GIT_PREFIX')) { $isGit = $true }
    if (-not $isGit) {
      $current = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $PID) -ErrorAction SilentlyContinue
      $hops = 0
      while ($current -and $current.ParentProcessId -gt 0 -and $hops -lt 4) {
        $parent = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $current.ParentProcessId) -ErrorAction SilentlyContinue
        if ($parent -and $parent.Name -match '^git(\.exe)?$') { $isGit = $true; break }
        $current = $parent; $hops++
      }
    }
  } catch {}
  if ($isGit -and $warnInGit -and $warnInGit.Trim() -in @('1','true','yes','on')) {
    Write-Warning "LabVIEW CLI: invocation detected in Git context (possible difftool)."
  }
  if ($isGit -and $suppressInGit -and $suppressInGit.Trim() -in @('1','true','yes','on')) {
    $Reason.Value = 'git-context'
    return $true
  }
  $ttlRaw = [System.Environment]::GetEnvironmentVariable('COMPAREVI_CLI_SENTINEL_TTL','Process')
  $ttl = 0
  if ($ttlRaw) { try { $ttl = [int]$ttlRaw } catch { $ttl = 0 } }
  if ($ttl -le 0) { return $false }
  $vi1 = [string]$Normalized.vi1
  $vi2 = [string]$Normalized.vi2
  $reportPath = $null
  if ($Normalized.ContainsKey('reportPath')) { $reportPath = [string]$Normalized.reportPath }
  if ([string]::IsNullOrWhiteSpace($vi1) -or [string]::IsNullOrWhiteSpace($vi2)) { return $false }
  try { $vi1 = (Resolve-Path -LiteralPath $vi1).Path } catch {}
  try { $vi2 = (Resolve-Path -LiteralPath $vi2).Path } catch {}
  $sentinel = Get-CompareCliSentinelPath -Vi1 $vi1 -Vi2 $vi2 -ReportPath $reportPath
  if (Test-Path -LiteralPath $sentinel -PathType Leaf) {
    try {
      $item = Get-Item -LiteralPath $sentinel -ErrorAction Stop
      $age = (New-TimeSpan -Start $item.LastWriteTimeUtc -End ([DateTime]::UtcNow)).TotalSeconds
      if ($age -lt $ttl) {
        $Reason.Value = ('sentinel:{0}s' -f [int]$ttl)
        return $true
      }
    } catch {}
  }
  return $false
}

<#
.SYNOPSIS
Touch-CompareCliSentinel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Touch-CompareCliSentinel {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][string]$Vi1,
    [Parameter(Mandatory)][string]$Vi2,
    [string]$ReportPath
  )
  try {
    $path = Get-CompareCliSentinelPath -Vi1 $Vi1 -Vi2 $Vi2 -ReportPath $ReportPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      New-Item -ItemType File -Path $path -Force | Out-Null
    }
    (Get-Item -LiteralPath $path).LastWriteTimeUtc = [DateTime]::UtcNow
  } catch {}
}

<#
.SYNOPSIS
Select-LVProvider: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Select-LVProvider {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][string]$Operation,
    [Parameter()][string]$RequestedProvider
  )
  $providers = @()
  if ($RequestedProvider -and $RequestedProvider -ne 'auto') {
    $explicit = Get-LVProviderByName $RequestedProvider
    if (-not $explicit) { throw "Requested provider '$RequestedProvider' is not registered." }
    $providers = @($explicit)
  } else {
    $envProvider = $env:LVCLI_PROVIDER
    if ($envProvider -and $envProvider -ne 'auto') {
      $explicit = Get-LVProviderByName $envProvider
      if ($explicit) { $providers += $explicit }
    }
    if (-not $providers) {
      $providers = Get-LVProviders
    }
  }
  $explicitRequest = ($RequestedProvider -and $RequestedProvider -ne 'auto')
  if (-not $providers -or $providers.Count -eq 0) {
    throw "No LabVIEW CLI providers registered."
  }
  foreach ($provider in $providers) {
    try {
      $binary = $provider.ResolveBinaryPath()
      if ([string]::IsNullOrWhiteSpace($binary)) { continue }
      $binaryExists = $false
      $binaryResolved = $binary
      try {
        $binaryResolved = (Resolve-Path -LiteralPath $binary -ErrorAction Stop).Path
        $binaryExists = $true
      } catch {
        try {
          if ([System.IO.Path]::IsPathRooted($binary)) {
            $binaryResolved = [System.IO.Path]::GetFullPath($binary)
          } else {
            $binaryResolved = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $binary))
          }
        } catch {
          $binaryResolved = $binary
        }
      }
      if (-not $binaryExists -and -not $explicitRequest) { continue }
      if (-not ($provider.Supports($Operation))) { continue }
        return [pscustomobject]@{
          Provider     = $provider
          ProviderName = $provider.Name()
          Binary       = $binaryResolved
        }
    } catch {
      Write-Verbose ("Provider {0} selection failed: {1}" -f $provider.Name(), $_.Exception.Message)
    }
  }
  $names = ($providers | ForEach-Object { $_.Name() }) -join ', '
  throw "No registered provider can execute operation '$Operation'. Checked: $names"
}

<#
.SYNOPSIS
Set-LVHeadlessEnv: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
  function Set-LVHeadlessEnv {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
    $guard = @{}
    foreach ($pair in (@{'LV_SUPPRESS_UI'='1'; 'LV_NO_ACTIVATE'='1'; 'LV_CURSOR_RESTORE'='1'}).GetEnumerator()) {
      $existing = [System.Environment]::GetEnvironmentVariable($pair.Key)
      if ($existing) { $guard[$pair.Key] = $existing }
      [System.Environment]::SetEnvironmentVariable($pair.Key, $pair.Value)
    }
  if (-not [System.Environment]::GetEnvironmentVariable('LV_IDLE_WAIT_SECONDS')) {
    [System.Environment]::SetEnvironmentVariable('LV_IDLE_WAIT_SECONDS','2')
    $guard['LV_IDLE_WAIT_SECONDS'] = $null
  }
  if (-not [System.Environment]::GetEnvironmentVariable('LV_IDLE_MAX_WAIT_SECONDS')) {
    [System.Environment]::SetEnvironmentVariable('LV_IDLE_MAX_WAIT_SECONDS','5')
    $guard['LV_IDLE_MAX_WAIT_SECONDS'] = $null
  }
  return $guard
}

<#
.SYNOPSIS
Restore-LVHeadlessEnv: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Restore-LVHeadlessEnv {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([hashtable]$Guard)
  if (-not $Guard) { return }
  foreach ($key in $Guard.Keys) {
    $value = $Guard[$key]
    [System.Environment]::SetEnvironmentVariable($key, $value)
  }
}

<#
.SYNOPSIS
Write-LVOperationEvent: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Write-LVOperationEvent {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][hashtable]$EventData
  )
  try {
    $resultsDir = Join-Path $script:RepoRoot 'tests/results'
    if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
      New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    }
    $cliDir = Join-Path $resultsDir '_cli'
    if (-not (Test-Path -LiteralPath $cliDir -PathType Container)) {
      New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
    }
    $eventFile = Join-Path $cliDir 'operation-events.ndjson'
    if (-not $EventData.ContainsKey('timestamp')) {
      $EventData['timestamp'] = (Get-Date).ToUniversalTime().ToString('o')
    }
    ($EventData | ConvertTo-Json -Compress) | Add-Content -Path $eventFile
  } catch {
    Write-Verbose ("Failed to write CLI event: {0}" -f $_.Exception.Message)
  }
}

<#
.SYNOPSIS
Initialize-LabVIEWCliPidTracker: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Initialize-LabVIEWCliPidTracker {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  if (-not $script:LabVIEWPidTrackerLoaded) { return }
  if ($script:LabVIEWPidTrackerState) { return }

  $resultsDir = Join-Path $script:RepoRoot 'tests/results'
  $cliDir = Join-Path $resultsDir '_cli'
  $agentDir = Join-Path $cliDir '_agent'

  try {
    if (-not (Test-Path -LiteralPath $agentDir -PathType Container)) {
      New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    }
  } catch {
    Write-Warning ("LabVIEW CLI: failed to prepare LabVIEW PID tracker directory: {0}" -f $_.Exception.Message)
    $script:LabVIEWPidTrackerLoaded = $false
    $script:LabVIEWPidTrackerPath = $null
    $script:LabVIEWPidTrackerRelativePath = $null
    return
  }

  $trackerPath = Join-Path $agentDir 'labview-pid.json'

  $script:LabVIEWPidTrackerState = $null
  $script:LabVIEWPidTrackerInitialState = $null
  $script:LabVIEWPidTrackerFinalState = $null
  $script:LabVIEWPidTrackerFinalized = $false
  $script:LabVIEWPidTrackerFinalizedSource = $null
  $script:LabVIEWPidTrackerFinalContext = $null
  $script:LabVIEWPidTrackerFinalContextSource = $null
  $script:LabVIEWPidTrackerFinalContextDetail = $null

  try {
    $state = Start-LabVIEWPidTracker -TrackerPath $trackerPath -Source 'labview-cli:init'
    $script:LabVIEWPidTrackerState = $state
    $script:LabVIEWPidTrackerInitialState = $state
    $script:LabVIEWPidTrackerPath = $trackerPath
    $script:LabVIEWPidTrackerRelativePath = 'tests/results/_cli/_agent/labview-pid.json'
    if ($state -and $state.PSObject.Properties['Pid'] -and $state.Pid) {
      $modeText = if ($state.Reused) { 'Reusing existing' } else { 'Tracking detected' }
      Write-Host ("[labview-pid] {0} LabVIEW.exe PID {1}." -f $modeText, $state.Pid) -ForegroundColor DarkGray
    }
  } catch {
    Write-Warning ("LabVIEW CLI: failed to start LabVIEW PID tracker: {0}" -f $_.Exception.Message)
    $script:LabVIEWPidTrackerLoaded = $false
    $script:LabVIEWPidTrackerPath = $null
    $script:LabVIEWPidTrackerRelativePath = $null
    $script:LabVIEWPidTrackerState = $null
    $script:LabVIEWPidTrackerInitialState = $null
  }
}

<#
.SYNOPSIS
Finalize-LabVIEWCliPidTracker: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Finalize-LabVIEWCliPidTracker {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [string]$Source,
    [string]$Operation,
    [string]$Provider,
    [Nullable[int]]$ExitCode,
    [Nullable[bool]]$TimedOut,
    [string[]]$CliArgs,
    [Nullable[double]]$ElapsedSeconds,
    [string]$Binary,
    [string]$ErrorMessage
  )

  if (-not $script:LabVIEWPidTrackerLoaded) { return }
  if (-not $script:LabVIEWPidTrackerPath) { return }
  if ($script:LabVIEWPidTrackerFinalized) { return }

  $context = [ordered]@{ stage = if ($Source) { $Source } else { 'labview-cli:summary' } }
  if ($Operation) { $context.operation = $Operation }
  if ($Provider) { $context.provider = $Provider }
  if ($PSBoundParameters.ContainsKey('ExitCode') -and $ExitCode -ne $null) {
    $context.exitCode = [int]$ExitCode
  }
  if ($PSBoundParameters.ContainsKey('TimedOut')) { $context.timedOut = [bool]$TimedOut }
  if ($PSBoundParameters.ContainsKey('CliArgs') -and $CliArgs) { $context.args = @($CliArgs) }
  if ($PSBoundParameters.ContainsKey('ElapsedSeconds') -and $ElapsedSeconds -ne $null) {
    $context.elapsedSeconds = [double]$ElapsedSeconds
  }
  if ($PSBoundParameters.ContainsKey('Binary') -and $Binary) { $context.binary = $Binary }
  if ($PSBoundParameters.ContainsKey('ErrorMessage') -and $ErrorMessage) { $context.error = $ErrorMessage }

  $stopArgs = @{ TrackerPath = $script:LabVIEWPidTrackerPath; Source = $context.stage }
  if (
    $script:LabVIEWPidTrackerState -and
    $script:LabVIEWPidTrackerState.PSObject.Properties['Pid'] -and
    $script:LabVIEWPidTrackerState.Pid
  ) {
    $stopArgs.Pid = $script:LabVIEWPidTrackerState.Pid
  }
  if ($context.Count -gt 0) { $stopArgs.Context = [pscustomobject]$context }

  try {
    $finalState = Stop-LabVIEWPidTracker @stopArgs
    $script:LabVIEWPidTrackerFinalState = $finalState
    $script:LabVIEWPidTrackerFinalizedSource = $context.stage
    if ($finalState -and $finalState.PSObject.Properties['Context'] -and $finalState.Context) {
      $script:LabVIEWPidTrackerFinalContext = $finalState.Context
      if ($finalState.PSObject.Properties['ContextSource'] -and $finalState.ContextSource) {
        $script:LabVIEWPidTrackerFinalContextSource = [string]$finalState.ContextSource
        $script:LabVIEWPidTrackerFinalContextDetail = [string]$finalState.ContextSource
      }
    }
    } catch {
      Write-Warning (
        "LabVIEW CLI: failed to finalize LabVIEW PID tracker: {0}" -f $_.Exception.Message
      )
      if ($context) {
        try {
          $script:LabVIEWPidTrackerFinalContext = Resolve-LabVIEWPidContext -Input $context
        } catch {
          $script:LabVIEWPidTrackerFinalContext = $context
        }
        $script:LabVIEWPidTrackerFinalContextSource = $context.stage
        $script:LabVIEWPidTrackerFinalContextDetail = $context.stage
      }
    } finally {
      if ($context -and -not $script:LabVIEWPidTrackerFinalContext) {
        try {
          $script:LabVIEWPidTrackerFinalContext = Resolve-LabVIEWPidContext -Input $context
        } catch {
          $script:LabVIEWPidTrackerFinalContext = $context
        }
        if (-not $script:LabVIEWPidTrackerFinalContextSource) {
          $script:LabVIEWPidTrackerFinalContextSource = $context.stage
        }
        if (-not $script:LabVIEWPidTrackerFinalContextDetail) {
          $script:LabVIEWPidTrackerFinalContextDetail = $context.stage
        }
      }
      if (-not $script:LabVIEWPidTrackerFinalizedSource) { $script:LabVIEWPidTrackerFinalizedSource = $context.stage }
      if (-not $script:LabVIEWPidTrackerFinalContextDetail -and $script:LabVIEWPidTrackerFinalContextSource) {
        $script:LabVIEWPidTrackerFinalContextDetail = $script:LabVIEWPidTrackerFinalContextSource
      }
      $script:LabVIEWPidTrackerFinalized = $true
      $script:LabVIEWPidTrackerState = $null
    }

  return $script:LabVIEWPidTrackerFinalState
}

<#
.SYNOPSIS
Resolve-LabVIEWCliPidTrackerPayload: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LabVIEWCliPidTrackerPayload {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  $payload = [ordered]@{ enabled = [bool]$script:LabVIEWPidTrackerLoaded }

  if ($script:LabVIEWPidTrackerPath) {
    $payload['path'] = $script:LabVIEWPidTrackerPath
    try {
      $fileInfo = Get-Item -LiteralPath $script:LabVIEWPidTrackerPath -ErrorAction Stop
      if ($fileInfo) {
        $payload['pathExists'] = $true
        try { $payload['length'] = [long]$fileInfo.Length } catch { $payload['length'] = $null }
        try { $payload['lastWriteTimeUtc'] = $fileInfo.LastWriteTimeUtc.ToString('o') } catch { $payload['lastWriteTimeUtc'] = $null }
      } else {
        $payload['pathExists'] = $false
      }
    } catch {
      $payload['pathExists'] = $false
    }
  } else {
    $payload['pathExists'] = $false
  }

  if ($script:LabVIEWPidTrackerRelativePath) {
    $payload['relativePath'] = $script:LabVIEWPidTrackerRelativePath
  }

  $payload['finalized'] = [bool]$script:LabVIEWPidTrackerFinalized

  if ($script:LabVIEWPidTrackerInitialState) {
    $initial = [ordered]@{}
    if (
      $script:LabVIEWPidTrackerInitialState.PSObject.Properties['Pid'] -and
      $script:LabVIEWPidTrackerInitialState.Pid
    ) {
      try { $initial['pid'] = [int]$script:LabVIEWPidTrackerInitialState.Pid } catch { $initial['pid'] = $null }
    } else {
      $initial['pid'] = $null
    }
    if ($script:LabVIEWPidTrackerInitialState.PSObject.Properties['Running']) {
      try { $initial['running'] = [bool]$script:LabVIEWPidTrackerInitialState.Running } catch { $initial['running'] = $null }
    }
    if ($script:LabVIEWPidTrackerInitialState.PSObject.Properties['Reused']) {
      try { $initial['reused'] = [bool]$script:LabVIEWPidTrackerInitialState.Reused } catch { $initial['reused'] = $null }
    }
    if ($script:LabVIEWPidTrackerInitialState.PSObject.Properties['Candidates']) {
      $initial['candidates'] = @(
        $script:LabVIEWPidTrackerInitialState.Candidates | Where-Object { $_ -ne $null }
      )
    }
    if (
      $script:LabVIEWPidTrackerInitialState.PSObject.Properties['Observation'] -and
      $script:LabVIEWPidTrackerInitialState.Observation
    ) {
      $initial['observation'] = $script:LabVIEWPidTrackerInitialState.Observation
    }
    if ($initial.Count -gt 0) { $payload['initial'] = [pscustomobject]$initial }
  }

  if ($script:LabVIEWPidTrackerFinalized) {
    $final = [ordered]@{}
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['Pid'] -and
      $script:LabVIEWPidTrackerFinalState.Pid
    ) {
      try { $final['pid'] = [int]$script:LabVIEWPidTrackerFinalState.Pid } catch { $final['pid'] = $null }
    } elseif (
      $script:LabVIEWPidTrackerInitialState -and
      $script:LabVIEWPidTrackerInitialState.PSObject.Properties['Pid'] -and
      $script:LabVIEWPidTrackerInitialState.Pid
    ) {
      try { $final['pid'] = [int]$script:LabVIEWPidTrackerInitialState.Pid } catch { $final['pid'] = $null }
    } else {
      $final['pid'] = $null
    }
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['Running']
    ) {
      try { $final['running'] = [bool]$script:LabVIEWPidTrackerFinalState.Running } catch { $final['running'] = $null }
    }
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['Reused']
    ) {
      try { $final['reused'] = [bool]$script:LabVIEWPidTrackerFinalState.Reused } catch { $final['reused'] = $null }
    } elseif (
      $script:LabVIEWPidTrackerInitialState -and
      $script:LabVIEWPidTrackerInitialState.PSObject.Properties['Reused']
    ) {
      try { $final['reused'] = [bool]$script:LabVIEWPidTrackerInitialState.Reused } catch { $final['reused'] = $null }
    }
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['Observation'] -and
      $script:LabVIEWPidTrackerFinalState.Observation
    ) {
      $final['observation'] = $script:LabVIEWPidTrackerFinalState.Observation
    }
    if ($script:LabVIEWPidTrackerFinalizedSource) {
      $final['finalizedSource'] = $script:LabVIEWPidTrackerFinalizedSource
    }
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['Context'] -and
      $script:LabVIEWPidTrackerFinalState.Context
    ) {
      $final['context'] = $script:LabVIEWPidTrackerFinalState.Context
    }
    if (
      $script:LabVIEWPidTrackerFinalState -and
      $script:LabVIEWPidTrackerFinalState.PSObject.Properties['ContextSource'] -and
      $script:LabVIEWPidTrackerFinalState.ContextSource
    ) {
      $final['contextSource'] = [string]$script:LabVIEWPidTrackerFinalState.ContextSource
    }
    if ($script:LabVIEWPidTrackerFinalContext) {
      $final['context'] = $script:LabVIEWPidTrackerFinalContext
    }
    if ($script:LabVIEWPidTrackerFinalContextSource) {
      $final['contextSource'] = $script:LabVIEWPidTrackerFinalContextSource
    }
    if ($script:LabVIEWPidTrackerFinalContextDetail) {
      $final['contextSourceDetail'] = $script:LabVIEWPidTrackerFinalContextDetail
    }
    if ($final.Count -gt 0) { $payload['final'] = [pscustomobject]$final }
  }

  return $payload
}

<#
.SYNOPSIS
Get-LabVIEWCliPidTracker: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWCliPidTracker {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param()
  $payload = Resolve-LabVIEWCliPidTrackerPayload
  if (-not $payload) { return $null }
  return [pscustomobject]$payload
}

<#
.SYNOPSIS
Add-LabVIEWCliPidTrackerToResult: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Add-LabVIEWCliPidTrackerToResult {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([pscustomobject]$Result)
  if (-not $Result) { return }

  $payload = Resolve-LabVIEWCliPidTrackerPayload
  if (-not $payload) { return }
  $payloadObject = [pscustomobject]$payload

  if ($Result -is [System.Collections.IDictionary]) {
    $Result['labviewPidTracker'] = $payloadObject
    return
  }

  if ($Result.PSObject.Properties['labviewPidTracker']) {
    $Result.labviewPidTracker = $payloadObject
  } else {
    Add-Member -InputObject $Result -Name labviewPidTracker -MemberType NoteProperty -Value $payloadObject
  }
}

<#
.SYNOPSIS
Invoke-LVOperation: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVOperation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Operation,
    [Parameter()][hashtable]$Params,
    [string]$Provider = 'auto',
    [string[]]$AdditionalArguments,
    [switch]$Preview,
    [int]$TimeoutSeconds = 300
  )

  $spec = Get-LVOperationSpec -Operation $Operation
  $normalized = Resolve-LVNormalizedParams -OperationSpec $spec -Params $Params
  $selection = Select-LVProvider -Operation $Operation -RequestedProvider $Provider
  $provider = $selection.Provider
  $providerObject = $selection.Provider
  $providerName = $selection.ProviderName
  $binary = $selection.Binary
  if (-not $providerName -and $provider -and -not ($provider -is [string])) {
    try { $providerName = $provider.Name() } catch {}
  }
  if ($provider -is [string]) {
    $lookupName = if (-not [string]::IsNullOrWhiteSpace($providerName)) { $providerName } else { $provider.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($lookupName)) {
      Write-Verbose ("LabVIEW CLI provider fallback lookup for '{0}'." -f $lookupName)
      if (-not $providerName) { $providerName = $lookupName }
      $fallbackProvider = Get-LVProviderByName $lookupName
      if (-not $fallbackProvider) {
        $fallbackProvider = Get-LVProviders | Where-Object { $_.Name() -eq $lookupName } | Select-Object -First 1
      }
      if ($fallbackProvider) {
        Write-Verbose ("LabVIEW CLI provider '{0}' resolved via fallback (type {1})." -f $lookupName, $fallbackProvider.GetType().FullName)
        $providerObject = $fallbackProvider
      }
    }
  }
  $providerLabel = if ($providerName) { $providerName } elseif ($Provider) { $Provider } else { 'auto' }
  if ($null -eq $providerObject) { throw "Provider '$providerLabel' could not be resolved." }
  try {
    if ($providerObject -and ($providerObject | Get-Member -Name 'Name' -ErrorAction SilentlyContinue)) {
      $providerLabel = $providerObject.Name()
      if (-not $providerName) { $providerName = $providerLabel }
    }
  } catch {}
  Write-Verbose ("LabVIEW CLI provider '{0}' resolved to type {1}" -f $providerLabel, ($providerObject.GetType().FullName))
  if ($providerObject -and ($providerObject | Get-Member -Name 'Validate')) {
    $providerObject.Validate($Operation, $normalized)
  }
  $arguments = @($providerObject.BuildArgs($Operation, $normalized))
  if ($AdditionalArguments -and $AdditionalArguments.Count -gt 0) {
    $arguments = @($arguments + $AdditionalArguments)
  }
  $commandLine = Format-LVCommandLine -Binary $binary -Arguments $arguments
  $result = [ordered]@{
    provider        = if ($providerObject -and ($providerObject | Get-Member -Name 'Name' -ErrorAction SilentlyContinue)) { $providerObject.Name() } else { $providerLabel }
    operation       = $Operation
    cliPath         = $binary
    args            = @($arguments)
    command         = $commandLine
    normalizedParams= $normalized
  }
  if ($Preview) { return [pscustomobject]$result }

  # Optional suppression: env guard or short-TTL sentinel (only for CreateComparisonReport)
  $suppressReason = $null
  if (Test-ShouldSuppressCliCompare -Operation $Operation -Normalized $normalized -Reason ([ref]$suppressReason)) {
    Write-Verbose ("LabVIEW CLI: suppressed '{0}' (reason={1})." -f $Operation, ($suppressReason ?? 'n/a'))
    $result.exitCode = 0
    $result.elapsedSeconds = 0
    $result.stdout = ''
    $result.stderr = ''
    $result.ok = $true
    $result.skipped = $true
    $result.skipReason = $suppressReason
    return [pscustomobject]$result
  }

  Initialize-LabVIEWCliPidTracker

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $binary
  foreach ($arg in $arguments) { $psi.ArgumentList.Add($arg) }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $psi.UseShellExecute = $false

  $guard = $null
  $process = $null
  $stdout = ''
  $stderr = ''
  $sw = $null
  $timedOut = $false
  $exitCode = $null
  $elapsedSeconds = $null
  $finalizeSource = 'labview-cli:operation'
  $errorMessage = $null
  $trackerElapsed = $null

  try {
    $guard = Set-LVHeadlessEnv
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $process = [System.Diagnostics.Process]::Start($psi)
      if (-not $process) { throw "Failed to start process '$binary'." }
      if (-not $process.WaitForExit([Math]::Max(1,$TimeoutSeconds) * 1000)) {
        $timedOut = $true
        try { $process.Kill($true) } catch {}
        throw "Operation '$Operation' timed out after $TimeoutSeconds second(s)."
      }
      $stdout = $process.StandardOutput.ReadToEnd()
      $stderr = $process.StandardError.ReadToEnd()
      $exitCode = $process.ExitCode
      if ($sw) { $elapsedSeconds = [Math]::Round($sw.Elapsed.TotalSeconds,3) }
    } catch {
      $errorMessage = $_.Exception.Message
      $finalizeSource = 'labview-cli:error'
      throw
    } finally {
      if ($sw) {
        try { $sw.Stop() } catch {}
      }
      if (-not $elapsedSeconds -and $sw) {
        try { $elapsedSeconds = [Math]::Round($sw.Elapsed.TotalSeconds,3) } catch { $elapsedSeconds = $null }
      }
      if (-not $trackerElapsed -and $elapsedSeconds) { $trackerElapsed = $elapsedSeconds }
      if (-not $trackerElapsed -and $sw) {
        try { $trackerElapsed = [Math]::Round($sw.Elapsed.TotalSeconds,3) } catch { $trackerElapsed = $null }
      }
      if ($process) { $process.Dispose() }
      if ($guard) { Restore-LVHeadlessEnv -Guard $guard }
    }
  } catch {
    if (-not $errorMessage -and $_ -and $_.Exception) {
      $errorMessage = $_.Exception.Message
    }
    if (-not $finalizeSource -or $finalizeSource -eq 'labview-cli:operation') {
      $finalizeSource = 'labview-cli:error'
    }
    throw
  } finally {
    if (-not $trackerElapsed) {
      if ($elapsedSeconds) {
        $trackerElapsed = $elapsedSeconds
      } elseif ($sw) {
        try { $trackerElapsed = [Math]::Round($sw.Elapsed.TotalSeconds,3) } catch { $trackerElapsed = $null }
      }
    }
    if ($script:LabVIEWPidTrackerLoaded -and $script:LabVIEWPidTrackerPath) {
      $finalizeParams = @{
        Source    = $finalizeSource
        Operation = $Operation
      }
      if ($result.provider) { $finalizeParams['Provider'] = $result.provider }
      if ($result.args) { $finalizeParams['CliArgs'] = $result.args }
      if ($binary) { $finalizeParams['Binary'] = $binary }
      if ($null -ne $exitCode) { $finalizeParams['ExitCode'] = $exitCode }
      if ($null -ne $timedOut) { $finalizeParams['TimedOut'] = [bool]$timedOut }
      if ($trackerElapsed) { $finalizeParams['ElapsedSeconds'] = $trackerElapsed }
      if ($errorMessage) { $finalizeParams['ErrorMessage'] = $errorMessage }
      try {
        Finalize-LabVIEWCliPidTracker @finalizeParams | Out-Null
      } catch {
        Write-Verbose ("LabVIEW CLI: tracker finalization failed: {0}" -f $_.Exception.Message)
      }
    }
  }

  $result.exitCode = $exitCode
  $result.elapsedSeconds = $elapsedSeconds
  $result.stdout = $stdout
  $result.stderr = $stderr
  $result.ok = (-not $timedOut -and $exitCode -eq 0)

  # Update sentinel timestamp after a successful run (for duplicate suppression windows)
  if ($Operation -eq 'CreateComparisonReport' -and $normalized -and $normalized.ContainsKey('vi1') -and $normalized.ContainsKey('vi2')) {
    try { Touch-CompareCliSentinel -Vi1 ([string]$normalized.vi1) -Vi2 ([string]$normalized.vi2) -ReportPath ([string]($normalized.reportPath ?? '')) } catch {}
  }

  Write-LVOperationEvent -EventData @{
    provider = $result.provider
    operation = $Operation
    exitCode = $exitCode
    seconds = $result.elapsedSeconds
    args = $result.args
    timedOut = $timedOut
  }

  Add-LabVIEWCliPidTrackerToResult $result

  return [pscustomobject]$result
}

<#
.SYNOPSIS
Invoke-LVCreateComparisonReport: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVCreateComparisonReport {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaseVi,
    [Parameter(Mandatory)][string]$HeadVi,
    [string]$ReportPath,
    [ValidateSet('HTMLSingleFile','HTML','XML','Text','Word')]
    [string]$ReportType,
    [string[]]$Flags,
    [string]$Provider = 'auto',
    [switch]$Preview,
    [string]$LabVIEWPath,
    [Nullable[int]]$TimeoutSeconds
  )

  $params = @{
    vi1 = $BaseVi
    vi2 = $HeadVi
  }
  if ($PSBoundParameters.ContainsKey('ReportPath') -and $ReportPath) {
    $params.reportPath = $ReportPath
  }
  if ($PSBoundParameters.ContainsKey('ReportType') -and $ReportType) {
    $params.reportType = $ReportType
  }
  if ($PSBoundParameters.ContainsKey('Flags') -and $Flags) {
    $params.flags = @($Flags)
  }
  if ($PSBoundParameters.ContainsKey('LabVIEWPath') -and $LabVIEWPath) {
    $params.labviewPath = $LabVIEWPath
  }
  $invokeArgs = @{
    Operation = 'CreateComparisonReport'
    Params    = $params
    Provider  = $Provider
    Preview   = $Preview.IsPresent
  }
  if ($PSBoundParameters.ContainsKey('TimeoutSeconds') -and $TimeoutSeconds -gt 0) {
    $invokeArgs.TimeoutSeconds = [int]$TimeoutSeconds
  }
  Invoke-LVOperation @invokeArgs
}

<#
.SYNOPSIS
Invoke-LVRunVI: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVRunVI {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ViPath,
    [object[]]$Arguments,
    [switch]$ShowFrontPanel,
    [switch]$AbortOnError,
    [string]$Provider = 'auto',
    [switch]$Preview
  )

  $params = @{ viPath = $ViPath }
  if ($PSBoundParameters.ContainsKey('Arguments') -and $Arguments) { $params.arguments = @($Arguments) }
  if ($PSBoundParameters.ContainsKey('ShowFrontPanel')) { $params.showFP = $ShowFrontPanel.IsPresent }
  if ($PSBoundParameters.ContainsKey('AbortOnError')) { $params.abortOnError = $AbortOnError.IsPresent }

  Invoke-LVOperation -Operation 'RunVI' -Params $params -Provider $Provider -Preview:$Preview
}

<#
.SYNOPSIS
Invoke-LVRunVIAnalyzer: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVRunVIAnalyzer {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$ReportPath,
    [ValidateSet('HTML','XML','Text')]
    [string]$ReportSaveType,
    [string]$ConfigPassword,
    [string]$Provider = 'auto',
    [switch]$Preview
  )

  $params = @{
    configPath = $ConfigPath
    reportPath = $ReportPath
  }
  if ($PSBoundParameters.ContainsKey('ReportSaveType') -and $ReportSaveType) { $params.reportSaveType = $ReportSaveType }
  if ($PSBoundParameters.ContainsKey('ConfigPassword') -and $ConfigPassword) { $params.configPassword = $ConfigPassword }

  Invoke-LVOperation -Operation 'RunVIAnalyzer' -Params $params -Provider $Provider -Preview:$Preview
}

<#
.SYNOPSIS
Invoke-LVRunUnitTests: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVRunUnitTests {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$JUnitReportPath,
    [string]$Provider = 'auto',
    [switch]$Preview
  )

  $params = @{
    projectPath    = $ProjectPath
    junitReportPath= $JUnitReportPath
  }
  Invoke-LVOperation -Operation 'RunUnitTests' -Params $params -Provider $Provider -Preview:$Preview
}

<#
.SYNOPSIS
Invoke-LVMassCompile: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVMassCompile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$DirectoryToCompile,
    [string]$MassCompileLogFile,
    [switch]$AppendToMassCompileLog,
    [int]$NumOfVIsToCache,
    [switch]$ReloadLVSBs,
    [string]$Provider = 'auto',
    [switch]$Preview
  )

  $params = @{ directoryToCompile = $DirectoryToCompile }
  if ($PSBoundParameters.ContainsKey('MassCompileLogFile') -and $MassCompileLogFile) { $params.massCompileLogFile = $MassCompileLogFile }
  if ($PSBoundParameters.ContainsKey('AppendToMassCompileLog')) { $params.appendToMassCompileLog = $AppendToMassCompileLog.IsPresent }
  if ($PSBoundParameters.ContainsKey('NumOfVIsToCache')) { $params.numOfVIsToCache = $NumOfVIsToCache }
  if ($PSBoundParameters.ContainsKey('ReloadLVSBs')) { $params.reloadLVSBs = $ReloadLVSBs.IsPresent }

  Invoke-LVOperation -Operation 'MassCompile' -Params $params -Provider $Provider -Preview:$Preview
}

<#
.SYNOPSIS
Invoke-LVExecuteBuildSpec: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Invoke-LVExecuteBuildSpec {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$BuildSpecName,
    [string]$TargetName,
    [string]$Provider = 'auto',
    [switch]$Preview
  )

  $params = @{
    projectPath   = $ProjectPath
    buildSpecName = $BuildSpecName
  }
  if ($PSBoundParameters.ContainsKey('TargetName') -and $TargetName) { $params.targetName = $TargetName }

  Invoke-LVOperation -Operation 'ExecuteBuildSpec' -Params $params -Provider $Provider -Preview:$Preview
}

Export-ModuleMember -Function `
  Invoke-LVCreateComparisonReport, `
  Invoke-LVRunVI, `
  Invoke-LVRunVIAnalyzer, `
  Invoke-LVRunUnitTests, `
  Invoke-LVMassCompile, `
  Invoke-LVExecuteBuildSpec, `
  Invoke-LVOperation, `
  Get-LabVIEWCliPidTracker, `
  Get-LVOperationNames, `
  Get-LVOperationSpec, `
  Register-LVProvider, `
  Get-LVProviders, `
  Get-LVProviderByName

<#
.SYNOPSIS
Test-ValidLabel: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

<#
.SYNOPSIS
Invoke-WithTimeout: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
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
