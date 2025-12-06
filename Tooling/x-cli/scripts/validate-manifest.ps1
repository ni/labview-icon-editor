<#
  Validate a manifest generated in Stage 2 by ensuring each listed
  artifact exists and its SHA-256 checksum matches the manifest entry.
  Usage: ./scripts/validate-manifest.ps1 -Manifest telemetry/manifest.json
#>
Param(
  [Parameter(Mandatory=$true)][string]$Manifest,
  [string]$BaseDir = ".",
  [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoPath([string]$p) {
  # Avoid Resolve-Path on missing files; just join and later Test-Path.
  return (Join-Path -Path $BaseDir -ChildPath $p)
}

function HasProp([object]$obj, [string]$name) {
  return ($null -ne $obj) -and ($obj.PSObject.Properties.Name -contains $name)
}

if (-not (Test-Path -LiteralPath $Manifest)) {
  throw "Manifest file not found: $Manifest"
}

$raw = Get-Content -LiteralPath $Manifest -Raw
try {
  $json = $raw | ConvertFrom-Json
} catch {
  throw "Manifest is not valid JSON: $Manifest"
}

if (-not (HasProp $json 'schema') -or $json.schema -ne "pipeline.manifest/v1") {
  $msg = "Manifest schema expected 'pipeline.manifest/v1' but found '$($json.schema)'."
  if ($Strict) { throw $msg } else { Write-Warning $msg }
}

$missing = @()
if (-not (HasProp $json 'artifacts') -or -not (HasProp $json.artifacts 'win_x64')) { $missing += 'artifacts.win_x64' }
if (-not (HasProp $json 'artifacts') -or -not (HasProp $json.artifacts 'linux_x64')) { $missing += 'artifacts.linux_x64' }
if (-not (HasProp $json 'telemetry') -or -not (HasProp $json.telemetry 'summary')) { $missing += 'telemetry.summary' }
if ($missing.Count -gt 0) {
  throw "Manifest missing required entries: $($missing -join ', ')"
}

$entries = @()
if (HasProp $json 'artifacts') {
  if (HasProp $json.artifacts 'win_x64')   { $entries += @{ name="artifacts.win_x64";   item=$json.artifacts.win_x64 } }
  if (HasProp $json.artifacts 'linux_x64') { $entries += @{ name="artifacts.linux_x64"; item=$json.artifacts.linux_x64 } }
}
if (HasProp $json 'telemetry') {
  if (HasProp $json.telemetry 'summary') { $entries += @{ name="telemetry.summary"; item=$json.telemetry.summary } }
  if (HasProp $json.telemetry 'raw')     { $entries += @{ name="telemetry.raw";     item=$json.telemetry.raw } } # optional
}

foreach ($e in $entries) {
  $path   = $e.item.path
  $shaExp = ($e.item.sha256 | Out-String).Trim().ToLower()
  if ([string]::IsNullOrWhiteSpace($path))   { throw "Entry '$($e.name)' has empty path." }
  if ([string]::IsNullOrWhiteSpace($shaExp)) { throw "Entry '$($e.name)' has empty sha256." }
  if ($shaExp -notmatch '^[0-9a-f]{64}$') { throw "Entry '$($e.name)' sha256 is not 64 hex characters." }

  $full = Resolve-RepoPath $path
  if (-not (Test-Path -LiteralPath $full)) {
    throw "Entry '$($e.name)' path does not exist: $full"
  }

  $shaAct = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLower()
  if ($shaAct -ne $shaExp) {
    throw "SHA256 mismatch for '$($e.name)'. expected=$shaExp actual=$shaAct file=$full"
  } else {
    Write-Host "OK: $($e.name) -> $path"
  }
}

Write-Host "Manifest validated successfully."
