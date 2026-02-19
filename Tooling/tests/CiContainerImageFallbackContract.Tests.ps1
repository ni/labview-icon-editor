#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI container image fallback ownership contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
        $script:linuxContainerSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-linux-container:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
        $script:windowsContainerSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-windows-container:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
        $script:parityServicePath = Join-Path $script:repoRoot 'Tooling/runner-cli/RunnerCli/ParityService.cs'
        $script:parityServiceContent = Get-Content -Path $script:parityServicePath -Raw
    }

    It 'linux container lane delegates image pull/fallback to runner-cli parity run' {
        $script:linuxContainerSection | Should -Not -Match '(?m)^\s*-\s*name:\s*Pull LabVIEW Linux image\s*$'
        $script:linuxContainerSection | Should -Not -Match 'LV_REQUESTED_RELEASE'
        $script:linuxContainerSection | Should -Not -Match 'fallback_release='
        $script:linuxContainerSection | Should -Not -Match 'try_pull_release'
        $script:linuxContainerSection | Should -Match 'parity run --mode linux-container --context \$contextPath --build-spec'
    }

    It 'windows container lane delegates image pull/fallback to runner-cli parity run' {
        $script:windowsContainerSection | Should -Not -Match '(?m)^\s*-\s*name:\s*Pull LabVIEW Windows image\s*$'
        $script:windowsContainerSection | Should -Not -Match 'Try-PullWindowsRelease'
        $script:windowsContainerSection | Should -Not -Match 'LVIE_CONTAINER_PARITY_FALLBACK_RELEASE'
        $script:windowsContainerSection | Should -Match 'parity run --mode windows-container --context \$contextPath --build-spec'
    }

    It 'runner-cli parity service owns deterministic container fallback policy' {
        $script:parityServiceContent | Should -Match 'DefaultContainerFallbackRelease = "2026q1"'
        $script:parityServiceContent | Should -Match 'Environment\.GetEnvironmentVariable\("LVIE_CONTAINER_PARITY_FALLBACK_RELEASE"\)'
        $script:parityServiceContent | Should -Match "WARNING: Requested container release '\{requestedRelease\}' is unavailable\. Falling back to '\{candidate\}'\."
        $script:parityServiceContent | Should -Match "Unable to pull LabVIEW container image for '\{requestedRelease\}'\. Tried:"
    }
}
