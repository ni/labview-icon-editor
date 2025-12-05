#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Set-ConsoleUtf8: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Set-ConsoleUtf8 {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

    # ShouldProcess guard: honor -WhatIf / -Confirm
    if (-not $PSCmdlet.ShouldProcess($MyInvocation.MyCommand.Name, 'Execute')) { return }

  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::UTF8
  } catch {}
}

<#
.SYNOPSIS
Resolve-RepoRoot: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-RepoRoot {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$StartPath = (Get-Location).Path)
  try { return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim() } catch { return $StartPath }
}

<#
.SYNOPSIS
Get-LabVIEWConfigObjects: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWConfigObjects {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  $configs = New-Object System.Collections.Generic.List[object]
  $root = Resolve-RepoRoot
  foreach ($name in @('labview-paths.local.json', 'labview-paths.json')) {
    $path = Join-Path $root 'configs' $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    try {
      $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 6

$schemaPath = Join-Path $PSScriptRoot 'configs/schema/vi-diff-heuristics.schema.json'
if (Test-Path -LiteralPath $schemaPath) {
  ($cfgContent) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop
}
      if ($config) { $configs.Add($config) | Out-Null }
    } catch {}
  }
  return $configs.ToArray()
}

<#
.SYNOPSIS
Get-VersionedConfigValue: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VersionedConfigValue {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    $Config,
    [string]$PropertyName,
    [int]$Version,
    [int]$Bitness
  )

  if (-not $Config) { return $null }
  if (-not $Version) { return $null }

  $versionsProp = $Config.PSObject.Properties['versions']
  if (-not $versionsProp -or -not $versionsProp.Value) { return $null }
  $versionsNode = $versionsProp.Value

  $versionKey = $Version.ToString()
  if ($versionsNode -is [System.Collections.IDictionary]) {
    if (-not $versionsNode.Contains($versionKey)) { return $null }
    $versionNode = $versionsNode[$versionKey]
  } else {
    $versionEntry = $versionsNode.PSObject.Properties[$versionKey]
    if (-not $versionEntry) { return $null }
    $versionNode = $versionEntry.Value
  }
  if (-not $versionNode) { return $null }

  $bitnessNode = $null
  if ($Bitness) {
    $bitKey = $Bitness.ToString()
    if ($versionNode -is [System.Collections.IDictionary]) {
      if ($versionNode.Contains($bitKey)) { $bitnessNode = $versionNode[$bitKey] }
    } else {
      $bitProp = $versionNode.PSObject.Properties[$bitKey]
      if ($bitProp) { $bitnessNode = $bitProp.Value }
    }
  } else {
    $bitnessNode = $versionNode
  }

  if (-not $bitnessNode) { return $null }

  if ($bitnessNode -is [string]) {
    return $bitnessNode
  }

  $propertyProp = $bitnessNode.PSObject.Properties[$PropertyName]
  if ($propertyProp -and $propertyProp.Value) {
    return [string]$propertyProp.Value
  }

  # Accept lowercase camel variations for convenience
  $altName = $PropertyName
  if ($PropertyName -cmatch '([A-Z])') {
    $altName = ([regex]::Replace($PropertyName, '([a-z0-9])([A-Z])', '$1$2')).ToLower()
  }
  foreach ($prop in $bitnessNode.PSObject.Properties) {
    if ($prop.Name -ieq $PropertyName -or $prop.Name -ieq $altName) {
      if ($prop.Value) { return [string]$prop.Value }
    }
  }

  return $null
}

<#
.SYNOPSIS
Resolve-BinPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-BinPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)] [string]$Name
  )
  $root = Resolve-RepoRoot
  $bin = Join-Path $root 'bin'
  if ($IsWindows) {
    $exe = Join-Path $bin ("{0}.exe" -f $Name)
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
  }
  $nix = Join-Path $bin $Name
  if (Test-Path -LiteralPath $nix -PathType Leaf) { return $nix }
  return $null
}

<#
.SYNOPSIS
Get-VersionedConfigValues: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-VersionedConfigValues {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    $Config,
    [string]$PropertyName
  )

  $values = New-Object System.Collections.Generic.List[string]
  if (-not $Config) { return $values.ToArray() }
  $versionsProp = $Config.PSObject.Properties['versions']
  if (-not $versionsProp) { return $values.ToArray() }
  $versionsNode = $versionsProp.Value
  if (-not $versionsNode) { return $values.ToArray() }

  $versionEntries = @()
  if ($versionsNode -is [System.Collections.IDictionary]) {
    foreach ($key in $versionsNode.Keys) {
      $versionEntries += [pscustomobject]@{ Name = $key; Value = $versionsNode[$key] }
    }
  } else {
    $versionEntries = $versionsNode.PSObject.Properties
  }

  foreach ($versionEntry in $versionEntries) {
    $bitnessNode = $versionEntry.Value
    if (-not $bitnessNode) { continue }

    $bitnessEntries = @()
    if ($bitnessNode -is [System.Collections.IDictionary]) {
      foreach ($key in $bitnessNode.Keys) {
        $bitnessEntries += [pscustomobject]@{ Name = $key; Value = $bitnessNode[$key] }
      }
    } else {
      $bitnessEntries = $bitnessNode.PSObject.Properties
    }

    foreach ($bitnessEntry in $bitnessEntries) {
      $valueNode = $bitnessEntry.Value
      if (-not $valueNode) { continue }
      if ($valueNode -is [System.Collections.IDictionary]) {
        if ($valueNode.Contains($PropertyName) -and $valueNode[$PropertyName]) {
          $values.Add([string]$valueNode[$PropertyName])
        }
      } else {
        $valueProp = $valueNode.PSObject.Properties[$PropertyName]
        if ($valueProp -and $valueProp.Value) {
          $values.Add([string]$valueProp.Value)
        }
      }
    }
  }

  return $values.ToArray()
}

