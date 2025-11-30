Param(
  [string]$Workflow = $env:GITHUB_WORKFLOW
, [string]$RunId    = $env:GITHUB_RUN_ID
, [string]$Commit   = $env:GITHUB_SHA
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Workflow) { $Workflow = 'ci.yml' }
if (-not $RunId)    { $RunId    = 'local' }
if (-not $Commit)   {
  try { $Commit = (git rev-parse --short=8 HEAD) } catch { $Commit = '' }
}
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

New-Item -ItemType Directory -Force -Path 'telemetry' | Out-Null

function Get-Sha256([string]$Path) {
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLower()
  }
  return ''
}

$win = 'dist/x-cli-win-x64'
$lin = 'dist/x-cli-linux-x64'
$sum = 'telemetry/summary.json'
$man = 'telemetry/manifest.json'

if (-not (Test-Path -LiteralPath $sum -PathType Leaf)) {
  Write-Error "ERROR: missing telemetry summary at $sum"
}
if (-not (Test-Path -LiteralPath $win -PathType Leaf) -or -not (Test-Path -LiteralPath $lin -PathType Leaf)) {
  Write-Error "ERROR: missing dist artifacts: expected $win and $lin"
}

$json = [ordered]@{
  schema = 'pipeline.manifest/v1'
  run    = @{ workflow=$Workflow; run_id=$RunId; commit=$Commit; ts=$ts }
  artifacts = [ordered]@{
    win_x64   = @{ path=$win; sha256=(Get-Sha256 $win) }
    linux_x64 = @{ path=$lin; sha256=(Get-Sha256 $lin) }
  }
  telemetry = @{ summary = @{ path=$sum; sha256=(Get-Sha256 $sum) } }
}

$json | ConvertTo-Json -Depth 6 | Out-File -FilePath $man -Encoding utf8
Write-Host "Wrote $man"

