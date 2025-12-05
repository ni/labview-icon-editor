$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "create-seeded-branch.ps1 Parameters" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:Subject = Join-Path $script:RepoRoot 'scripts/labview/create-seeded-branch.ps1'
    }

    It "script exists" {
        Test-Path $script:Subject | Should -BeTrue
    }

    It "has valid PowerShell syntax" {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:Subject, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It "has LabVIEWVersion with range 2020-2030" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['LabVIEWVersion'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $attr.MinRange | Should -Be 2020
        $attr.MaxRange | Should -Be 2030
    }

    It "has LabVIEWMinor with values 0 or 3" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['LabVIEWMinor'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $attr.ValidValues | Should -Contain '0'
        $attr.ValidValues | Should -Contain '3'
    }

    It "has Bitness with values 32 or 64" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['Bitness'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $attr.ValidValues | Should -Contain '32'
        $attr.ValidValues | Should -Contain '64'
    }
}
