param()
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host 'Pester not found. Attempting to install (CurrentUser)...'
    try {
        Install-Module Pester -Scope CurrentUser -Force -MinimumVersion 5.3.0 -ErrorAction Stop
    } catch {
        Write-Warning 'Could not install Pester automatically. If Invoke-Pester fails, install Pester manually.'
    }
}

Import-Module Pester -ErrorAction SilentlyContinue
$pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($pester.Version.Major -ge 5) {
    Invoke-Pester -CI -Path (Join-Path $PSScriptRoot 'Ghops.Tests.ps1')
} else {
    Write-Host "Pester v$pester detected (<5); skipping ghops smoke tests."
}
