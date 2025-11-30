#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $toolsRoot 'VendorTools.psm1') -Force

function Resolve-GCliBinaryPath {
    $path = Resolve-GCliPath
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'Unable to resolve g-cli executable path. Configure GCLI_EXE_PATH or labview-paths*.json.'
    }
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return (Resolve-Path -LiteralPath $path).Path
    }
    return $path
}

function Get-GCliArgs {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [hashtable]$Params
    )

    $Params = $Params ?? @{}

    switch ($Operation) {
        'VipbBuild' {
            $buildSpec = $Params.buildSpecPath
            $version   = $Params.buildVersion
            $release   = $Params.releaseNotesPath

            if ([string]::IsNullOrWhiteSpace($buildSpec)) {
                throw "VipbBuild requires 'buildSpecPath'."
            }
            if ([string]::IsNullOrWhiteSpace($version)) {
                throw "VipbBuild requires 'buildVersion'."
            }
            if ([string]::IsNullOrWhiteSpace($release)) {
                throw "VipbBuild requires 'releaseNotesPath'."
            }

            $lvVersion = if ($Params.ContainsKey('labviewVersion') -and $Params.labviewVersion) {
                [string]$Params.labviewVersion
            } else {
                '2025'
            }
            $architecture = if ($Params.ContainsKey('architecture') -and $Params.architecture) {
                [string]$Params.architecture
            } else {
                '64'
            }
            $timeout = if ($Params.ContainsKey('timeoutSeconds') -and $Params.timeoutSeconds) {
                [string]$Params.timeoutSeconds
            } else {
                '300'
            }

            $args = @(
                '--lv-ver', $lvVersion,
                '--arch', $architecture,
                'vipb',
                '--',
                '--buildspec', $buildSpec,
                '-v', $version,
                '--release-notes', $release
            )

            if (-not [string]::IsNullOrWhiteSpace($timeout)) {
                $args += @('--timeout', $timeout)
            }

            if ($Params.ContainsKey('additionalOptions') -and $Params.additionalOptions) {
                foreach ($opt in $Params.additionalOptions) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$opt)) {
                        $args += [string]$opt
                    }
                }
            }

            return $args
        }
        'VipcInstall' {
            $vipcPath      = $Params.vipcPath
            $applyVipcPath = $Params.applyVipcPath
            $targetVersion = $Params.targetVersion

            if ([string]::IsNullOrWhiteSpace($vipcPath)) {
                throw "VipcInstall requires 'vipcPath'."
            }
            if ([string]::IsNullOrWhiteSpace($applyVipcPath)) {
                throw "VipcInstall requires 'applyVipcPath'."
            }
            if ([string]::IsNullOrWhiteSpace($targetVersion)) {
                throw "VipcInstall requires 'targetVersion'."
            }

            $lvVersion = if ($Params.ContainsKey('labviewVersion') -and $Params.labviewVersion) {
                [string]$Params.labviewVersion
            } else {
                '2025'
            }
            $architecture = if ($Params.ContainsKey('labviewBitness') -and $Params.labviewBitness) {
                [string]$Params.labviewBitness
            } else {
                '64'
            }

            return @(
                '--lv-ver', $lvVersion,
                '--arch', $architecture,
                '-v', $applyVipcPath,
                '--',
                $vipcPath,
                $targetVersion
            )
        }
        default {
            throw "Operation '$Operation' not implemented for g-cli provider."
        }
    }
}

function New-GCliProvider {
    $provider = New-Object PSObject
    $provider | Add-Member ScriptMethod Name { 'gcli' }
    $provider | Add-Member ScriptMethod ResolveBinaryPath { Resolve-GCliBinaryPath }
    $provider | Add-Member ScriptMethod Supports {
        param($Operation)
        return @('VipbBuild','VipcInstall') -contains $Operation
    }
    $provider | Add-Member ScriptMethod BuildArgs {
        param($Operation,$Params)
        return (Get-GCliArgs -Operation $Operation -Params $Params)
    }
    return $provider
}

function New-LVProvider {
    return New-GCliProvider
}

Export-ModuleMember -Function New-GCliProvider, New-LVProvider


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