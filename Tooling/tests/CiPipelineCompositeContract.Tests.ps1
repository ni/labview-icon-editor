#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI pipeline composite contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $workflowPath = Join-Path $repoRoot '.github/workflows/ci.yml'
        if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
            throw "Workflow not found: $workflowPath"
        }

        $script:content = Get-Content -LiteralPath $workflowPath -Raw
    }

    It 'keeps canonical CI workflow identity and ubuntu hosted execution' {
        $script:content | Should -Match '(?m)^name:\s*CI Pipeline\s*$'
        $script:content | Should -Not -Match 'self-hosted'
        $script:content | Should -Not -Match 'windows-latest'
        $script:content | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest\s*$'
    }

    It 'uses only official actions plus local pylavi and VI Analyzer composites' {
        $allowedLocal = @(
            './.github/actions/pylavi-ci',
            './.github/actions/vi-analyzer-ci'
        )

        $usesMatches = [regex]::Matches($script:content, '(?m)^\s*(?:-\s*)?uses:\s*(?<value>.+?)\s*$')
        $usesValues = @($usesMatches | ForEach-Object { $_.Groups['value'].Value.Trim() })

        foreach ($useValue in $usesValues) {
            $isOfficial = $useValue -match '^actions/'
            $isAllowedLocal = $allowedLocal -contains $useValue
            ($isOfficial -or $isAllowedLocal) | Should -BeTrue -Because "Unexpected uses target in CI pipeline: $useValue"
        }

        $usesValues | Should -Contain 'actions/checkout@v4'
        $usesValues | Should -Contain 'actions/upload-artifact@v4'
        $usesValues | Should -Contain './.github/actions/pylavi-ci'
        $usesValues | Should -Contain './.github/actions/vi-analyzer-ci'
    }
}