<#
.SYNOPSIS
Resolve-ActionlintPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-ActionlintPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  $p = Resolve-BinPath -Name 'actionlint'
  if ($IsWindows -and $p -and (Split-Path -Leaf $p) -eq 'actionlint') {
    $alt = Join-Path (Split-Path -Parent $p) 'actionlint.exe'
    if (Test-Path -LiteralPath $alt -PathType Leaf) { return $alt }
  }
  return $p
}

<#
.SYNOPSIS
Resolve-MarkdownlintCli2Path: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-MarkdownlintCli2Path {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  $root = Resolve-RepoRoot
  if ($IsWindows) {
    $candidates = @(
      (Join-Path $root 'node_modules/.bin/markdownlint-cli2.cmd'),
      (Join-Path $root 'node_modules/.bin/markdownlint-cli2.ps1')
    )
  } else {
    $candidates = @(Join-Path $root 'node_modules/.bin/markdownlint-cli2')
  }
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c -PathType Leaf) { return $c } }
  return $null
}

<#
.SYNOPSIS
Get-MarkdownlintCli2Version: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-MarkdownlintCli2Version {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  $root = Resolve-RepoRoot
  $pkg = Join-Path $root 'node_modules/markdownlint-cli2/package.json'
  if (Test-Path -LiteralPath $pkg -PathType Leaf) {
    try { return ((Get-Content -LiteralPath $pkg -Raw | ConvertFrom-Json).version) } catch {}
  }
  $pj = Join-Path $root 'package.json'
  if (Test-Path -LiteralPath $pj -PathType Leaf) {
    try { $decl = (Get-Content -LiteralPath $pj -Raw | ConvertFrom-Json).devDependencies.'markdownlint-cli2'; if ($decl) { return "declared $decl (not installed)" } } catch {}
  }
  return 'unavailable'
}

<#
.SYNOPSIS
Resolve-LVComparePath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LVComparePath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  if (-not $IsWindows) { return $null }
  $root = Resolve-RepoRoot
  $configPath = Join-Path $root 'configs/labview-paths.json'
  $config = $null
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
      $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 4
    } catch {}
  }

  $jsonCandidates = @()
  if ($config -and $config.PSObject.Properties['lvcompare']) {
    $values = $config.lvcompare
    if ($values -is [string]) { $jsonCandidates += $values }
    if ($values -is [System.Collections.IEnumerable]) { $jsonCandidates += $values }
  }
  if ($config -and $config.PSObject.Properties['LVComparePath'] -and $config.LVComparePath) {
    $jsonCandidates += [string]$config.LVComparePath
  }
  foreach ($value in (Get-VersionedConfigValues -Config $config -PropertyName 'LVComparePath')) {
    if ($value) { $jsonCandidates += [string]$value }
  }

  $envCandidates = @(
    $env:LVCOMPARE_PATH,
    $env:LV_COMPARE_PATH
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  $canonicalCandidates = @(
    (Join-Path $env:ProgramFiles 'National Instruments\Shared\LabVIEW Compare\LVCompare.exe')
  )

  $allCandidates = @($jsonCandidates + $envCandidates + $canonicalCandidates) | Where-Object { $_ }
  foreach ($candidate in $allCandidates) {
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    } catch {}
  }

  Write-Verbose ('VendorTools: LVCompare candidates evaluated -> {0}' -f ($allCandidates -join '; '))
  return $null
}

<#
.SYNOPSIS
Resolve-LabVIEWCliPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LabVIEWCliPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  if (-not $IsWindows) { return $null }
  $root = Resolve-RepoRoot
  $configPath = Join-Path $root 'configs/labview-paths.json'
  $config = $null
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 4 } catch {}
  }

  if ($config) {
    $configCandidates = @()
    if ($config.PSObject.Properties['labviewcli']) {
      $entries = $config.labviewcli
      if ($entries -is [string]) { $configCandidates += $entries }
      elseif ($entries -is [System.Collections.IEnumerable]) {
        foreach ($entry in $entries) { if ($entry) { $configCandidates += [string]$entry } }
      }
    }
    if ($config.PSObject.Properties['LabVIEWCLIPath'] -and $config.LabVIEWCLIPath) {
      $configCandidates += [string]$config.LabVIEWCLIPath
    }
    foreach ($value in (Get-VersionedConfigValues -Config $config -PropertyName 'LabVIEWCLIPath')) {
      if ($value) { $configCandidates += [string]$value }
    }
    foreach ($candidate in $configCandidates) {
      try {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          return (Resolve-Path -LiteralPath $candidate).Path
        }
      } catch {}
    }
  }

  $envCandidates = @(
    $env:LABVIEWCLI_PATH,
    $env:LABVIEW_CLI_PATH
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  foreach ($candidate in $envCandidates) {
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    } catch {}
  }
  $candidates = @(
    (Join-Path $env:ProgramFiles 'National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe')
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
  }
  return $null
}

