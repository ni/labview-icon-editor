param(
  [string] $DiagnosticsPath = 'telemetry/stage3-diagnostics.json',
  [string] $SchemaPath = 'docs/schemas/stage3-diagnostics.schema.json',
  [switch] $Strict
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Error $msg; exit 1 }

if (-not (Test-Path $DiagnosticsPath)) { Fail "Diagnostics JSON not found: $DiagnosticsPath" }
if (-not (Test-Path $SchemaPath)) { Write-Warning "Schema not found: $SchemaPath; performing minimal checks only." }

try {
  $diag = Get-Content $DiagnosticsPath -Raw | ConvertFrom-Json
} catch {
  Fail "Invalid JSON: $DiagnosticsPath — $($_.Exception.Message)"
}

# Minimal schema-less checks (portable)
$required = 'published','dry_run_forced','webhook_present','summary_path','comment_path','summary_bytes','comment_bytes','chunks'
foreach ($k in $required) {
  if (-not ($diag.PSObject.Properties.Name -contains $k)) { Fail "Missing required key: $k" }
}

if (@('true','false') -notcontains ($diag.published)) { Fail "published must be 'true' or 'false'" }
if (@('true','false') -notcontains ($diag.dry_run_forced)) { Fail "dry_run_forced must be 'true' or 'false'" }
if (@('true','false') -notcontains ($diag.webhook_present)) { Fail "webhook_present must be 'true' or 'false'" }
if (-not ($diag.summary_bytes -is [int]) -or $diag.summary_bytes -lt 0) { Fail "summary_bytes must be >= 0" }
if (-not ($diag.comment_bytes -is [int]) -or $diag.comment_bytes -lt 0) { Fail "comment_bytes must be >= 0" }

# Optional: if JSON Schema is available and python exists, validate against it
if (Test-Path $SchemaPath) {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($null -ne $python) {
    try {
      & $python.Path - <<'PY'
import sys, json
try:
    import jsonschema
except ImportError:
    sys.exit(0)
print('jsonschema available', file=sys.stderr)
PY
      if ($LASTEXITCODE -eq 0) {
        & $python.Path -m jsonschema -i $DiagnosticsPath $SchemaPath
        if ($LASTEXITCODE -ne 0) { Fail "JSON Schema validation failed" }
      }
    } catch {
      if ($Strict) { Fail "Python/jsonschema validation failed: $($_.Exception.Message)" } else { Write-Warning "Schema validation skipped: $($_.Exception.Message)" }
    }
  } else {
    if ($Strict) { Fail "Python not found; cannot run JSON Schema validation" } else { Write-Host "Python not found; minimal validation passed." }
  }
}

Write-Host "Diagnostics validation OK: $DiagnosticsPath"
exit 0

