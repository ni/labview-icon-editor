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
            './.github/workflows/build-lvlibp-windows-github-hosted.yml',
            './.github/workflows/build-vip-package.yml'
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
        $usesValues | Should -Contain './.github/workflows/build-vip-package.yml'
    }

    It 'build jobs depend on run-metadata and version-gate' {
        $script:content | Should -Match 'build-lvlibp-linux-container'
        $script:content | Should -Match 'build-lvlibp-windows-container'
        $script:content | Should -Match 'build-lvlibp-windows-github-hosted'
    }

    It 'passes the Windows x64 PPL artifact to the VIP workflow' {
        $vipBlock = [regex]::Match($script:content, '(?s)build-vip-package:.*?(?=\n  \w|\z)').Value
        $vipBlock | Should -Match 'needs: \[run-metadata, version-gate, build-lvlibp-windows-container\]'
        $vipBlock | Should -Match 'ppl_artifact_name: ci-lv-icon-x64-\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}'
    }

    It 'packages only the downloaded x64 PPL and declares 64-bit LabVIEW support' {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $vipWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github/workflows/build-vip-package.yml') -Raw
        $vipb = Get-Content -LiteralPath (Join-Path $repoRoot 'Tooling/deployment/NI Icon editor.vipb') -Raw

        $vipWorkflow | Should -Match 'actions/download-artifact@v6'
        $vipWorkflow | Should -Match '--labview-bitness 64'
        $vipWorkflow | Should -Match '-SupportedBitness 64'
        $vipWorkflow | Should -Not -Match 'lv_icon_x86\.lvlibp|SupportedBitness 32|labview-bitness 32'
        $vipb | Should -Match '<LV_32-Bit>false</LV_32-Bit>'
        $vipb | Should -Match '<LV_64-Bit>true</LV_64-Bit>'
        $vipb | Should -Not -Match 'lv_icon_x86\.lvlibp'
    }

    It 'pipeline-contract waits for all build jobs' {
        $script:content | Should -Match 'build-lvlibp-linux-container'
        $script:content | Should -Match 'build-lvlibp-windows-container'
        $script:content | Should -Match 'build-lvlibp-windows-github-hosted'
        # skipped is acceptable for windows-github-hosted on PRs
        $script:content | Should -Match "ghHostedResult -notin @\('success', 'skipped'\)"
    }
}