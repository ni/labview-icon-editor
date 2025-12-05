$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "vipb-bump-worktree.ps1 Parameters" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:Subject = Join-Path $script:RepoRoot 'scripts/labview/vipb-bump-worktree.ps1'
    }

    It "script exists" {
        Test-Path $script:Subject | Should -BeTrue
    }

    It "has valid PowerShell syntax" {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:Subject, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It "has TargetLabVIEWMinor parameter" {
        $params = (Get-Command $script:Subject).Parameters
        $params.ContainsKey('TargetLabVIEWMinor') | Should -BeTrue
    }

    It "TargetLabVIEWMinor validates 0 and 3" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['TargetLabVIEWMinor'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $attr.ValidValues | Should -Contain '0'
        $attr.ValidValues | Should -Contain '3'
    }

    It "has TargetBitness parameter" {
        $params = (Get-Command $script:Subject).Parameters
        $params.ContainsKey('TargetBitness') | Should -BeTrue
    }

    It "TargetBitness validates 32 and 64" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['TargetBitness'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $attr.ValidValues | Should -Contain '32'
        $attr.ValidValues | Should -Contain '64'
    }

    It "requires RepositoryPath" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['RepositoryPath'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
        $attr | Should -Not -BeNullOrEmpty
    }

    It "requires TargetLabVIEWVersion" {
        $params = (Get-Command $script:Subject).Parameters
        $attr = $params['TargetLabVIEWVersion'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
        $attr | Should -Not -BeNullOrEmpty
    }
}