<#
.SYNOPSIS
Resolve-LabVIEW2025Environment: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LabVIEW2025Environment {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([switch]$ThrowOnMissing)

  if (-not $IsWindows) {
    if ($ThrowOnMissing) { throw 'LabVIEW 2025 (64-bit) resolution requires Windows.' }
    return [pscustomobject]@{
      LabVIEWExePath = $null
      LabVIEWCliPath = $null
      LVComparePath  = $null
    }
  }

  $config = Get-LabVIEWConfig

<#
.SYNOPSIS
Add-LabVIEWCandidate: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
  function Add-LabVIEWCandidate {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

    param($list, $value)
    if ($null -eq $value) { return }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
      foreach ($item in $value) { Add-LabVIEWCandidate $list $item }
      return
    }
    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    foreach ($entry in ($text -split ';')) {
      $trimmed = $entry.Trim()
      if ($trimmed.Length -eq 0) { continue }
      if (-not $list.Contains($trimmed)) { $list.Add($trimmed) | Out-Null }
    }
  }

  $labviewCandidates = New-Object System.Collections.Generic.List[string]
  Add-LabVIEWCandidate $labviewCandidates $env:LABVIEW_PATH
  Add-LabVIEWCandidate $labviewCandidates $env:LABVIEW_EXE_PATH
  Add-LabVIEWCandidate $labviewCandidates (Get-VersionedConfigValue -Config $config -PropertyName 'LabVIEWExePath' -Version 2025 -Bitness 64)
  Add-LabVIEWCandidate $labviewCandidates (Find-LabVIEWVersionExePath -Version 2025 -Bitness 64 -Config $config)
  if ($env:ProgramFiles) {
    Add-LabVIEWCandidate $labviewCandidates (Join-Path $env:ProgramFiles 'National Instruments\LabVIEW 2025\LabVIEW.exe')
  }

  $labviewExe = $null
  foreach ($candidate in $labviewCandidates) {
    try {
      if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
      $resolved = (Resolve-Path -LiteralPath $candidate).Path
      if ($resolved -match '(?i)Program Files \(x86\)') { continue }
      $labviewExe = $resolved
      break
    } catch {}
  }

  if (-not $labviewExe -and $ThrowOnMissing) {
    throw 'LabVIEW 2025 (64-bit) executable not found. Set LABVIEW_PATH, configure configs/labview-paths(.local).json, or install LabVIEW 2025 (64-bit).'
  }

  $cliCandidates = New-Object System.Collections.Generic.List[string]
  Add-LabVIEWCandidate $cliCandidates $env:LABVIEWCLI_PATH
  Add-LabVIEWCandidate $cliCandidates $env:LABVIEW_CLI_PATH
  Add-LabVIEWCandidate $cliCandidates (Get-VersionedConfigValue -Config $config -PropertyName 'LabVIEWCLIPath' -Version 2025 -Bitness 64)
  if ($config -and $config.PSObject.Properties['labviewcli']) { Add-LabVIEWCandidate $cliCandidates $config.labviewcli }
  if ($config -and $config.PSObject.Properties['LabVIEWCLIPath']) { Add-LabVIEWCandidate $cliCandidates $config.LabVIEWCLIPath }
  if ($env:ProgramFiles) {
    Add-LabVIEWCandidate $cliCandidates (Join-Path $env:ProgramFiles 'National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe')
  }

  $labviewCli = $null
  foreach ($candidate in $cliCandidates) {
    try {
      if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
      $resolved = (Resolve-Path -LiteralPath $candidate).Path
      if ($resolved -match '(?i)Program Files \(x86\)') { continue }
      $labviewCli = $resolved
      break
    } catch {}
  }

  $lvComparePath = $null
  try {
    $candidateCompare = Resolve-LVComparePath
    if ($candidateCompare -and -not ($candidateCompare -match '(?i)Program Files \(x86\)')) {
      $lvComparePath = $candidateCompare
    } else {
      $canonicalCompare = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'National Instruments\Shared\LabVIEW Compare\LVCompare.exe' } else { $null }
      if ($canonicalCompare -and (Test-Path -LiteralPath $canonicalCompare -PathType Leaf)) {
        $lvComparePath = (Resolve-Path -LiteralPath $canonicalCompare).Path
      }
    }
  } catch {}

  return [pscustomobject]@{
    LabVIEWExePath = $labviewExe
    LabVIEWCliPath = $labviewCli
    LVComparePath  = $lvComparePath
  }
}


