Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$secretsDir = Join-Path $repoRoot '.secrets'
$tokenFile  = Join-Path $secretsDir 'github_token.txt'

New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
if (-not (Test-Path $tokenFile)) {
  "" | Out-File -Encoding utf8NoBOM -FilePath $tokenFile
  Write-Host "Created placeholder token file: $tokenFile" -ForegroundColor Yellow
  Write-Host "Paste your GitHub PAT (single line), then re-run 'make first-run' or this script." -ForegroundColor Yellow
  exit 0
}

# 1) Load token and login (installs gh portable if missing)
& "$repoRoot/scripts/ghops/tools/use-local-github-token.ps1" -Validate -Login -EnsureGh

# 2) Persist PATH bootstrap with optional echo-once notice
& "$repoRoot/scripts/ghops/tools/bootstrap-path.ps1" -AllHosts -WindowsPowerShell -EchoOnce

# 3) Show status
try { gh --version | Write-Host } catch {}
gh auth status | Write-Host
Write-Host "First-run complete. Open a new terminal to get the PATH bootstrap and notice." -ForegroundColor Green

