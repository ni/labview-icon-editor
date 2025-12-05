#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetModule = Join-Path $repoRoot 'src' 'tools' 'VendorTools.psm1'
if (-not (Test-Path -LiteralPath $targetModule -PathType Leaf)) {
    throw "VendorTools module not found at '$targetModule'."
}

Import-Module -Name $targetModule -Force -Global | Out-Null