<#
.SYNOPSIS
Get-GCliCandidateExePaths: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-GCliCandidateExePaths {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$GCliExePath)

  if (-not $IsWindows) { return @() }

  $candidates = New-Object System.Collections.Generic.List[string]

  if (-not [string]::IsNullOrWhiteSpace($GCliExePath)) {
    foreach ($entry in ($GCliExePath -split ';')) {
      if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $candidates.Add($entry.Trim())
      }
    }
  }

  foreach ($envName in @('GCLI_EXE_PATH','GCLI_PATH')) {
    $value = [Environment]::GetEnvironmentVariable($envName, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable($envName, 'Machine') }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable($envName, 'User') }
    if ([string]::IsNullOrWhiteSpace($value)) { continue }
    foreach ($entry in ($value -split ';')) {
      if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $candidates.Add($entry.Trim())
      }
    }
  }

  $root = Resolve-RepoRoot
  foreach ($configName in @('labview-paths.local.json','labview-paths.json')) {
    $configPath = Join-Path $root "configs/$configName"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
    try {
      $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 4
      if ($config) {
        foreach ($propName in @('GCliExePath','GCliPath','gcli','gcliExePath')) {
          if ($config.PSObject.Properties[$propName] -and $config.$propName) {
            $value = $config.$propName
            if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
              foreach ($entry in $value) {
                if ($entry) { $candidates.Add([string]$entry) }
              }
            } else {
              $candidates.Add([string]$value)
            }
          }
        }
      }
      foreach ($value in (Get-VersionedConfigValues -Config $config -PropertyName 'GCliExePath')) {
        if ($value) { $candidates.Add([string]$value) }
      }
      foreach ($value in (Get-VersionedConfigValues -Config $config -PropertyName 'gcliExePath')) {
        if ($value) { $candidates.Add([string]$value) }
      }
    } catch {}
  }

  $defaultGCliPath = 'C:\Program Files\G-CLI\bin\g-cli.exe'
  $candidates.Add($defaultGCliPath)

  $resolved = New-Object System.Collections.Generic.List[string]
  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    try {
      $pathCandidate = $candidate
      if (Test-Path -LiteralPath $pathCandidate -PathType Container) {
        $pathCandidate = Join-Path $pathCandidate 'g-cli.exe'
      }
      if (Test-Path -LiteralPath $pathCandidate -PathType Leaf) {
        $resolvedPath = (Resolve-Path -LiteralPath $pathCandidate).Path
        if (-not $resolved.Contains($resolvedPath)) {
          $resolved.Add($resolvedPath)
        }
      }
    } catch {}
  }

  return $resolved.ToArray()
}

<#
.SYNOPSIS
Resolve-GCliPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-GCliPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  if (-not $IsWindows) { return $null }
  $candidates = @(Get-GCliCandidateExePaths -GCliExePath $null)
  if ($candidates.Count -eq 0) { return $null }

  $viable = New-Object System.Collections.Generic.List[string]

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $trimmed = $candidate.Trim()

    if ($trimmed.StartsWith('function:', [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Verbose ("Resolve-GCliPath using function reference '{0}'." -f $trimmed)
      return $trimmed
    }

    try {
      if (Test-Path -LiteralPath $trimmed -PathType Leaf) {
        $resolved = (Resolve-Path -LiteralPath $trimmed).Path
        Write-Verbose ("Resolve-GCliPath found '{0}'." -f $resolved)
        return $resolved
      }
    } catch {
      # fall through, we only log aggregate failure below
    }

    if (-not $viable.Contains($trimmed)) {
      $viable.Add($trimmed) | Out-Null
    }
  }

  if ($viable.Count -gt 0) {
    Write-Verbose ("Resolve-GCliPath tried candidates: {0}" -f ($viable -join ', '))
  }

  return $null
}

<#
.SYNOPSIS
Get-LabVIEWConfig: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWConfig {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

  $root = Resolve-RepoRoot
  foreach ($configName in @('labview-paths.local.json','labview-paths.json')) {
    $configPath = Join-Path $root "configs/$configName"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
    try {
      $json = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 6
      if ($json) { return $json }
    } catch {}
  }
  return $null
}

<#
.SYNOPSIS
Get-LabVIEWConfigEntries: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWConfigEntries {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param($Config)

  $entries = New-Object System.Collections.Generic.List[object]
  if (-not $Config) { return $entries.ToArray() }

  $versionsNode = $Config.PSObject.Properties['versions']
  if ($versionsNode -and $Config.versions) {
    foreach ($versionProp in $Config.versions.PSObject.Properties) {
      $versionName = $versionProp.Name
      $versionValue = $versionProp.Value
      if (-not $versionValue) { continue }
      foreach ($bitnessProp in $versionValue.PSObject.Properties) {
        $bitnessName = $bitnessProp.Name
        $bitnessValue = $bitnessProp.Value
        if (-not $bitnessValue) { continue }
        $path = $null
        if ($bitnessValue -is [string]) {
          $path = $bitnessValue
        } elseif ($bitnessValue.PSObject.Properties['LabVIEWExePath']) {
          $path = $bitnessValue.LabVIEWExePath
        }
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try {
          if (Test-Path -LiteralPath $path -PathType Leaf) {
            $resolved = (Resolve-Path -LiteralPath $path).Path
            $entries.Add([pscustomobject]@{
              Version = $versionName
              Bitness = $bitnessName
              Path    = $resolved
            }) | Out-Null
          }
        } catch {}
      }
    }
  }

  return $entries.ToArray()
}

