<#
.SYNOPSIS
  Dump g-cli --help output for quick inspection.

.DESCRIPTION
  Locates g-cli on PATH (or the default Windows install path) and prints
  `g-cli --help` output. Optionally writes the output to a file.

.PARAMETER OutputPath
  Optional path to write the help output; if omitted, only prints to stdout.
#>

[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Try to locate g-cli
$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli -and $IsWindows) {
    $default = 'C:\Program Files\G-CLI\bin\g-cli.exe'
    if (Test-Path -LiteralPath $default) {
        $gcli = [pscustomobject]@{ Source = $default }
    }
}

if (-not $gcli) {
    throw "g-cli not found on PATH or default install location. Please install g-cli."
}

Write-Host "Using g-cli at: $($gcli.Source)"
$output = & $gcli.Source --help 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "g-cli --help failed with exit code $LASTEXITCODE. Output: $($output -join '; ')"
}

$output | Write-Output

if ($OutputPath) {
    $resolved = Resolve-Path -LiteralPath (Split-Path -Parent $OutputPath) -ErrorAction SilentlyContinue
    if (-not $resolved) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force
    }
    Set-Content -LiteralPath $OutputPath -Value ($output -join [Environment]::NewLine) -Encoding UTF8
    Write-Host "g-cli help written to $OutputPath"
}
