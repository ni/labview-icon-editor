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
        $script:content | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest\s*$'
    }

    It 'windows-github-hosted build job runs on windows-latest and is skipped for PRs' {
        $script:content | Should -Match "github.event_name != 'pull_request'"

        $script:content | Should -Match '(?m)build-lvlibp-windows-github-hosted:'
        
        $ghHostedBlock = [regex]::Match($script:content, '(?s)build-lvlibp-windows-github-hosted:.*?(?=\n  \w|\z)').Value
        $windowsContainerBlock = [regex]::Match($script:content, '(?s)build-lvlibp-windows-container:.*?(?=\n  \w|\z)').Value

        $ghHostedBlock | Should -Match "github.event_name != 'pull_request'" -Because 'github-hosted job must be skipped on PRs'
        $windowsContainerBlock | Should -Not -Match "github.event_name != 'pull_request'" -Because 'windows container job must run on PRs too'
    }

    It 'uses only official actions, local composites, and local reusable workflows' {
        $allowedLocal = @(
            './.github/actions/pylavi-ci',
            './.github/actions/vi-analyzer-ci',
            './.github/workflows/build-lvlibp-linux-container.yml',
            './.github/workflows/build-lvlibp-windows-container.yml',
            './.github/workflows/build-lvlibp-windows-github-hosted.yml'
        )

        $usesMatches = [regex]::Matches($script:content, '(?m)^\s*(?:-\s*)?uses:\s*(?<value>.+?)\s*$')
        $usesValues = @($usesMatches | ForEach-Object { $_.Groups['value'].Value.Trim() })

        foreach ($useValue in $usesValues) {
            $isOfficial = $useValue -match '^actions/'
            $isAllowedLocal = $allowedLocal -contains $useValue
            ($isOfficial -or $isAllowedLocal) | Should -BeTrue -Because "Unexpected uses target in CI pipeline: $useValue"
        }

        $usesValues | Should -Contain 'actions/checkout@v5'
        $usesValues | Should -Contain 'actions/upload-artifact@v6'
        $usesValues | Should -Contain './.github/actions/pylavi-ci'
        $usesValues | Should -Contain './.github/actions/vi-analyzer-ci'
        $usesValues | Should -Contain './.github/workflows/build-lvlibp-linux-container.yml'
        $usesValues | Should -Contain './.github/workflows/build-lvlibp-windows-container.yml'
        $usesValues | Should -Contain './.github/workflows/build-lvlibp-windows-github-hosted.yml'
    }

    It 'build jobs depend on run-metadata and version-gate' {
        $script:content | Should -Match 'build-lvlibp-linux-container'
        $script:content | Should -Match 'build-lvlibp-windows-container'
        $script:content | Should -Match 'build-lvlibp-windows-github-hosted'
    }

    It 'pipeline-contract waits for all build jobs' {
        $script:content | Should -Match 'build-lvlibp-linux-container'
        $script:content | Should -Match 'build-lvlibp-windows-container'
        $script:content | Should -Match 'build-lvlibp-windows-github-hosted'
        # skipped is acceptable for windows-github-hosted on PRs
        $script:content | Should -Match "ghHostedResult -notin @\('success', 'skipped'\)"
    }
}