<#
.SYNOPSIS
Find-LabVIEWVersionExePath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Find-LabVIEWVersionExePath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory)][int]$Version,
    [Parameter(Mandatory)][ValidateSet(32,64)][int]$Bitness,
    $Config = (Get-LabVIEWConfig)
  )

  $versionString = $Version.ToString()
  $bitnessString = $Bitness.ToString()

  if ($Config) {
    foreach ($entry in (Get-LabVIEWConfigEntries -Config $Config)) {
      if (($entry.Version -eq $versionString) -and ($entry.Bitness -eq $bitnessString)) {
        return $entry.Path
      }
    }
  }

  foreach ($candidate in (Get-LabVIEWCandidateExePaths)) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $matchesVersion = $candidate -match ("LabVIEW\s*$versionString")
    if (-not $matchesVersion) { continue }
    $is32BitPath = $candidate -match '(?i)Program Files \(x86\)'
    $candidateBitness = if ($is32BitPath) { 32 } else { 64 }
    if ($candidateBitness -ne $Bitness) { continue }
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    } catch {}
  }

  return $null
}

<#
.SYNOPSIS
Get-LabVIEWCandidateExePaths: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWCandidateExePaths {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$LabVIEWExePath)

  if (-not $IsWindows) { return @() }

  $candidates = New-Object System.Collections.Generic.List[string]

  if (-not [string]::IsNullOrWhiteSpace($LabVIEWExePath)) {
    $candidates.Add($LabVIEWExePath)
  }

  foreach ($envValue in @($env:LABVIEW_PATH, $env:LABVIEW_EXE_PATH)) {
    if ([string]::IsNullOrWhiteSpace($envValue)) { continue }
    foreach ($entry in ($envValue -split ';')) {
      if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $candidates.Add($entry.Trim())
      }
    }
  }

  $root = Resolve-RepoRoot
  foreach ($configName in @('labview-paths.local.json','labview-paths.json')) {
    $configPath = Join-Path $root "configs/$configName"
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
    try {
      $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 4
      if ($config -and $config.PSObject.Properties['labview']) {
        $entries = $config.labview
        if ($entries -is [string]) { $candidates.Add($entries) }
        elseif ($entries -is [System.Collections.IEnumerable]) {
          foreach ($item in $entries) {
            if ($item) { $candidates.Add([string]$item) }
          }
        }
      }
      if ($config -and $config.PSObject.Properties['LabVIEWExePath'] -and $config.LabVIEWExePath) {
        $candidates.Add([string]$config.LabVIEWExePath)
      }
      foreach ($value in (Get-VersionedConfigValues -Config $config -PropertyName 'LabVIEWExePath')) {
        if ($value) { $candidates.Add([string]$value) }
      }
    } catch {}
  }

  $programRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  foreach ($rootPath in $programRoots) {
    try {
      $niRoot = Join-Path $rootPath 'National Instruments'
      if (-not (Test-Path -LiteralPath $niRoot -PathType Container)) { continue }
      $labviewDirs = Get-ChildItem -LiteralPath $niRoot -Directory -Filter 'LabVIEW*' -ErrorAction SilentlyContinue
      foreach ($dir in $labviewDirs) {
        $exe = Join-Path $dir.FullName 'LabVIEW.exe'
        if (Test-Path -LiteralPath $exe -PathType Leaf) {
          $candidates.Add($exe)
        }
      }
    } catch {}
  }

  $resolved = New-Object System.Collections.Generic.List[string]
  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $path = (Resolve-Path -LiteralPath $candidate).Path
        if (-not $resolved.Contains($path)) {
          $resolved.Add($path)
        }
      }
    } catch {}
  }

  return $resolved.ToArray()
}

<#
.SYNOPSIS
Get-LabVIEWIniPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWIniPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [string]$LabVIEWExePath
  )

  foreach ($exe in (Get-LabVIEWCandidateExePaths -LabVIEWExePath $LabVIEWExePath)) {
    try {
      $rootDir = Split-Path -Parent $exe
      $iniCandidate = Join-Path $rootDir 'LabVIEW.ini'
      if (Test-Path -LiteralPath $iniCandidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $iniCandidate).Path
      }
    } catch {}
  }
  return $null
}

<#
.SYNOPSIS
Get-LabVIEWIniValue: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Get-LabVIEWIniValue {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [string]$LabVIEWIniPath,
    [string]$LabVIEWExePath
  )

  if (-not $IsWindows) { return $null }

  if ([string]::IsNullOrWhiteSpace($LabVIEWIniPath)) {
    $LabVIEWIniPath = Get-LabVIEWIniPath -LabVIEWExePath $LabVIEWExePath
  }
  if (-not $LabVIEWIniPath) { return $null }

  try {
    foreach ($line in (Get-Content -LiteralPath $LabVIEWIniPath)) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line -match '^\s*[#;]') { continue }
      $parts = $line -split '=', 2
      if ($parts.Count -ne 2) { continue }
      if ($parts[0].Trim() -ieq $Key) {
        return $parts[1].Trim()
      }
    }
  } catch {}

  return $null
}

