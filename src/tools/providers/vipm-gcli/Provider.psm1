#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gcliProviderPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'gcli' 'Provider.psm1'
if (-not (Test-Path -LiteralPath $gcliProviderPath -PathType Leaf)) {
    throw "GCli provider module not found at '$gcliProviderPath'."
}
Import-Module $gcliProviderPath -Force

function New-VipmProvider {
    $gcliProvider = New-GCliProvider
    $vipmProvider = New-Object PSObject
    $vipmProvider | Add-Member NoteProperty GCliProvider $gcliProvider
    $vipmProvider | Add-Member ScriptMethod Name { 'vipm-gcli' }
    $vipmProvider | Add-Member ScriptMethod ResolveBinaryPath {
        $this.GCliProvider.ResolveBinaryPath()
    }
    $vipmProvider | Add-Member ScriptMethod Supports {
        param($Operation)
        return @('InstallVipc') -contains $Operation
    }
    $vipmProvider | Add-Member ScriptMethod BuildArgs {
        param($Operation,$Params)
        if ($Operation -ne 'InstallVipc') {
            throw "vipm-gcli provider only supports InstallVipc operation (requested '$Operation')."
        }
        return $this.GCliProvider.BuildArgs('VipcInstall', $Params)
    }
    return $vipmProvider
}

Export-ModuleMember -Function New-VipmProvider

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