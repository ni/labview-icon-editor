#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ReportPath,
    [string]$BaselineManifestPath,
    [string]$BaselineFixturePath,
    [string]$OutputDir,
    [string]$ResourceOverlayRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
if (-not (Test-Path 'variable:Global:InvokeValidateLocalStubLog')) {
    $Global:InvokeValidateLocalStubLog = @()
} elseif (-not $Global:InvokeValidateLocalStubLog) {
    $Global:InvokeValidateLocalStubLog = @()
}
$Global:InvokeValidateLocalStubLog += [pscustomobject]@{
    Command = 'Prepare'
    Parameters = [pscustomobject]@{
        OutputDir = $OutputDir
    }
}
if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
'{"schema":"icon-editor/vi-diff-requests@v1","count":1,"requests":[{"category":"test","relPath":"tests\\StubTest.vi","base":null,"head":"head.vi"}]}' | Set-Content -LiteralPath (Join-Path $OutputDir 'vi-diff-requests.json') -Encoding utf8

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
