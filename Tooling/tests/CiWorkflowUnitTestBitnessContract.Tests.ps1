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
}
