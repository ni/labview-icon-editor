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

    It 'defines unit-tests matrix for both 64-bit and 32-bit lanes with bitness runner routing' {
        $script:unitTestsSection | Should -Not -BeNullOrEmpty
        $script:unitTestsSection | Should -Match 'matrix:\s*\r?\n\s*include:'
        $script:unitTestsSection | Should -Match "bitness:\s*'64'"
        $script:unitTestsSection | Should -Match "bitness:\s*'32'"
        $script:unitTestsSection | Should -Match 'runner_label:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_64 \|\| vars\.LVIE_RUNNER_LABEL \|\| ''self-hosted-windows-lv''\s*\}\}'
        $script:unitTestsSection | Should -Match 'runner_label:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_32 \|\| vars\.LVIE_RUNNER_LABEL \|\| ''self-hosted-windows-lv''\s*\}\}'
        $script:unitTestsSection | Should -Match 'runs-on:\s*\$\{\{\s*matrix\.runner_label\s*\}\}'
    }

    It 'allows unit-tests matrix to use two self-hosted runners in parallel' {
        $script:unitTestsSection | Should -Match 'max-parallel:\s*2'
    }

    It 'uploads per-lane source-test evidence artifacts' {
        $script:unitTestsSection | Should -Match 'Assert VIPC dependencies on source-test runner \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'vipc-audit-pretest-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.json'
        $script:unitTestsSection | Should -Match 'Upload VIPC pretest audit \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'id:\s*source_test'
        $script:unitTestsSection | Should -Match 'source_test_verdict='
        $script:unitTestsSection | Should -Match 'report_fallback_used='
        $script:unitTestsSection | Should -Match 'Upload unit test report \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'UnitTestReport-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.xml'
        $script:unitTestsSection | Should -Match "if:\s*\$\{\{\s*failure\(\)\s*\|\|\s*steps\.source_test\.outputs\.source_test_verdict\s*==\s*'fail'\s*\}\}"
        $script:unitTestsSection | Should -Match 'Upload source-test evidence \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'source-test-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}-bit'
        $script:unitTestsSection | Should -Match 'source-test-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.json'
        $script:unitTestsSection | Should -Match 'Upload LabVIEW temp logs \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'labview-temp-logs-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}-bit'
        $script:unitTestsSection | Should -Match 'Upload unit test report legacy alias \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $script:unitTestsSection | Should -Match 'UnitTestReport\.xml'
    }

    It 'defaults source-test mode to canary via LVIE_SOURCE_TEST_STRICT' {
        $script:unitTestsSection | Should -Match 'LVIE_SOURCE_TEST_STRICT:\s*\$\{\{\s*vars\.LVIE_SOURCE_TEST_STRICT \|\| ''0''\s*\}\}'
        $script:unitTestsSection | Should -Match 'LVIE_LUNIT_VERBOSE_GCLI:\s*\$\{\{\s*vars\.LVIE_LUNIT_VERBOSE_GCLI \|\| ''1''\s*\}\}'
        $script:unitTestsSection | Should -Match 'LVIE_SOURCE_TEST_MODE_INPUT:\s*\$\{\{\s*github\.event_name == ''workflow_dispatch'' && github\.event\.inputs\.source_test_mode \|\| ''inherit''\s*\}\}'
        $script:unitTestsSection | Should -Match 'LVIE_SOURCE_TEST_LABVIEW_YEAR_OVERRIDE:\s*\$\{\{\s*github\.event_name == ''workflow_dispatch'' && github\.event\.inputs\.source_test_labview_year_override \|\| ''''\s*\}\}'
        $script:workflowContent | Should -Match 'source_test_mode:'
        $script:workflowContent | Should -Match 'source_test_labview_year_override:'
        $script:unitTestsSection | Should -Match 'Source-test canary mode active; keeping lane green'
    }

    It 'adds unit-test summary metadata for runner, mode, and mapping' {
        $script:unitTestsSection | Should -Match "runner=\{1\}; mode=\{2\}; LUnit executor=runner-cli \(g-cli backend\); target_year=\{3\}; source_year=\{4\}; lv2020_compat_mapping=\{5\}"
        $script:unitTestsSection | Should -Match '\$\{\{\s*runner\.name\s*\}\}'
        $script:unitTestsSection | Should -Match '\$\{\{\s*steps\.source_test\.outputs\.source_test_mode_effective\s*\}\}'
        $script:unitTestsSection | Should -Match '\$\{\{\s*steps\.source_test\.outputs\.source_test_year_compat_mapping_applied\s*\}\}'
    }

    It 'implements dispatch-only source-test override guards and precedence' {
        $script:unitTestsSection | Should -Match '\$sourceTestModeInputRaw = if \(\[string\]::IsNullOrWhiteSpace\(\$env:LVIE_SOURCE_TEST_MODE_INPUT\)\) \{ ''inherit'' \}'
        $script:unitTestsSection | Should -Match '\$strictModeRawFromVariable = if \(\[string\]::IsNullOrWhiteSpace\(\$env:LVIE_SOURCE_TEST_STRICT\)\) \{ ''0'' \}'
        $script:unitTestsSection | Should -Match '\[string\]::Equals\(\$unitTestYearFromLvversion, ''2020'''
        $script:unitTestsSection | Should -Match '\$unitTestYear = ''2026'''
        $script:unitTestsSection | Should -Match '\$unitTestYearSource = ''lv2020_compat_mapping'''
        $script:unitTestsSection | Should -Match 'workflow_dispatch input source_test_mode=strict'
        $script:unitTestsSection | Should -Match 'workflow_dispatch input source_test_mode=canary'
        $script:unitTestsSection | Should -Match 'source_test_mode override is workflow_dispatch only'
        $script:unitTestsSection | Should -Match 'source_test_labview_year_override is workflow_dispatch only'
        $script:unitTestsSection | Should -Match 'source_test_mode_effective='
        $script:unitTestsSection | Should -Match 'source_test_year_source_contract='
        $script:unitTestsSection | Should -Match 'source_test_year_override_applied='
        $script:unitTestsSection | Should -Match 'source_test_year_compat_mapping_applied='
        $script:unitTestsSection | Should -Match 'year_compat_mapping_applied\s*='
    }

    It 'does not include LV2020 empty-report bypass in unit-tests lane' {
        $script:unitTestsSection | Should -Not -Match 'Treating lane as skipped'
        $script:unitTestsSection | Should -Not -Match 'empty report override'
    }

    It 'removes LV2020 edge test lane and dead toggle env var' {
        $script:workflowContent | Should -Not -Match '^\s*unit-tests-lv2020-edge:'
        $script:workflowContent | Should -Not -Match 'LVIE_RUN_LV2020_EDGE_SMOKE'
    }

    It 'requires split apply-deps lanes for unit-tests and pipeline gating' {
        $script:workflowContent | Should -Match '(?ms)^  apply-deps-64:\s*$'
        $script:workflowContent | Should -Match '(?ms)^  apply-deps-32:\s*$'
        $script:workflowContent | Should -Match '(?ms)^  verify-iepaths:\s*$'
        $script:unitTestsSection | Should -Match 'needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*apply-deps-64,\s*apply-deps-32,\s*verify-iepaths\s*\]'
        $script:workflowContent | Should -Match '(?ms)^  publish-gate:\s*.*?\n\s*-\s*docs-lint\s*$'
        $script:workflowContent | Should -Match '(?ms)^  publish-gate:\s*.*?\n\s*-\s*apply-deps-64\s*$'
        $script:workflowContent | Should -Match '(?ms)^  publish-gate:\s*.*?\n\s*-\s*apply-deps-32\s*$'
        $script:workflowContent | Should -Match '(?ms)^  publish-gate:\s*.*?\n\s*-\s*verify-iepaths\s*$'
        $script:workflowContent | Should -Match '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*docs-lint\s*$'
        $script:workflowContent | Should -Match '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*apply-deps-64\s*$'
        $script:workflowContent | Should -Match '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*apply-deps-32\s*$'
        $script:workflowContent | Should -Match '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*verify-iepaths\s*$'
        $script:workflowContent | Should -Match "'docs-lint'"
        $script:workflowContent | Should -Match "'apply-deps-64'"
        $script:workflowContent | Should -Match "'apply-deps-32'"
        $script:workflowContent | Should -Match "'verify-iepaths'"
    }

    It 'emits a stable canonical required check context job' {
        $script:workflowContent | Should -Match '(?ms)^  required-context:\s*$'
        $script:workflowContent | Should -Match '(?ms)^  required-context:\s*.*?\n\s*name:\s*CI Required / Lint\+Contract'
        $script:workflowContent | Should -Match '(?ms)^  required-context:\s*.*?\n\s*-\s*docs-lint\s*$'
        $script:workflowContent | Should -Match '(?ms)^  required-context:\s*.*?\n\s*-\s*powershell-lint\s*$'
        $script:workflowContent | Should -Match '(?ms)^  required-context:\s*.*?\n\s*-\s*pipeline-contract\s*$'
    }
}
