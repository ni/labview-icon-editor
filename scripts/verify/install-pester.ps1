# Installs or updates Pester to at least the specified minimum version (CurrentUser scope).
[CmdletBinding()]
param(
    [Version] $MinimumVersion = [Version]'5.0.0'
)

$ErrorActionPreference = 'Stop'

Write-Host "Installing/Updating Pester to >= $MinimumVersion ..."

try {
    Install-Module Pester -Scope CurrentUser -Force -MinimumVersion $MinimumVersion -AllowClobber -ErrorAction Stop
} catch {
    throw "Failed to install/update Pester: $($_.Exception.Message)"
}

$module = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $module -or [Version]$module.Version -lt $MinimumVersion) {
    throw "Pester install did not meet minimum version $MinimumVersion; found '$($module.Version)'"
}

Write-Host "Pester installed/updated: $($module.Version)"
