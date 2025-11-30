<#
  git-pass.ps1 — Optional GitKraken passthrough for git commands

  Usage (PowerShell):
    . scripts/ghops/tools/git-pass.ps1   # dot-source to load Invoke-Git
    Invoke-Git status

  Environment controls:
    - GIT_TOOL=auto|git|gk (default: auto)
    - USE_GK_PASSTHROUGH=1 to allow auto to choose gk when available
    - GIT_PASSTHROUGH_ALLOW='status,log,show' or '*' to widen allowlist
    - GIT_ALIAS=1 to Set-Alias git=Invoke-Git (not in CI)

  CI guard: If CI/GITHUB_ACTIONS are set, always use native git and ignore passthrough.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitTool() {
  if ($env:CI -or $env:GITHUB_ACTIONS) { return 'git' }
  $mode = $env:GIT_TOOL
  if ([string]::IsNullOrWhiteSpace($mode)) { $mode = 'auto' }
  switch ($mode) {
    'git' { return 'git' }
    'gk'  {
      if (-not (Get-Command gk -ErrorAction SilentlyContinue)) { throw 'GIT_TOOL=gk but gk not found on PATH.' }
      return 'gk'
    }
    default {
      $useGk = ($env:USE_GK_PASSTHROUGH -eq '1' -or $env:USE_GK_PASSTHROUGH -eq 'true')
      if ($useGk -and (Get-Command gk -ErrorAction SilentlyContinue)) { return 'gk' }
      return 'git'
    }
  }
}

function Test-Allow([string[]] $args) {
  $allow = $env:GIT_PASSTHROUGH_ALLOW
  if ([string]::IsNullOrWhiteSpace($allow)) {
    # default allowlist (read-only-ish)
    $allow = 'status,log,show,diff,rev-parse,describe,ls-files,remote -v,branch,config --get'
  }
  if ($allow.Trim() -eq '*') { return $true }
  $first = ($args | Select-Object -First 1)
  $sub = if ($null -ne $first) { $first.ToString().Trim() } else { '' }
  # include a tiny bit of context for multi-word commands
  $second = ($args | Select-Object -Skip 1 -First 1)
  $pair = if ($null -ne $second) { ($sub + ' ' + $second) } else { $sub }
  $items = $allow.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  foreach ($item in $items) {
    if ($pair -like $item) { return $true }
    if ($sub -like $item) { return $true }
  }
  return $false
}

function Invoke-Git {
  [CmdletBinding(PositionalBinding = $false)]
  param([Parameter(ValueFromRemainingArguments=$true)][string[]] $Args)

  $tool = Get-GitTool
  if ($tool -eq 'gk') {
    if (-not (Test-Allow -args $Args)) {
      Write-Error "Blocked by allowlist for gk passthrough. Command not allowed: '$($Args -join ' ')'. Set GIT_PASSTHROUGH_ALLOW='*' or include this command."
      exit 2
    }
  }

  if ($tool -eq 'gk') {
    & gk @Args
    $code = $LASTEXITCODE
  } else {
    & git @Args
    $code = $LASTEXITCODE
  }
  $global:LASTEXITCODE = $code
  return $code
}

if (-not ($env:CI -or $env:GITHUB_ACTIONS)) {
  if ($env:GIT_ALIAS -eq '1') {
    try { Set-Alias -Name git -Value Invoke-Git -ErrorAction Stop } catch { }
  }
}
# Export only when running as a module
try {
  if ($ExecutionContext -and $ExecutionContext.SessionState -and $ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Invoke-Git -ErrorAction SilentlyContinue
  }
} catch { }
