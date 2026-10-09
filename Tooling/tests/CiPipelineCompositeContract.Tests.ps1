#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI pipeline composite contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $workflowPath = Join-Path $repoRoot '.github/workflows/ci.yml'
        $pplWorkflowPath = Join-Path $repoRoot '.github/workflows/build-lvlibp-windows-container.yml'
        $vipWorkflowPath = Join-Path $repoRoot '.github/workflows/build-vip-package.yml'
        $vipBuilderPath = Join-Path $repoRoot 'Tooling/Build-VipFromPplInContainer.ps1'
        if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
            throw "Workflow not found: $workflowPath"
        }
        foreach ($requiredPath in @($pplWorkflowPath, $vipWorkflowPath, $vipBuilderPath)) {
            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                throw "Required VIP build file not found: $requiredPath"
            }
        }

        $script:content = Get-Content -LiteralPath $workflowPath -Raw
        $script:pplContent = Get-Content -LiteralPath $pplWorkflowPath -Raw
        $script:vipContent = Get-Content -LiteralPath $vipWorkflowPath -Raw
        $script:vipBuilderContent = Get-Content -LiteralPath $vipBuilderPath -Raw
    }

    It 'keeps canonical CI workflow identity and ubuntu hosted execution' {
        $script:content | Should -Match '(?m)^name:\s*CI Pipeline\s*$'
        $script:content | Should -Not -Match 'self-hosted'
        $script:content | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest\s*$'
            $script:content | Should -Match '(?m)^\s*- users/amrutha/vip-build\s*$'
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

    It 'passes the existing x64 PPL artifact into the VIP workflow' {
        $script:pplContent | Should -Match 'ppl_artifact_name: \$\{\{ steps\.version\.outputs\.ppl_artifact_name \}\}'
        $script:pplContent | Should -Match 'ppl_artifact_name=\$pplArtifactName'
        $script:pplContent | Should -Match 'name: lv_icon_x64_v\$\{\{ steps\.version\.outputs\.major \}\}'
        $script:content | Should -Match 'ppl_artifact_name: \$\{\{ needs\.build-lvlibp-windows-container\.outputs\.ppl_artifact_name \}\}'
        $script:content | Should -Match 'build-vip-package'
    }

    It 'packages only the downloaded x64 PPL inside LabVIEW Docker without editing the tracked VIPB' {
        $script:vipContent | Should -Match 'actions/download-artifact@v6'
        $script:vipContent | Should -Match 'Build-VipFromPplInContainer\.ps1'
        $script:vipContent | Should -Match 'nationalinstruments/labview:.*-windows'
        $script:vipContent | Should -Not -Match 'supported_bitness: ''32''|setup-labview@actions|setup-nipm@actions'
        $script:vipContent | Should -Match 'NI Icon editor\.ci\.vipb'
        $script:vipContent | Should -Match 'x86Entries.*RemoveChild'
        $script:vipContent | Should -Match "SelectSingleNode\('//LV_32-Bit'\)\.InnerText = 'false'"
        $script:vipBuilderContent | Should -Match '-SkipPreflight'
        $script:vipBuilderContent | Should -Match '-SupportedBitness 64'
        $script:vipBuilderContent | Should -Match 'lv_icon_x64\.lvlibp'
    }

    It 'pipeline-contract waits for all build jobs' {
        $script:content | Should -Match 'build-lvlibp-linux-container'
        $script:content | Should -Match 'build-lvlibp-windows-container'
        $script:content | Should -Match 'build-lvlibp-windows-github-hosted'
        $script:content | Should -Match 'build-vip-package'
        # skipped is acceptable for windows-github-hosted on PRs
        $script:content | Should -Match "ghHostedResult -notin @\('success', 'skipped'\)"
    }
}