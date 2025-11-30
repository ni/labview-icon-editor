Param(
  [string]$BinPath,
  [switch]$Quiet,
  [switch]$AllHosts,           # also write to CurrentUserAllHosts profile
  [switch]$WindowsPowerShell,  # also write WindowsPowerShell profile if present
  [switch]$EchoOnce            # add an optional per-session notice snippet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
if (-not $BinPath -or [string]::IsNullOrWhiteSpace($BinPath)) {
  $BinPath = Join-Path $repoRoot '.tools\bin'
}
$BinPath = (Resolve-Path -LiteralPath $BinPath -ErrorAction SilentlyContinue) ?? $BinPath

New-Item -ItemType Directory -Force -Path $BinPath | Out-Null

$markerBegin = '# >>> x-cli PATH bootstrap >>>'
$markerEnd   = '# <<< x-cli PATH bootstrap <<<'
$abs = (Resolve-Path $BinPath).Path
$snippet = @(
  $markerBegin,
  "# Added by scripts/ghops/tools/bootstrap-path.ps1",
  "if (Test-Path '$abs') {",
  "  if ((`$env:PATH -split ';') -notcontains '$abs') { `$env:PATH = '$abs;' + `$env:PATH }",
  "}",
  $markerEnd
) -join "`n"

# Optional notice snippet (once per session)
$noticeBegin = '# >>> x-cli PATH notice >>>'
$noticeEnd   = '# <<< x-cli PATH notice <<<'
$notice = @(
  $noticeBegin,
  "# Optional: echo a short PATH confirmation once per session",
  "if (Test-Path '$abs') {",
  "  if (-not `$env:XCLI_TOOLS_PATH_NOTICE_SHOWN) {",
  "    `$env:XCLI_TOOLS_PATH_NOTICE_SHOWN = '1'",
  "    Write-Host \"x-cli tools on PATH: $abs\" -ForegroundColor DarkCyan",
  "  }",
  "}",
  $noticeEnd
) -join "`n"

function Add-ToProfile([string]$profilePath) {
  $dir = Split-Path -Parent $profilePath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Force -Path $profilePath | Out-Null }
  $content = Get-Content -LiteralPath $profilePath -ErrorAction SilentlyContinue -Raw
  if ($content -and $content.Contains($markerBegin)) { return $false }
  Add-Content -LiteralPath $profilePath -Value ("`n" + $snippet + "`n") -Encoding utf8NoBOM
  return $true
}

function Add-NoticeToProfile([string]$profilePath) {
  if (-not $EchoOnce) { return $false }
  $dir = Split-Path -Parent $profilePath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Force -Path $profilePath | Out-Null }
  $content = Get-Content -LiteralPath $profilePath -ErrorAction SilentlyContinue -Raw
  if ($content -and $content.Contains($noticeBegin)) { return $false }
  Add-Content -LiteralPath $profilePath -Value ("`n" + $notice + "`n") -Encoding utf8NoBOM
  return $true
}

$written = @()
$targets = @($PROFILE.CurrentUserCurrentHost)
if ($AllHosts) { $targets += $PROFILE.CurrentUserAllHosts }
if ($WindowsPowerShell) {
  $winPs = Join-Path $HOME 'Documents\WindowsPowerShell\Profile.ps1'
  $targets += $winPs
}

foreach ($p in $targets | Select-Object -Unique) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }
  $added = $false
  if (Add-ToProfile -profilePath $p) { $added = $true }
  if (Add-NoticeToProfile -profilePath $p) { $added = $true }
  if ($added) { $written += $p }
}

if (-not $Quiet) {
  if ($written.Count -gt 0) {
    Write-Host "Added PATH bootstrap for x-cli to:" -ForegroundColor Green
    $written | ForEach-Object { Write-Host "  $_" }
    Write-Host "Open a new terminal for changes to take effect." -ForegroundColor Yellow
  } else {
    Write-Host "PATH bootstrap already present in profile(s)." -ForegroundColor Cyan
  }
}

# Friendly hint for GitKraken CLI passthrough (dev shells only)
if (-not $Quiet -and -not ($env:CI -or $env:GITHUB_ACTIONS)) {
  if (Get-Command gk -ErrorAction SilentlyContinue) {
    Write-Host "GitKraken CLI detected. Enable passthrough with USE_GK_PASSTHROUGH=1 or force with GIT_TOOL=gk." -ForegroundColor DarkYellow
  }
}
