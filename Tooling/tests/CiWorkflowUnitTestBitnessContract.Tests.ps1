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

    It 'uploads per-lane source-test evidence artifacts' {
        $script:unitTestsSection | Should -Match 'Upload source-test evidence \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'source-test-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}-bit'
        $script:unitTestsSection | Should -Match 'source-test-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.json'
    }

    It 'defaults source-test mode to canary via LVIE_SOURCE_TEST_STRICT' {
        $script:unitTestsSection | Should -Match 'LVIE_SOURCE_TEST_STRICT:\s*\$\{\{\s*vars\.LVIE_SOURCE_TEST_STRICT \|\| ''0''\s*\}\}'
        $script:unitTestsSection | Should -Match 'Source-test canary mode active; keeping lane green'
    }

    It 'does not include LV2020 empty-report bypass in unit-tests lane' {
        $script:unitTestsSection | Should -Not -Match 'Treating lane as skipped'
        $script:unitTestsSection | Should -Not -Match "\$unitTestYear -eq '2020'"
    }

    It 'removes LV2020 edge test lane and dead toggle env var' {
        $script:workflowContent | Should -Not -Match '^\s*unit-tests-lv2020-edge:'
        $script:workflowContent | Should -Not -Match 'LVIE_RUN_LV2020_EDGE_SMOKE'
    }
}
