[CmdletBinding(PositionalBinding=$false)]
Param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $here '..')

if ($IsWindows) {
  & (Join-Path $here 'setup-git-hooks.ps1')
  exit $LASTEXITCODE
}

# POSIX PowerShell: use the shell script if available
if (Test-Path (Join-Path $here 'setup-git-hooks.sh')) {
  bash (Join-Path $here 'setup-git-hooks.sh')
  exit $LASTEXITCODE
}

Write-Host 'No suitable hook installer found for this platform.'
exit 1