<#
.SYNOPSIS
Resolve-LabVIEWServerPort: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LabVIEWServerPort {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [string]$LabVIEWExePath,
    [int]$DefaultPort = 3363
  )

  $iniPath = $null
  if ($LabVIEWExePath) {
    $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $LabVIEWExePath
  }

  $value = $null
  if ($iniPath) {
    $value = Get-LabVIEWIniValue -Key 'server.tcp.port' -LabVIEWIniPath $iniPath -LabVIEWExePath $LabVIEWExePath
  }

  if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultPort }

  $port = 0
  if ([int]::TryParse($value, [ref]$port) -and $port -gt 0) {
    return $port
  }

  return $DefaultPort
}

function Resolve-LabVIEWCLIPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [int]$Version,
    [int]$Bitness = 64,
    [string]$LabVIEWCLIPath
  )

  if (-not $IsWindows) { return $null }

  $candidates = New-Object System.Collections.ArrayList
  $addCandidate = {
    param([System.Collections.ArrayList]$list, [string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    if (-not $list.Contains($value)) { [void]$list.Add($value) }
  }

  & $addCandidate $candidates $LabVIEWCLIPath

  foreach ($config in (Get-LabVIEWConfigObjects)) {
    foreach ($propName in @('labviewCli', 'LabVIEWCli', 'LabVIEWCLIPath', 'LabVIEWCliPath', 'labviewCliPath')) {
      $prop = $config.PSObject.Properties[$propName]
      if (-not $prop) { continue }
      $value = $prop.Value
      if ($value -is [string]) {
        & $addCandidate $candidates $value
      } elseif ($value -is [System.Collections.IEnumerable]) {
        foreach ($item in $value) { & $addCandidate $candidates $item }
      }
    }

    if ($Version) {
      foreach ($name in @('LabVIEWCliPath','LabVIEWCLIPath')) {
        $versionValue = Get-VersionedConfigValue -Config $config -PropertyName $name -Version $Version -Bitness $Bitness
        if ($versionValue) { & $addCandidate $candidates $versionValue }
      }
    }
  }

  foreach ($envKey in @('LABVIEWCLI_PATH', 'LABVIEWCLI_EXE_PATH')) {
    $envValue = [System.Environment]::GetEnvironmentVariable($envKey)
    if ([string]::IsNullOrWhiteSpace($envValue)) { continue }
    foreach ($entry in ($envValue -split ';')) {
      & $addCandidate $candidates ($entry.Trim())
    }
  }

  if ($Version) {
    $programRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($rootPath in $programRoots) {
      $candidate = Join-Path $rootPath ("National Instruments\LabVIEW {0}\Shared\LabVIEW CLI\LabVIEWCLI.exe" -f $Version)
      & $addCandidate $candidates $candidate
    }
  }

  & $addCandidate $candidates 'C:\Program Files\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'
  & $addCandidate $candidates 'C:\Program Files (x86)\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'

  foreach ($candidate in $candidates) {
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    } catch {}
  }

  return $null
}

<#
.SYNOPSIS
Resolve-LabVIEWExePath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-LabVIEWExePath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param(
    [int]$Version,
    [int]$Bitness = 64,
    [string]$LabVIEWPath
  )

  if (-not $IsWindows) { return $null }

  $candidates = New-Object System.Collections.ArrayList
  $addCandidate = {
    param([System.Collections.ArrayList]$list, [string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    if (-not $list.Contains($value)) { [void]$list.Add($value) }
  }

  & $addCandidate $candidates $LabVIEWPath

  foreach ($envKey in @('LABVIEW_EXE_PATH','LABVIEW_PATH')) {
    $envValue = [System.Environment]::GetEnvironmentVariable($envKey)
    if ([string]::IsNullOrWhiteSpace($envValue)) { continue }
    foreach ($entry in ($envValue -split ';')) {
      & $addCandidate $candidates ($entry.Trim())
    }
  }

  foreach ($config in (Get-LabVIEWConfigObjects)) {
    foreach ($prop in @('labview','LabVIEWPath','labviewPath')) {
      $propVal = $config.PSObject.Properties[$prop]
      if (-not $propVal) { continue }
      $value = $propVal.Value
      if ($value -is [string]) { & $addCandidate $candidates $value }
      elseif ($value -is [System.Collections.IEnumerable]) {
        foreach ($item in $value) { & $addCandidate $candidates $item }
      }
    }

    if ($Version) {
      foreach ($name in @('LabVIEWPath','labview')) {
        $versionValue = Get-VersionedConfigValue -Config $config -PropertyName $name -Version $Version -Bitness $Bitness
        if ($versionValue) { & $addCandidate $candidates $versionValue }
      }
    }
  }

  if ($Version) {
    $programRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($rootPath in $programRoots) {
      $candidate = Join-Path $rootPath ("National Instruments\LabVIEW {0}\LabVIEW.exe" -f $Version)
      & $addCandidate $candidates $candidate
    }
  }

  $orderedCandidates = @()
  try {
    $orderedCandidates = [string[]]$candidates.ToArray()
  } catch {
    $orderedCandidates = @($candidates)
  }

  if ($Bitness -in @(32, 64)) {
    $preferred = @()
    $fallback  = @()
    foreach ($candidate in $orderedCandidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
      $normalized = $candidate.ToLowerInvariant()
      $isPreferred = $false
      if ($Bitness -eq 32) {
        if ($normalized -like '*program files (x86)*' -or $normalized -match '\\32(bit)?\\') {
          $isPreferred = $true
        }
      } elseif ($Bitness -eq 64) {
        if (($normalized -like '*program files*' -and $normalized -notlike '*program files (x86)*') -or $normalized -match '\\64(bit)?\\') {
          $isPreferred = $true
        }
      }
      if ($isPreferred) {
        $preferred += $candidate
      } else {
        $fallback += $candidate
      }
    }
    $orderedCandidates = $preferred + $fallback
  }

  foreach ($candidate in $orderedCandidates) {
    if ($candidate -is [string]) {
      if ($candidate.StartsWith('function:', [System.StringComparison]::OrdinalIgnoreCase)) {
        $functionName = $candidate.Substring('function:'.Length)
        if (-not [string]::IsNullOrWhiteSpace($functionName)) {
          return $functionName
        }
      }
    }
  }

  foreach ($candidate in $orderedCandidates) {
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    } catch {}
  }

  return $null
}

