#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Branch protection policy contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:setPolicyPath = Join-Path $script:toolingRoot 'Set-SoloMaintainerBranchProtection.ps1'
        $script:verifyPolicyPath = Join-Path $script:toolingRoot 'Test-CiBranchProtection.ps1'
    }

    It 'Set-SoloMaintainerBranchProtection enforces app-pinned required checks' {
        (Test-Path -LiteralPath $script:setPolicyPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:setPolicyPath -Raw
        $content | Should -Match 'RequiredCheckAppId'
        $content | Should -Match 'CI Pipeline / CI Required / Lint\+Contract'
        $content | Should -Match 'app_id'
    }

    It 'Test-CiBranchProtection validates context and app-id alignment' {
        (Test-Path -LiteralPath $script:verifyPolicyPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:verifyPolicyPath -Raw
        $content | Should -Match 'RequiredContexts'
        $content | Should -Match 'RequiredCheckAppId'
        $content | Should -Match 'CI Pipeline / CI Required / Lint\+Contract'
        $content | Should -Match 'app_id_mismatches'
    }
}
