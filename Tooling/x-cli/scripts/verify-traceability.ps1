#!/usr/bin/env pwsh
<#!
.SYNOPSIS
  Verify that requirements in docs/traceability.yaml map to existing SRS docs
  and that each referenced source contains its requirement ID.

.DESCRIPTION
  Mirrors the behavior of scripts/verify-traceability.py but implemented in
  PowerShell to reduce Python dependencies. Parses the mapping using simple
  regex scans (no external modules).

.EXAMPLE
  pwsh ./scripts/verify-traceability.ps1

.OUTPUTS
  Writes errors to stderr and exits non-zero on failure.
!>
[CmdletBinding()]
param(
  [string]$Traceability = 'docs/traceability.yaml'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path . | Select-Object -ExpandProperty Path
$tracePath = Join-Path $root $Traceability
if (-not (Test-Path -LiteralPath $tracePath)) {
  Write-Error "traceability file not found: $Traceability"
  exit 2
}

$entries = @()
$currentId = $null
Get-Content -Raw -LiteralPath $tracePath -Encoding UTF8 | ForEach-Object {
  $_ -split "`n"
} | ForEach-Object {
  $line = $_
  if ($line -match "^\s*-\s*id:\s*((?:FGC|TEST)-REQ-[A-Z-]+-\d{3})") {
    $currentId = $matches[1]
    return
  }
  if ($currentId -and $line -match "^\s*source:\s*(\S+)") {
    $entries += [pscustomobject]@{ id = $currentId; source = $matches[1] }
    $currentId = $null
  }
}

$errors = @()
foreach ($e in $entries) {
  $rel = $e.source
  $path = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $path)) {
    $errors += "${($e.id)}: source file not found: $rel"
    continue
  }
  $text = Get-Content -Raw -LiteralPath $path -Encoding UTF8
  # Allow non-breaking hyphen variants by normalizing to a loose pattern
  $pattern = [Regex]::Escape($e.id).Replace('\-', '[-\u2011]')
  if (-not [Regex]::IsMatch($text, $pattern)) {
    $errors += "${($e.id)}: ID not found in $rel"
  }
}

if ($errors.Count -gt 0) {
  foreach ($err in $errors) { Write-Error $err }
  exit 1
}
exit 0