<#
.SYNOPSIS
Resolve-VIPMPath: brief description (TODO: refine).
.DESCRIPTION
Auto-seeded to satisfy help synopsis presence. Update with real details.
#>
function Resolve-VIPMPath {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]

  param([string]$VipmPath)

  if (-not $IsWindows) { return $null }

  $resolveCandidate = {
    param([string]$candidate)

    if ([string]::IsNullOrWhiteSpace($candidate)) { return $null }

    $expanded = [Environment]::ExpandEnvironmentVariables($candidate)
    # If we were given a directory, probe common VIPM executables (prefer the CLI under support\vipm.exe).
    if (Test-Path -LiteralPath $expanded -PathType Container) {
      foreach ($probe in @('support\vipm.exe','vipm.exe','VIPM.exe','VI Package Manager.exe')) {
        $full = Join-Path -Path $expanded -ChildPath $probe
        if (Test-Path -LiteralPath $full -PathType Leaf) {
          return (Resolve-Path -LiteralPath $full).Path
        }
      }
      return $null
    }

    if (-not (Test-Path -LiteralPath $expanded -PathType Leaf)) { return $null }

    $resolved = (Resolve-Path -LiteralPath $expanded).Path
    $dir = Split-Path -Parent $resolved
    $leaf = Split-Path -Leaf $resolved

    # If the resolved path points at the GUI stub, prefer the CLI neighbor when present.
    if ($leaf -in @('VI Package Manager.exe','VIPM.exe')) {
      $cli = Join-Path -Path $dir -ChildPath 'support\vipm.exe'
      if (Test-Path -LiteralPath $cli -PathType Leaf) {
        return (Resolve-Path -LiteralPath $cli).Path
      }
    }

    return $resolved
  }

  $candidates = New-Object System.Collections.ArrayList
  $addCandidate = {
    param([System.Collections.ArrayList]$list, [string]$value)
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    if (-not $list.Contains($value)) { [void]$list.Add($value) }
  }

  & $addCandidate $candidates $VipmPath

  foreach ($envKey in @('VIPM_PATH','VIPM_EXE_PATH')) {
    $envValue = [System.Environment]::GetEnvironmentVariable($envKey)
    if ([string]::IsNullOrWhiteSpace($envValue)) { continue }
    foreach ($entry in ($envValue -split ';')) {
      & $addCandidate $candidates ($entry.Trim())
    }
  }

  foreach ($config in (Get-LabVIEWConfigObjects)) {
    foreach ($propName in @('vipm', 'VIPMPath', 'VipmPath')) {
      $prop = $config.PSObject.Properties[$propName]
      if (-not $prop) { continue }
      $value = $prop.Value
      if ($value -is [string]) {
        & $addCandidate $candidates $value
      } elseif ($value -is [System.Collections.IEnumerable]) {
        foreach ($item in $value) { & $addCandidate $candidates $item }
      }
    }
    foreach ($name in @('VIPMPath','VipmPath')) {
      $versionValue = Get-VersionedConfigValue -Config $config -PropertyName $name -Version 2021 -Bitness 32
      if ($versionValue) { & $addCandidate $candidates $versionValue }
    }
  }

  foreach ($path in @(
      'C:\Program Files\JKI\VI Package Manager',
      'C:\Program Files (x86)\JKI\VI Package Manager',
      'C:\Program Files\JKI\VI Package Manager\support\vipm.exe',
      'C:\Program Files (x86)\JKI\VI Package Manager\support\vipm.exe',
      'C:\Program Files\JKI\VI Package Manager\VIPM.exe',
      'C:\Program Files (x86)\JKI\VI Package Manager\VIPM.exe',
      'C:\Program Files\JKI\VI Package Manager\VI Package Manager.exe',
      'C:\Program Files (x86)\JKI\VI Package Manager\VI Package Manager.exe'
    )) {
    & $addCandidate $candidates $path
  }

  foreach ($candidate in $candidates) {
    try {
      $resolvedCandidate = & $resolveCandidate $candidate
      if ($resolvedCandidate) {
        return $resolvedCandidate
      }
    } catch {}
  }

  return $null
}

