[CmdletBinding(PositionalBinding=$false)]
Param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$hookDir = Join-Path $repoRoot '..' '.git' 'hooks'
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null

function Install-BatHook {
  param(
    [Parameter(Mandatory=$true)][string]$Name
  )
  $src = Join-Path $repoRoot 'hooks' ($Name + '.bat')
  if (-not (Test-Path $src)) { return }
  $dst = Join-Path $hookDir ($Name + '.bat')
  Copy-Item -Force $src $dst
}

foreach ($name in 'pre-commit','commit-msg','prepare-commit-msg','post-commit') {
  Install-BatHook -Name $name
}

Write-Host "Installed Windows-friendly hooks (.bat) into $hookDir"

