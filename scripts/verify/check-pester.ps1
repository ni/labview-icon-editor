# Ensures Pester is available and meets a minimum version requirement.
[CmdletBinding()]
param(
    [Version] $MinimumVersion = [Version]'5.0.0'
)

$ErrorActionPreference = 'Stop'

Write-Host "Checking for Pester >= $MinimumVersion ..."

$module = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1

if (-not $module) {
    throw "Pester is not installed. Install it with: Install-Module Pester -Scope CurrentUser"
}

if ([Version]$module.Version -lt $MinimumVersion) {
    throw "Pester version $($module.Version) is below required $MinimumVersion. Update with: Install-Module Pester -Scope CurrentUser -Force"
}

Write-Host "Pester OK: $($module.Version)"
