[CmdletBinding(PositionalBinding=$false)]
Param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Prints which GitHub token source would be used by helper scripts.
# Order: GITHUB_USER_TOKEN -> keyring(x-cli/github_user_token) -> .secrets/github_user_token.txt -> GITHUB_TOKEN -> GH_TOKEN -> .secrets/github_token.txt -> github_token.txt
# Output: JSON with found, kind, source, length, token_preview (masked prefix).

function Mask-Token([string]$tok) {
  if ([string]::IsNullOrEmpty($tok)) { return "" }
  $pref = if ($tok.Length -ge 4) { $tok.Substring(0,4) } else { $tok }
  return "$pref***"
}

function Emit-Json([bool]$found, [string]$kind, [string]$source, [string]$tok) {
  $obj = [pscustomobject]@{
    found         = $found
    kind          = $kind
    source        = $source
    length        = ($tok | ForEach-Object { $_.Length })
    token_preview = (Mask-Token $tok)
  }
  $obj | ConvertTo-Json -Compress
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $here '..')

# 1) User token via env
if ($env:GITHUB_USER_TOKEN) {
  Emit-Json -found $true -kind 'user' -source 'env:GITHUB_USER_TOKEN' -tok $env:GITHUB_USER_TOKEN
  exit 0
}

# 2) User token via keyring (best-effort using Python keyring)
$keyTok = ''
try {
  $py = @'
try:
    import keyring
    t = keyring.get_password("x-cli", "github_user_token") or ""
    print(t.strip())
except Exception:
    print("")
'@
  $keyTok = (& python -c $py) -as [string]
  if ($null -ne $keyTok) { $keyTok = $keyTok.Trim() } else { $keyTok = '' }
} catch { $keyTok = '' }
if ($keyTok) {
  Emit-Json -found $true -kind 'user' -source 'keyring:x-cli/github_user_token' -tok $keyTok
  exit 0
}

# 3) User token via file
$userTokFile = Join-Path $root '.secrets/github_user_token.txt'
if (Test-Path $userTokFile) {
  try {
    $uTok = (Get-Content -LiteralPath $userTokFile -Raw).Trim()
  } catch { $uTok = '' }
  if ($uTok) {
    Emit-Json -found $true -kind 'user' -source '.secrets/github_user_token.txt' -tok $uTok
    exit 0
  }
}

# 4) Repo token via env
if ($env:GITHUB_TOKEN) {
  Emit-Json -found $true -kind 'repo' -source 'env:GITHUB_TOKEN' -tok $env:GITHUB_TOKEN
  exit 0
}
if ($env:GH_TOKEN) {
  Emit-Json -found $true -kind 'repo' -source 'env:GH_TOKEN' -tok $env:GH_TOKEN
  exit 0
}

# 5) Repo token via file
$repoTokFile = Join-Path $root '.secrets/github_token.txt'
if (Test-Path $repoTokFile) {
  try {
    $rTok = (Get-Content -LiteralPath $repoTokFile -Raw).Trim()
  } catch { $rTok = '' }
  if ($rTok) {
    Emit-Json -found $true -kind 'repo' -source '.secrets/github_token.txt' -tok $rTok
    exit 0
  }
}
$repoTokFile2 = Join-Path $root 'github_token.txt'
if (Test-Path $repoTokFile2) {
  try {
    $rTok = (Get-Content -LiteralPath $repoTokFile2 -Raw).Trim()
  } catch { $rTok = '' }
  if ($rTok) {
    Emit-Json -found $true -kind 'repo' -source 'github_token.txt' -tok $rTok
    exit 0
  }
}

Emit-Json -found $false -kind '' -source 'none' -tok ''

