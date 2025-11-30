#Requires -Version 7.0

[CmdletBinding()]
param (
    [string]$MinimumSupportedLVVersion,
    [string]$VIP_LVVersion,
    [string[]]$SupportedBitness = @('64'),
    [string]$RelativePath = (Resolve-Path '.').ProviderPath,
    [string]$VIPCPath,
    [switch]$DisplayOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helperModule = Join-Path $PSScriptRoot 'VipmDependencyHelpers.psm1'
if (-not (Test-Path -LiteralPath $helperModule -PathType Leaf)) {
    throw "VipmDependencyHelpers.psm1 not found at '$helperModule'."
}
Import-Module $helperModule -Force

Write-Verbose "Parameters:"
Write-Verbose " - MinimumSupportedLVVersion: $MinimumSupportedLVVersion"
Write-Verbose " - VIP_LVVersion:             $VIP_LVVersion"
Write-Verbose " - SupportedBitness:          $($SupportedBitness -join ', ')"
Write-Verbose " - RelativePath:              $RelativePath"
Write-Verbose " - VIPCPath:                  $VIPCPath"
Write-Verbose " - DisplayOnly:               $($DisplayOnly.IsPresent)"

$ResolvedRelativePath = (Resolve-Path -Path $RelativePath -ErrorAction Stop).ProviderPath

$installProviderName = 'vipm-gcli'
$displayProviderName = 'vipm'
$ProviderName = if ($DisplayOnly) { $displayProviderName } else { $installProviderName }
$ProviderName = $ProviderName.ToLowerInvariant()
Write-Verbose " - ProviderName:              $ProviderName"

$expandedBitness = @()
foreach ($entry in $SupportedBitness) {
    if ([string]::IsNullOrWhiteSpace($entry)) { continue }
    $expandedBitness += ($entry -split '[,\s]+' | Where-Object { $_ })
}
if ($expandedBitness) {
    $SupportedBitness = $expandedBitness
}

if (-not $DisplayOnly) {
    if (-not $VIPCPath) {
        $vipcFiles = @(Get-ChildItem -Path $ResolvedRelativePath -Filter *.vipc)
        if ($vipcFiles.Count -eq 0) {
            throw "No .vipc file found in '$ResolvedRelativePath'."
        }
        if ($vipcFiles.Count -gt 1) {
            throw "Multiple .vipc files found in '$ResolvedRelativePath'. Specify -VIPCPath."
        }
        $VIPCPath = $vipcFiles[0].FullName
    } elseif (-not [System.IO.Path]::IsPathRooted($VIPCPath)) {
        $VIPCPath = (Resolve-Path -Path (Join-Path $ResolvedRelativePath $VIPCPath) -ErrorAction Stop).ProviderPath
    } else {
        $VIPCPath = (Resolve-Path -Path $VIPCPath -ErrorAction Stop).ProviderPath
    }
    if (-not (Test-Path -LiteralPath $VIPCPath -PathType Leaf)) {
        throw "The .vipc file does not exist at '$VIPCPath'."
    }
}

if ($DisplayOnly -and $ProviderName -ne 'vipm') {
    throw "DisplayOnly runs require the classic 'vipm' provider. '$ProviderName' was requested."
}

$vipmModulePath = Join-Path $ResolvedRelativePath 'tools' 'Vipm.psm1'
if (-not (Test-Path -LiteralPath $vipmModulePath -PathType Leaf)) {
    throw "VIPM module not found at '$vipmModulePath'."
}
Import-Module $vipmModulePath -Force

$versionsToApply = [System.Collections.Generic.List[string]]::new()
$versionsToApply.Add([string]$MinimumSupportedLVVersion) | Out-Null
if ($VIP_LVVersion -and ($VIP_LVVersion -ne $MinimumSupportedLVVersion)) {
    $versionsToApply.Add([string]$VIP_LVVersion) | Out-Null
}
$uniqueVersions = $versionsToApply | Select-Object -Unique

$bitnessList = @()
foreach ($bitness in $SupportedBitness) {
    if ([string]::IsNullOrWhiteSpace($bitness)) { continue }
    $normalized = $bitness.Trim()
    if ($normalized -notin @('32','64')) {
        throw "SupportedBitness must be 32 or 64. Invalid value '$bitness'."
    }
    if ($bitnessList -notcontains $normalized) {
        $bitnessList += $normalized
    }
}
if (-not $bitnessList) {
    $bitnessList = @('64')
}

$vipmTelemetryRoot = Initialize-VipmTelemetry -RepoRoot $ResolvedRelativePath
$collectedPackages = New-Object System.Collections.Generic.List[object]

foreach ($bitness in $bitnessList) {
    foreach ($version in $uniqueVersions) {
        $vipcForValidation = if ($DisplayOnly) { $null } else { $VIPCPath }
        Test-VipmCliReady -LabVIEWVersion $version -LabVIEWBitness $bitness -RepoRoot $ResolvedRelativePath -ProviderName $ProviderName -VipcPath $vipcForValidation | Out-Null
        if ($DisplayOnly) {
            $collectedPackages.Add((Show-VipmDependencies -LabVIEWVersion $version -LabVIEWBitness $bitness -TelemetryRoot $vipmTelemetryRoot -ProviderName $ProviderName)) | Out-Null
        } else {
            Write-Output ("Applying dependencies via provider '{0}' for LabVIEW {1} ({2}-bit)..." -f $ProviderName, $version, $bitness)
            $collectedPackages.Add((Install-VipmVipc -VipcPath $VIPCPath -LabVIEWVersion $version -LabVIEWBitness $bitness -RepoRoot $ResolvedRelativePath -TelemetryRoot $vipmTelemetryRoot -ProviderName $ProviderName)) | Out-Null
        }
    }
}

if ($DisplayOnly) {
    Write-Host 'Displayed vipmcli/g-cli dependencies:'
} else {
    Write-Host ("Successfully applied dependencies using provider '{0}'." -f $ProviderName)
}

Write-Host '=== vipmcli Packages ==='
foreach ($entry in $collectedPackages) {
    Write-Host ("LabVIEW {0} ({1}-bit)" -f $entry.version, $entry.bitness)
    foreach ($pkg in $entry.packages) {
        Write-Host ("  - {0} ({1}) v{2}" -f $pkg.name, $pkg.identifier, $pkg.version)
    }
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
