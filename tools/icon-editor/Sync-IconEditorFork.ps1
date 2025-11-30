#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoSlug,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vendorRoot = Join-Path $repoRoot 'vendor\icon-editor'
if (-not (Test-Path -LiteralPath $vendorRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $vendorRoot -Force | Out-Null
}

Write-Host ("[sync-icon-editor] Stubbed sync for '{0}'. No network calls performed." -f ($RepoSlug ?? 'local'))
