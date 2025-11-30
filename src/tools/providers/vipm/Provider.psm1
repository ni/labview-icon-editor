#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NOTE: This is the classic VIPM (desktop/CLI) provider. New automation flows
# (x-cli, Codex, CI) should prefer the vipm-gcli/vipmcli toolchains and
# providers under tools/providers/vipm-gcli + tools/providers/gcli. This
# provider is retained for legacy, display-only, or manual workflows.

$toolsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $toolsRoot 'VendorTools.psm1') -Force

function Resolve-VipmBinaryPath {
    $path = Resolve-VIPMPath
    if ([string]::IsNullOrWhiteSpace($path)) {
        $cliCommand = Get-Command vipm -ErrorAction SilentlyContinue
        if ($cliCommand) {
            return $cliCommand.Source
        }

        throw 'Unable to resolve VIPM executable path. Configure VIPM_PATH/VIPM_EXE_PATH or update configs/labview-paths*.json.'
    }

    $candidatePath = $null

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $candidatePath = (Resolve-Path -LiteralPath $path).Path
    } elseif (Test-Path -LiteralPath $path -PathType Container) {
        foreach ($exeName in @('support\vipm.exe','vipm.exe','VIPM.exe','VI Package Manager.exe')) {
            $possible = Join-Path $path $exeName
            if (Test-Path -LiteralPath $possible -PathType Leaf) {
                $candidatePath = (Resolve-Path -LiteralPath $possible).Path
                break
            }
        }
    }

    if (-not $candidatePath) {
        throw "Unable to resolve VIPM executable path from '$path'. Configure VIPM_PATH/VIPM_EXE_PATH or update configs/labview-paths*.json."
    }

    return $candidatePath
}

function Get-VipmArgs {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [hashtable]$Params
    )

    $Params = $Params ?? @{}

    switch ($Operation) {
        'InstallVipc' {
            $vipc = $Params.vipcPath
            if ([string]::IsNullOrWhiteSpace($vipc)) {
                throw "InstallVipc requires 'vipcPath'."
            }

            $args = @(
                '-vipc', $vipc,
                '-q'
            )

            if ($Params.ContainsKey('labviewVersion') -and $Params.labviewVersion) {
                $args += @('-lvversion', [string]$Params.labviewVersion)
            }
            if ($Params.ContainsKey('labviewBitness') -and $Params.labviewBitness) {
                $args += @('-lvbitness', [string]$Params.labviewBitness)
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
        'BuildVip' {
            $vipb = $Params.vipbPath
            if ([string]::IsNullOrWhiteSpace($vipb)) {
                throw "BuildVip requires 'vipbPath'."
            }

            $args = @(
                '-vipb', $vipb,
                '-q'
            )

            if ($Params.ContainsKey('outputDirectory') -and $Params.outputDirectory) {
                $args += @('-output', [string]$Params.outputDirectory)
            }
            if ($Params.ContainsKey('buildVersion') -and $Params.buildVersion) {
                $args += @('-version', [string]$Params.buildVersion)
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
        default {
            throw "Operation '$Operation' is not implemented for the VIPM provider."
        }
    }
}

function New-VipmProvider {
    $provider = New-Object PSObject
    $provider | Add-Member ScriptMethod Name { 'vipm' }
    $provider | Add-Member ScriptMethod ResolveBinaryPath { Resolve-VipmBinaryPath }
    $provider | Add-Member ScriptMethod Supports {
        param($Operation)
        return @('InstallVipc','BuildVip') -contains $Operation
    }
    $provider | Add-Member ScriptMethod BuildArgs {
        param($Operation,$Params)
        return (Get-VipmArgs -Operation $Operation -Params $Params)
    }
    return $provider
}

function New-LVProvider {
    return New-VipmProvider
}

Export-ModuleMember -Function New-VipmProvider, New-LVProvider

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
