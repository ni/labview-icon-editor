#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW parity workflow build-spec contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/labview-parity.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
    }

    It 'removes run_build_spec input surface and output wiring' {
        $workflowContent | Should -Not -Match 'run_build_spec'
    }

    It 'uses mandatory --build-spec true in parity run invocations' {
        $trueFlagMatches = [regex]::Matches($workflowContent, '--build-spec\s+true')
        $trueFlagMatches.Count | Should -BeGreaterOrEqual 2
        $workflowContent | Should -Not -Match '--build-spec\s+"\$\{\{'
    }

    It 'does not gate parity verification or uploads on build-spec toggles' {
        $workflowContent | Should -Not -Match 'outputs\.run_build_spec'
        $workflowContent | Should -Not -Match 'run_build_spec\s*=='
    }

    It 'defines parity mode input contract and self-hosted capacity precheck' {
        $workflowContent | Should -Match '(?ms)^\s*workflow_call:\s*.*?\n\s*parity_mode:\s*'
        $workflowContent | Should -Match '(?ms)^\s*workflow_dispatch:\s*.*?\n\s*parity_mode:\s*'
        $workflowContent | Should -Match 'Supported values:\s*auto,\s*containers-only,\s*full'

        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*$'
        $workflowContent | Should -Match 'listSelfHostedRunnersForRepo'
        $workflowContent | Should -Match 'Self-hosted availability lookup unavailable with workflow token; treating as unknown'
        $workflowContent | Should -Match 'core\.info\(`Self-hosted availability lookup unavailable with workflow token; treating as unknown\.'
        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*.*?outputs:\s*.*?\n\s*self_hosted_available:'
        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*.*?outputs:\s*.*?\n\s*self_hosted_availability_reason:'
        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*.*?outputs:\s*.*?\n\s*self_hosted_online_count:'
        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*.*?outputs:\s*.*?\n\s*self_hosted_total_count:'
        $workflowContent | Should -Match '(?ms)^  self-hosted-capacity:\s*.*?outputs:\s*.*?\n\s*self_hosted_online_runners:'

        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?needs:\s*\[\s*self-hosted-capacity\s*\]'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*parity_mode_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.parity_mode_effective\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*self_hosted_available:\s*\$\{\{\s*steps\.resolve\.outputs\.self_hosted_available\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*self_hosted_online_count:\s*\$\{\{\s*steps\.resolve\.outputs\.self_hosted_online_count\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*self_hosted_total_count:\s*\$\{\{\s*steps\.resolve\.outputs\.self_hosted_total_count\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*self_hosted_online_runners:\s*\$\{\{\s*steps\.resolve\.outputs\.self_hosted_online_runners\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_64_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_64_effective\s*\}\}'
        $workflowContent | Should -Match '(?ms)^  resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_32_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_32_effective\s*\}\}'
    }

    It 'keeps permission-limited runner lookup as informational unknown and preserves warning path for other errors' {
        $capacityMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  self-hosted-capacity:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $capacityMatch.Success | Should -BeTrue
        $capacityBlock = $capacityMatch.Value

        $capacityBlock | Should -Match 'permissionDenied = lowerError\.includes\(''resource not accessible by integration''\)'
        $capacityBlock | Should -Match 'core\.info\(`Self-hosted availability lookup unavailable with workflow token; treating as unknown\.'
        $capacityBlock | Should -Match 'core\.warning\(`Self-hosted availability lookup failed; treating as unknown\.'
        $capacityBlock | Should -Not -Match 'core\.warning\(`Self-hosted availability lookup unavailable with workflow token; treating as unknown\.'
        $capacityBlock | Should -Match 'core\.setOutput\(''self_hosted_available'', ''unknown''\)'
        $capacityBlock | Should -Match 'core\.setOutput\(''self_hosted_availability_reason'', `runner-lookup-error:'
        $capacityBlock | Should -Match 'core\.setOutput\(''self_hosted_online_count'''
        $capacityBlock | Should -Match 'core\.setOutput\(''self_hosted_total_count'''
        $capacityBlock | Should -Match 'core\.setOutput\(''self_hosted_online_runners'''
    }

    It 'derives Linux container parity job name from .lvcontainer contract' {
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lvcontainer_raw:\s*\$\{\{\s*steps\.resolve\.outputs\.lvcontainer_raw\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lv_release_linux:\s*\$\{\{\s*steps\.resolve\.outputs\.lv_release_linux\s*\}\}'
        $workflowContent | Should -Match 'Get-LabVIEWContainerReleaseInfo\s+-RepoRoot\s+\$env:GITHUB_WORKSPACE'
        $parityLinuxMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  parity-linux:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $parityLinuxMatch.Success | Should -BeTrue
        $parityLinuxBlock = $parityLinuxMatch.Value
        $parityLinuxBlock | Should -Match '(?m)^\s*name:\s*Parity \(Linux Container \$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*\}\}\)'
        $parityLinuxBlock | Should -Match 'LV_RELEASE_INPUT="\$\{\{\s*needs\.resolve-parity-context\.outputs\.lv_release_linux\s*\}\}"'
        $parityLinuxBlock | Should -Match '--mode\s+linux-container'
        $parityLinuxBlock | Should -Not -Match 'LV_RELEASE_INPUT="\$\{\{\s*needs\.resolve-parity-context\.outputs\.lv_release_input\s*\}\}"'
    }

    It 'derives Windows container parity job name from .lvcontainer and does not use event-only skip gating' {
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lvcontainer_windows_tag:\s*\$\{\{\s*steps\.resolve\.outputs\.lvcontainer_windows_tag\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lv_release_windows:\s*\$\{\{\s*steps\.resolve\.outputs\.lv_release_windows\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*windows_release_exception_applied:\s*\$\{\{\s*steps\.resolve\.outputs\.windows_release_exception_applied\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*windows_release_exception_note:\s*\$\{\{\s*steps\.resolve\.outputs\.windows_release_exception_note\s*\}\}'
        $workflowContent | Should -Match 'Windows parity fallback applied: requested'
        $parityWindowsMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  parity-windows:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $parityWindowsMatch.Success | Should -BeTrue
        $parityWindowsBlock = $parityWindowsMatch.Value

        $parityWindowsBlock | Should -Match '(?m)^\s*name:\s*Parity \(Windows Container \$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_windows_tag\s*\}\}\)'
        $parityWindowsBlock | Should -Not -Match 'name:\s*Parity \(Windows Container \$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*\}\}\)'
        $parityWindowsBlock | Should -Match '\$lvReleaseInput = ''\$\{\{\s*needs\.resolve-parity-context\.outputs\.lv_release_windows\s*\}\}'''
        $parityWindowsBlock | Should -Match "'--mode',\s*'windows-container'"
        $parityWindowsBlock | Should -Not -Match '\$lvReleaseInput = ''\$\{\{\s*needs\.resolve-parity-context\.outputs\.lv_release_input\s*\}\}'''
        $parityWindowsBlock | Should -Not -Match 'github\.event_name\s*=='
    }

    It 'runs VI Analyzer in parity from the resolved .lvcontainer linux contract' {
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lvcontainer_linux_tag:\s*\$\{\{\s*steps\.resolve\.outputs\.lvcontainer_linux_tag\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lvcontainer_linux_year:\s*\$\{\{\s*steps\.resolve\.outputs\.lvcontainer_linux_year\s*\}\}'

        $viAnalyzerMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  vi-analyzer-linux:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $viAnalyzerMatch.Success | Should -BeTrue
        $viAnalyzerBlock = $viAnalyzerMatch.Value

        $viAnalyzerBlock | Should -Match '(?m)^\s*name:\s*VI Analyzer Linux container \$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*\}\}'
        $viAnalyzerBlock | Should -Match '(?m)^\s*needs:\s*\[\s*resolve-parity-context\s*\]'
        $viAnalyzerBlock | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest'
        $viAnalyzerBlock | Should -Match 'LVIE_CONTAINER_CONTRACT_TAG:\s*\$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*\}\}'
        $viAnalyzerBlock | Should -Match 'LVIE_CONTAINER_CONTRACT_LINUX_IMAGE:\s*nationalinstruments/labview:\$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*\}\}'
        $viAnalyzerBlock | Should -Match 'LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\$\{\{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_year\s*\}\}'
        $viAnalyzerBlock | Should -Match 'run-vi-analyzer-linux\.sh'
    }

    It 'defines mandatory dual-bitness self-hosted lanes with runner-cli one-shot execution and cleanup' {
        $workflowContent | Should -Match '(?ms)^\s*workflow_call:\s*.*?\n\s*run_self_hosted_64:\s*.*?\n\s*default:\s*true'
        $workflowContent | Should -Match '(?ms)^\s*workflow_call:\s*.*?\n\s*run_self_hosted_32:\s*.*?\n\s*default:\s*true'
        $workflowContent | Should -Match '(?ms)^\s*workflow_call:\s*.*?\n\s*lv_release_self_hosted:\s*'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*parity_mode_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.parity_mode_effective\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*lv_release_self_hosted:\s*\$\{\{\s*steps\.resolve\.outputs\.lv_release_self_hosted\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_64:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_64\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_32:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_32\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_64_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_64_effective\s*\}\}'
        $workflowContent | Should -Match '(?ms)^\s*resolve-parity-context:\s*.*?outputs:\s*.*?\n\s*run_self_hosted_32_effective:\s*\$\{\{\s*steps\.resolve\.outputs\.run_self_hosted_32_effective\s*\}\}'
        $workflowContent | Should -Match 'runSelfHostedLegacyRaw'
        $workflowContent | Should -Match 'Resolve-BoolToggle'
        $workflowContent | Should -Match 'parityModeEffective'
        $workflowContent | Should -Match 'lvReleaseSelfHostedInput'

        $policyGateMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  self-hosted-policy-gate:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $policyGateMatch.Success | Should -BeTrue
        $policyGateBlock = $policyGateMatch.Value
        $policyGateBlock | Should -Match '(?m)^\s*needs:\s*\[\s*resolve-parity-context\s*\]'
        $policyGateBlock | Should -Match 'mode -ne ''full'''
        $policyGateBlock | Should -Match 'Full parity mode requires an available self-hosted runner'
        $policyGateBlock | Should -Match 'self_hosted_online_count'
        $policyGateBlock | Should -Match 'self_hosted_online_runners'
        $policyGateBlock | Should -Match 'parallel-capable'
        $policyGateBlock | Should -Match 'queue-expected'

        $runnerCliBuildWinMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  runner-cli-build-win:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $runnerCliBuildWinMatch.Success | Should -BeTrue
        $runnerCliBuildWinBlock = $runnerCliBuildWinMatch.Value
        $runnerCliBuildWinBlock | Should -Match '(?m)^\s*uses:\s*\./\.github/workflows/runner-cli-reusable\.yml'
        $runnerCliBuildWinBlock | Should -Match '(?m)^\s*rid:\s*win-x64'
        $runnerCliBuildWinBlock | Should -Match '(?m)^\s*artifact_name:\s*runner-cli-win-x64'

        $paritySelfHosted64Match = [regex]::Match(
            $workflowContent,
            '(?ms)^  parity-self-hosted-64:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $paritySelfHosted64Match.Success | Should -BeTrue
        $paritySelfHosted64Block = $paritySelfHosted64Match.Value

        $paritySelfHosted64Block | Should -Match '(?m)^\s*name:\s*Parity \(Self-Hosted Windows LabVIEW 64-bit\)'
        $paritySelfHosted64Block | Should -Match 'needs:\s*\[\s*resolve-parity-context,\s*runner-cli-build-win,\s*self-hosted-policy-gate\s*\]'
        $paritySelfHosted64Block | Should -Match 'outputs\.run_self_hosted_64_effective'
        $paritySelfHosted64Block | Should -Match 'needs\.runner-cli-build-win\.outputs\.artifact_name'
        $paritySelfHosted64Block | Should -Match "'parity',\s*'self-hosted'"
        $paritySelfHosted64Block | Should -Match "'--labview-bitness',\s*'64'"
        $paritySelfHosted64Block | Should -Match 'outputs\.lv_release_self_hosted'
        $paritySelfHosted64Block | Should -Match 'dotnet build-server shutdown'
        $paritySelfHosted64Block | Should -Match 'close_bitness:\s*64'
        $paritySelfHosted64Block | Should -Match 'labview-parity-self-hosted-labviewcli-logs-64'
        $paritySelfHosted64Block | Should -Match 'labview-parity-self-hosted-editor-packed-library-64'
        $paritySelfHosted64Block | Should -Not -Match 'dotnet run --project \.\\Tooling\\runner-cli\\RunnerCli\\RunnerCli\.csproj'

        $paritySelfHosted32Match = [regex]::Match(
            $workflowContent,
            '(?ms)^  parity-self-hosted-32:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $paritySelfHosted32Match.Success | Should -BeTrue
        $paritySelfHosted32Block = $paritySelfHosted32Match.Value

        $paritySelfHosted32Block | Should -Match '(?m)^\s*name:\s*Parity \(Self-Hosted Windows LabVIEW 32-bit\)'
        $paritySelfHosted32Block | Should -Match 'needs:\s*\[\s*resolve-parity-context,\s*runner-cli-build-win,\s*self-hosted-policy-gate\s*\]'
        $paritySelfHosted32Block | Should -Match 'outputs\.run_self_hosted_32_effective'
        $paritySelfHosted32Block | Should -Match 'needs\.runner-cli-build-win\.outputs\.artifact_name'
        $paritySelfHosted32Block | Should -Match "'parity',\s*'self-hosted'"
        $paritySelfHosted32Block | Should -Match "'--labview-bitness',\s*'32'"
        $paritySelfHosted32Block | Should -Match 'outputs\.lv_release_self_hosted'
        $paritySelfHosted32Block | Should -Match 'dotnet build-server shutdown'
        $paritySelfHosted32Block | Should -Match 'close_bitness:\s*32'
        $paritySelfHosted32Block | Should -Match 'labview-parity-self-hosted-labviewcli-logs-32'
        $paritySelfHosted32Block | Should -Match 'labview-parity-self-hosted-editor-packed-library-32'
        $paritySelfHosted32Block | Should -Not -Match 'dotnet run --project \.\\Tooling\\runner-cli\\RunnerCli\\RunnerCli\.csproj'
    }

    It 'writes a parity summary job with deterministic mode and lane results' {
        $summaryMatch = [regex]::Match(
            $workflowContent,
            '(?ms)^  parity-summary:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$|\z)'
        )
        $summaryMatch.Success | Should -BeTrue
        $summaryBlock = $summaryMatch.Value

        $summaryBlock | Should -Match '(?m)^\s*if:\s*\$\{\{\s*always\(\)\s*\}\}'
        $summaryBlock | Should -Match '## LabVIEW Parity Summary'
        $summaryBlock | Should -Match 'needs\.resolve-parity-context\.outputs\.parity_mode_effective'
        $summaryBlock | Should -Match 'needs\.resolve-parity-context\.outputs\.self_hosted_online_count'
        $summaryBlock | Should -Match 'needs\.resolve-parity-context\.outputs\.self_hosted_online_runners'
        $summaryBlock | Should -Match 'self_hosted_online_count:'
        $summaryBlock | Should -Match "self-hosted-policy-gate"
        $summaryBlock | Should -Match "vi-analyzer-linux"
    }
}
