Param(
  [switch]$Login,
  [switch]$Quiet,
  [switch]$Validate,
  [switch]$EnsureGh  # also add .tools/bin to PATH and ensure gh is available
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
$binDir   = Join-Path $repoRoot '.tools\bin'
$secretsDir = Join-Path $repoRoot '.secrets'
$tokenFile  = Join-Path $secretsDir 'github_token.txt'

New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir     | Out-Null

# Ensure .tools/bin in PATH (current session)
$binPath = (Resolve-Path $binDir).Path
if (($env:PATH -split ';') -notcontains $binPath) {
  $env:PATH = "$binPath;" + $env:PATH
  if (-not $Quiet) { Write-Host "Added to PATH for this session: $binPath" }
}

# Ensure .gitignore guards tokens
$gi = Join-Path $secretsDir '.gitignore'
if (-not (Test-Path $gi)) {
  @('*','!.gitignore','!README.md') -join "`n" | Out-File -Encoding utf8NoBOM -FilePath $gi
}

if (-not (Test-Path $tokenFile)) {
  "" | Out-File -Encoding utf8NoBOM -FilePath $tokenFile
  if (-not $Quiet) {
    Write-Host "Created placeholder token file: $tokenFile"
    Write-Host "Paste your PAT (single line) and re-run this script."
  }
  exit 0
}

# Load into this session's env
$loader = Join-Path $repoRoot 'scripts\load_github_token.ps1'
if (Test-Path $loader) {
  . $loader
}

if (-not $env:GITHUB_TOKEN) {
  if (-not $Quiet) { Write-Warning "No token loaded. Ensure $tokenFile contains your PAT." }
  exit 1
}

function Test-GitHubToken([string]$token) {
  try {
    $headers = @{ Authorization = "token $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'x-cli-token-validator' }
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/rate_limit' -Headers $headers -Method Get -TimeoutSec 8 -ErrorAction Stop
    return $true
  } catch { return $false }
}

if ($Validate -or $Login) {
  $tok = (Get-Content -LiteralPath $tokenFile -Raw).Trim()
  # Soft format check: typical prefixes are ghp_ and github_pat_
  if (-not ($tok.StartsWith('ghp_') -or $tok.StartsWith('github_pat_'))) {
    if (-not $Quiet) { Write-Warning "Token format looks unusual (expected ghp_ or github_pat_ prefix); continuing with HTTP validation." }
  }
  $ok = $false
  if ($tok.Length -ge 20) {
    $ok = Test-GitHubToken -token $tok
  }
  if (-not $ok) {
    Write-Warning "Token validation failed (HTTP ping). Ensure the PAT is valid and not expired."
    Write-Warning "Reminder: for publishing/comments, the PAT should include at least the 'repo' scope."
    exit 3
  } elseif (-not $Quiet) {
    Write-Host "Token validation succeeded."
  }
}

if ($Login) {
  try {
    if ([string]::IsNullOrWhiteSpace($tok)) { throw "token file empty" }
    # Optionally ensure gh exists
    $ghExists = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghExists -and $EnsureGh) {
      if (-not $Quiet) { Write-Host "gh not found. Attempting portable install to .tools/bin …" }
      $latest = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/cli/cli/releases/latest"
      $asset = $latest.assets | Where-Object { $_.name -match 'windows_amd64\\.zip$' } | Select-Object -First 1
      if ($null -ne $asset) {
        $dlDir = Join-Path $repoRoot '.tools\gh'
        New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
        $zipPath = Join-Path $dlDir 'gh.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $dlDir -Force
        $ghExe = Get-ChildItem -Path $dlDir -Recurse -Filter 'gh.exe' | Select-Object -First 1
        if ($ghExe) { Copy-Item -Force $ghExe.FullName (Join-Path $binDir 'gh.exe') }
      }
      $ghExists = Get-Command gh -ErrorAction SilentlyContinue
    }
    if (-not $ghExists) { throw "gh CLI not found. Install gh or pass -EnsureGh to attempt portable install." }
    $prevGhToken = $env:GH_TOKEN
    $prevGitHubToken = $env:GITHUB_TOKEN
    try { $env:GH_TOKEN = $null; $env:GITHUB_TOKEN = $null } catch {}
    $tok | gh auth login --with-token | Out-Null
    # restore env
    if ($prevGhToken) { $env:GH_TOKEN = $prevGhToken } else { $env:GH_TOKEN = $tok }
    if ($prevGitHubToken) { $env:GITHUB_TOKEN = $prevGitHubToken } else { $env:GITHUB_TOKEN = $tok }
    if (-not $Quiet) { gh auth status | Write-Output }
  } catch {
    Write-Warning "gh auth login failed. $_"
    exit 2
  }
}

if (-not $Quiet) {
  Write-Host "Loaded token into env for this session (GITHUB_TOKEN, GH_TOKEN)."
}
