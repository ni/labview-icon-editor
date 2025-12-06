# Legacy validator local runner (archived)
## Former path: scripts/ci/kv_local.ps1
param(
  [string]$OutDir = "_kv",
  [string]$Root   = ".",
  [string]$Zip    = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve Python (python > python3 > py -3)
$Python = (Get-Command python  -ErrorAction SilentlyContinue) `
       ?? (Get-Command python3 -ErrorAction SilentlyContinue) `
       ?? (Get-Command py      -ErrorAction SilentlyContinue)
if (-not $Python) { throw "Python not found on PATH (need python/python3/py)." }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$logPath  = Join-Path $OutDir 'validator.log'
$jsonPath = Join-Path $OutDir 'validator.json'

# Run validator (root or ZIP) and capture stdout → validator.log
if ($Zip) {
  & $Python.Source "scripts/knowledge_validator.py" --zip $Zip 2>&1 `
    | Tee-Object -FilePath $logPath | Out-Null
} else {
  & $Python.Source "scripts/knowledge_validator.py" --root $Root 2>&1 `
    | Tee-Object -FilePath $logPath | Out-Null
}

# Extract JSON after the anchored marker
$txt    = Get-Content -Raw -Path $logPath
$marker = '--JARVIS-VALIDATOR-JSON--'
$idx    = $txt.IndexOf($marker, [StringComparison]::Ordinal)
if ($idx -ge 0) {
  $json = $txt.Substring($idx + $marker.Length)
  $json | Set-Content -Encoding UTF8 -Path $jsonPath
} else {
  Write-Warning "Marker missing; no validator.json"
}

# Shape checks (ORDER, MARKER, JSON keys)
$patterns = '^Root:','^Manifest:','^Crosswalks:','^Glossary DoD:','^Edition Appendix:','^Policies PDFs:','^OVERALL:'
$okOrder = $true; $pos = -1
foreach ($p in $patterns) {
  $m = [regex]::Match($txt, $p, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $m.Success -or $m.Index -le $pos) { $okOrder = $false; break }
  $pos = $m.Index
}
$okMarker = ($idx -ge 0)

$okKeys = $false
try {
  if (Test-Path $jsonPath) {
    $j   = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
    $req = 'overall','roles','crosswalks','glossary_DoD','appendix_found','appendix_path','policies_pdf_note'
    $okKeys = ($req | ForEach-Object { $j.PSObject.Properties.Name -contains $_ }) -notcontains $false
  }
} catch { $okKeys = $false }

# Human-friendly status strings (avoid ternary)
$StatusOrder  = if ($okOrder)  { 'OK' }      else { 'FAIL' }
$StatusMarker = if ($okMarker) { 'OK' }      else { 'MISSING' }
$StatusJSON   = if ($okKeys)   { 'OK' }      else { 'MISSING' }

Write-Host ("Shape: ORDER={0} MARKER={1} JSON={2}" -f $StatusOrder, $StatusMarker, $StatusJSON)
Write-Host ("Artifacts: {0}, {1}" -f $logPath, $jsonPath)

# Keep local task non-failing for quick iteration
exit 0
