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

    It 'vip build job runs only on push (PR merge) after the Linux PPL build' {
        $vipBlock = [regex]::Match($script:content, '(?s)build-vip-linux-container:.*?(?=\n  \w|\z)').Value

        $vipBlock | Should -Match "if:\s*github.event_name == 'push'" -Because 'VIP build needs VIPM secrets, which only exist on merge runs'
        $vipBlock | Should -Match 'needs:\s*build-lvlibp-linux-container'
        $vipBlock | Should -Match 'uses:\s*ni/open-source/\.github/workflows/reusable-build-vip-linux\.yml@actions'
        $script:content | Should -Match "vipResult -notin @\('success', 'skipped'\)"
    }

    It 'uses only official actions, local composites, and approved reusable workflows' {
        $allowedLocal = @(
            './.github/actions/pylavi-ci',
            './.github/actions/vi-analyzer-ci',
            './.github/workflows/build-lvlibp-linux-container.yml',
            './.github/workflows/build-lvlibp-windows-container.yml',
            './.github/workflows/build-lvlibp-windows-github-hosted.yml',
            './.github/workflows/generate-sbom.yml',
            'ni/open-source/.github/workflows/reusable-build-vip-linux.yml@actions'
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

    It 'generates the SBOM only after a PR is merged' {
        $sbomBlock = [regex]::Match($script:content, '(?ms)^  sbom:.*?(?=^  [\w-]+:|\z)').Value
        $sbomBlock | Should -Match 'uses:\s*\./\.github/workflows/generate-sbom\.yml'
        $mergeCondition = "github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged == true"
        $sbomBlock | Should -Match ('(?m)^    if: ' + [regex]::Escape($mergeCondition) + '\s*$')
        $script:content | Should -Match '(?m)^      - closed\s*$'

        $contractBlock = [regex]::Match($script:content, '(?ms)^  pipeline-contract:.*?(?=^  [\w-]+:|\z)').Value
        $contractBlock | Should -Match 'needs:\s*\[[^\]]*\bsbom\b'
        $contractBlock | Should -Match 'SBOM_RESULT:\s*\$\{\{ needs\.sbom\.result \}\}'
        $contractBlock | Should -Match ('SBOM_REQUIRED: \$\{\{ ' + [regex]::Escape($mergeCondition) + ' \}\}')
        $contractBlock | Should -Match 'if \(\$env:SBOM_REQUIRED -eq ''true''\) \{\s*\$results\[''sbom''\] = \$env:SBOM_RESULT'
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