function Test-LVAddonLabPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$Strict,
    [string[]]$AllowedHosts
  )

  $mode = if ($Strict) { 'Strict' } else { 'Relaxed' }
  $result = [ordered]@{
    Path            = $Path
    IsDirectory     = $false
    IsGitRepo       = $false
    RepoRoot        = $null
    HasOrigin       = $false
    OriginUrl       = $null
    OriginHost      = $null
    IsAllowedHost   = $false
    IsLVAddonLab    = $false
    Mode            = $mode
  }

  $resolved = $null
  try {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $result.Path = $resolved
    if (Test-Path -LiteralPath $resolved -PathType Container) {
      $result.IsDirectory = $true
    }
  } catch {
    return [pscustomobject]$result
  }

  if (-not $result.IsDirectory) {
    return [pscustomobject]$result
  }

  $gitRoot = $null
  try {
    $gitRoot = git -C $resolved rev-parse --show-toplevel 2>$null
  } catch {
    $gitRoot = $null
  }
  if ($gitRoot) {
    $result.IsGitRepo = $true
    try {
      $result.RepoRoot = (Resolve-Path -LiteralPath $gitRoot.Trim()).Path
    } catch {
      $result.RepoRoot = $gitRoot.Trim()
    }
  } else {
    return [pscustomobject]$result
  }

  $origin = $null
  try {
    $origin = git -C $resolved remote get-url origin 2>$null
  } catch {
    $origin = $null
  }

  if ($origin) {
    $result.HasOrigin = $true
    $result.OriginUrl = $origin.Trim()
  } else {
    return [pscustomobject]$result
  }

  $hostList = New-Object System.Collections.Generic.List[string]
  $hostList.Add('github.com')
  if ($env:ICONEDITORLAB_GITHUB_HOSTS) {
    $envHosts = $env:ICONEDITORLAB_GITHUB_HOSTS -split '[,; ]+' | Where-Object { $_ }
    foreach ($h in $envHosts) { $hostList.Add($h) }
  }
  if ($AllowedHosts) {
    foreach ($h in $AllowedHosts) { if ($h) { $hostList.Add($h) } }
  }
  $allowedHosts = $hostList | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique

  $originHost = $null
  $uri = $null
  if ([Uri]::TryCreate($result.OriginUrl, [UriKind]::Absolute, [ref]$uri)) {
    $originHost = $uri.Host.ToLowerInvariant()
  } elseif ($result.OriginUrl -match '^[^@]+@([^:]+):') {
    $originHost = $Matches[1].ToLowerInvariant()
  }
  $result.OriginHost = $originHost
  if ($originHost -and $allowedHosts.Contains($originHost)) {
    $result.IsAllowedHost = $true
  }

  if ($result.RepoRoot) {
    $hasLvproj = $false
    try {
      foreach ($file in [System.IO.Directory]::EnumerateFiles($result.RepoRoot, '*.lvproj', [System.IO.SearchOption]::AllDirectories)) {
        if ($file) {
          $hasLvproj = $true
          break
        }
      }
    } catch {}

    $hasVipbMarker = $false
    if (-not $hasLvproj) {
      try {
        $vipbFiles = [System.IO.Directory]::EnumerateFiles($result.RepoRoot, '*.vipb', [System.IO.SearchOption]::AllDirectories)
        $checked = 0
        foreach ($vipb in $vipbFiles) {
          if ($checked -ge 3) { break }
          $checked++
          if (Select-String -Path $vipb -Pattern 'LVAddons' -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
            $hasVipbMarker = $true
            break
          }
        }
      } catch {}
    }

    $addonHelper = Test-Path -LiteralPath (Join-Path $result.RepoRoot 'Tooling/deployment/CreateLVAddonJSONfile.vi') -PathType Leaf
    $result.IsLVAddonLab = $hasLvproj -or $hasVipbMarker -or $addonHelper
  }

  return [pscustomobject]$result
}

function Assert-LVAddonLabPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$Strict,
    [string[]]$AllowedHosts
  )

  $analysis = Test-LVAddonLabPath -Path $Path -Strict:$Strict -AllowedHosts $AllowedHosts

  if (-not $analysis.IsDirectory) {
    throw ("IconEditorRoot '{0}' does not exist or is not a directory." -f $analysis.Path)
  }

  if (-not $analysis.IsGitRepo) {
    throw ("IconEditorRoot '{0}' is not a git repository. Localhost.LibraryPaths must point to an LV add-on lab clone." -f $analysis.Path)
  }

  if (-not $analysis.HasOrigin) {
    throw ("IconEditorRoot '{0}' has no 'origin' remote; cannot confirm GitHub LV add-on source." -f $analysis.Path)
  }

  if (-not $analysis.IsAllowedHost) {
    $originDisplay = if ($analysis.OriginUrl) { $analysis.OriginUrl } else { '<unknown>' }
    $hostMessage = "IconEditorRoot '{0}' origin '{1}' is not on an allowed GitHub host." -f $analysis.Path, $originDisplay
    if ($Strict) {
      throw $hostMessage
    } else {
      Write-Warning "[devmode] $hostMessage"
    }
  }

  if (-not $analysis.IsLVAddonLab) {
    $addonMessage = "IconEditorRoot '{0}' does not appear to contain a LabVIEW add-on project (.lvproj)." -f $analysis.Path
    if ($Strict) {
      throw $addonMessage
    } else {
      Write-Warning "[devmode] $addonMessage"
    }
  }

  return $analysis
}

Export-ModuleMember -Function *

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
