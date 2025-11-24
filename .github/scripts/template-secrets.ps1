<#
.SYNOPSIS
    Replaces placeholder tokens in a template file using values from workflow secrets (passed via environment variables or a JSON map).

.DESCRIPTION
    - Placeholders use the form {{TOKEN_NAME}}.
    - Values can come from:
        * The environment (supply token names via -Keys).
        * A JSON file containing an object of key/value pairs (-JsonMapPath).
      Both sources can be combined; JSON overrides environment only for matching keys.
    - Fails if a placeholder token is not supplied unless -AllowUnmapped is specified.
    - Never prints secret values; only prints which keys were used.

.PARAMETER TemplatePath
    Path to the input template file.

.PARAMETER OutputPath
    Path to write the rendered file.

.PARAMETER Keys
    Token names to pull from environment variables (e.g., -Keys "API_KEY","PASSWORD").

.PARAMETER JsonMapPath
    Path to a JSON file containing an object of key/value pairs to use for substitution.

.PARAMETER AllowUnmapped
    If set, leaves placeholders intact when no value is provided instead of failing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TemplatePath,
    [Parameter(Mandatory)][string]$OutputPath,
    [string[]]$Keys,
    [string]$JsonMapPath,
    [switch]$AllowUnmapped
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$TemplatePath = (Resolve-Path -LiteralPath $TemplatePath).Path
if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template file not found: $TemplatePath"
}

if (-not $Keys -and -not $JsonMapPath) {
    throw "Provide at least one source of values via -Keys and/or -JsonMapPath."
}

$valueMap = @{}

if ($JsonMapPath) {
    $jsonPath = (Resolve-Path -LiteralPath $JsonMapPath).Path
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        throw "JSON map file not found: $JsonMapPath"
    }
    $json = Get-Content -LiteralPath $jsonPath -Raw
    $obj = $null
    try {
        $obj = $json | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON map at '$jsonPath': $($_.Exception.Message)"
    }
    if (-not $obj.PSObject.Properties.Name.Count) {
        throw "JSON map at '$jsonPath' does not contain any key/value pairs."
    }
    foreach ($prop in $obj.PSObject.Properties) {
        $valueMap[$prop.Name] = [string]$prop.Value
    }
}

foreach ($k in ($Keys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    $envVal = [Environment]::GetEnvironmentVariable($k)
    if ([string]::IsNullOrEmpty($envVal)) {
        throw "Environment variable '$k' was not set."
    }
    $valueMap[$k] = $envVal
}

if ($valueMap.Count -eq 0) {
    throw "No values were loaded from -Keys or -JsonMapPath."
}

$templateContent = Get-Content -LiteralPath $TemplatePath -Raw
$pattern = '{{\s*(?<key>[A-Za-z0-9_.:-]+)\s*}}'
$missing = [System.Collections.Generic.HashSet[string]]::new()
$used = [System.Collections.Generic.HashSet[string]]::new()

$rendered = [regex]::Replace($templateContent, $pattern, {
    param($m)
    $key = $m.Groups['key'].Value
    if ($valueMap.ContainsKey($key)) {
        $used.Add($key) | Out-Null
        return $valueMap[$key]
    }
    $missing.Add($key) | Out-Null
    return $m.Value
})

if (-not $AllowUnmapped -and $missing.Count -gt 0) {
    $missingList = ($missing.ToArray() -join ', ')
    throw "Missing values for tokens: $missingList"
}

$outDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
Set-Content -LiteralPath $OutputPath -Value $rendered -Encoding UTF8

Write-Host ("Templated {0} placeholders into {1}" -f $used.Count, $OutputPath)
if ($used.Count -gt 0) {
    Write-Host ("Keys used (values not shown): {0}" -f ($used.ToArray() -join ', '))
}
if ($missing.Count -gt 0 -and $AllowUnmapped) {
    Write-Warning ("Placeholders left unmapped: {0}" -f ($missing.ToArray() -join ', '))
}
