[CmdletBinding(PositionalBinding=$false)]
Param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve repo root (x-cli/scripts/..)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $here '..')

$candidates = @(
  (Join-Path $repoRoot 'github_token.txt'),
  (Join-Path $repoRoot '.secrets/github_token.txt'),
  (Join-Path (Resolve-Path (Join-Path $repoRoot '..')) 'github_token.txt')
)

foreach ($p in $candidates) {
  if (Test-Path $p) {
    try {
      $tok = (Get-Content $p -Raw).Trim()
      if ($tok) {
        $env:GITHUB_TOKEN = $tok
        $env:GH_TOKEN = $tok
        Write-Verbose "Loaded GitHub token from $p"
        break
      }
    } catch {}
  }
}

if (-not $env:GITHUB_TOKEN) {
  Write-Verbose "No GitHub token file found; continuing without token."
}

# Also load a user OAuth token (device-flow) if present
try {
  $userTokenPath = Join-Path $repoRoot '.secrets/github_user_token.txt'
  if (Test-Path $userTokenPath) {
    $uTok = (Get-Content $userTokenPath -Raw).Trim()
    if ($uTok) {
      $env:GITHUB_USER_TOKEN = $uTok
      Write-Verbose "Loaded user token (GITHUB_USER_TOKEN) from $userTokenPath"
    }
  }
} catch {}
