#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI workflow unit-test bitness contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
        $script:unitTestsSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  unit-tests:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
    }

    It 'defines unit-tests matrix for both 64-bit and 32-bit lanes' {
        $script:unitTestsSection | Should -Not -BeNullOrEmpty
        $script:unitTestsSection | Should -Match 'bitness:\s*\$\{\{\s*fromJson\(''\["64","32"\]''\)\s*\}\}'
    }

    It 'keeps unit-tests matrix serialized' {
        $script:unitTestsSection | Should -Match 'max-parallel:\s*1'
    }

    It 'removes LV2020 edge test lane and dead toggle env var' {
        $script:workflowContent | Should -Not -Match '^\s*unit-tests-lv2020-edge:'
        $script:workflowContent | Should -Not -Match 'LVIE_RUN_LV2020_EDGE_SMOKE'
    }
}
