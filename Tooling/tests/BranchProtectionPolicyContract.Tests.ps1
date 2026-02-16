#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Branch protection policy contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:setPolicyPath = Join-Path $script:toolingRoot 'Set-SoloMaintainerBranchProtection.ps1'
        $script:verifyPolicyPath = Join-Path $script:toolingRoot 'Test-CiBranchProtection.ps1'
    }

    It 'Set-SoloMaintainerBranchProtection enforces PowerShell Lint + Pipeline Contract contexts' {
        (Test-Path -LiteralPath $script:setPolicyPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:setPolicyPath -Raw
        $content | Should -Match 'CI Pipeline / PowerShell Lint'
        $content | Should -Match 'CI Pipeline / Pipeline Contract'
    }

    It 'Test-CiBranchProtection defaults to PowerShell Lint + Pipeline Contract contexts' {
        (Test-Path -LiteralPath $script:verifyPolicyPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:verifyPolicyPath -Raw
        $content | Should -Match 'RequiredContexts'
        $content | Should -Match 'CI Pipeline / PowerShell Lint'
        $content | Should -Match 'CI Pipeline / Pipeline Contract'
    }
}
