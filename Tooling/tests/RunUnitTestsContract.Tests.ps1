#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'RunUnitTests execution contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:repoRoot = Split-Path -Parent $script:toolingRoot
        $script:runUnitTestsPath = Join-Path $script:repoRoot '.github\actions\run-unit-tests\RunUnitTests.ps1'
        $script:ciWorkflowPath = Join-Path $script:repoRoot '.github\workflows\ci.yml'
        $script:programPath = Join-Path $script:repoRoot 'Tooling\runner-cli\RunnerCli\Program.cs'
        $script:lunitServicePath = Join-Path $script:repoRoot 'Tooling\runner-cli\RunnerCli\LunitService.cs'
        $script:runnerCliTestsPath = Join-Path $script:repoRoot 'Tooling\runner-cli\RunnerCli.Tests\RunnerCliCliTests.cs'
    }

    It 'replaces ReportOnly parameter set with Parse' {
        $content = Get-Content -Path $script:runUnitTestsPath -Raw
        $content | Should -Match "ParameterSetName = 'Parse'"
        $content | Should -Not -Match "ParameterSetName = 'ReportOnly'"
    }

    It 'hard-fails run mode when ProjectPath is missing or invalid' {
        $content = Get-Content -Path $script:runUnitTestsPath -Raw
        $content | Should -Match 'ProjectPath is required in run mode\.'
        $content | Should -Match 'Provided ProjectPath does not exist:'
    }

    It 'restricts SkipRun behavior to parse mode only' {
        $content = Get-Content -Path $script:runUnitTestsPath -Raw
        $content | Should -Match '\$Script:SkipRun = \(\$PSCmdlet\.ParameterSetName -eq ''Parse''\)'
        $content | Should -Not -Match 'report-only mode'
    }

    It 'keeps parser-only validation path through runner-cli lunit validate' {
        $lunitService = Get-Content -Path $script:lunitServicePath -Raw
        $program = Get-Content -Path $script:programPath -Raw

        $lunitService | Should -Match '"-SkipGcli"'
        $lunitService | Should -Match 'lunit validate fallback report path'
        $program | Should -Match 'new Command\("validate", "Validate UnitTestReport-<os>-<bitness>\.xml using RunUnitTests\.ps1 parse-only mode\."\)'
    }

    It 'keeps runner-cli dry-run coverage for lunit run and lunit validate' {
        $content = Get-Content -Path $script:runnerCliTestsPath -Raw
        $content | Should -Match 'Lunit_run_dry_run_emits_gcli_and_parser_commands'
        $content | Should -Match 'Lunit_run_dry_run_includes_verbose_flag_when_requested'
        $content | Should -Match 'Lunit_validate_dry_run_emits_parser_command'
    }

    It 'keeps CI unit-test lanes on runner-cli lunit run with explicit project path' {
        $content = Get-Content -Path $script:ciWorkflowPath -Raw
        $projectPathLiteral = '''--project-path'', $env:PROJECT_PATH'
        $content | Should -Match "'lunit', 'run'"
        $content | Should -Match ([regex]::Escape($projectPathLiteral))
        $content | Should -Not -Match 'run-unit-tests/RunUnitTests\.ps1'
    }

    It 'captures and uploads source-test evidence per bitness lane' {
        $content = Get-Content -Path $script:ciWorkflowPath -Raw
        $unitTestsMatch = [regex]::Match(
            $content,
            '(?ms)^  unit-tests:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        )
        $unitTestsMatch.Success | Should -BeTrue
        $unitTestsSection = $unitTestsMatch.Groups['body'].Value

        $unitTestsSection | Should -Match ([regex]::Escape("g-cli lunit exit code:\s*(-?\d+)"))
        $unitTestsSection | Should -Match ([regex]::Escape("RunUnitTests parser exit code:\s*(-?\d+)"))
        $unitTestsSection | Should -Match 'failure_classifications\s*='
        $unitTestsSection | Should -Match 'gcli_nonzero_empty_report'
        $unitTestsSection | Should -Match 'legacy_report_path\s*='
        $unitTestsSection | Should -Match 'legacy_report_written\s*='
        $unitTestsSection | Should -Match 'report_path_canonical\s*='
        $unitTestsSection | Should -Match 'report_path_used\s*='
        $unitTestsSection | Should -Match 'report_fallback_used\s*='
        $unitTestsSection | Should -Match 'report_parse_source\s*='
        $unitTestsSection | Should -Match 'Legacy UnitTestReport compatibility copy written'
        $unitTestsSection | Should -Match 'Legacy UnitTestReport compatibility copy already present'
        $unitTestsSection | Should -Match 'UnitTestReport-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.xml'
        $unitTestsSection | Should -Match 'source-test-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}\.json'
        $unitTestsSection | Should -Match 'Upload source-test evidence \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $unitTestsSection | Should -Match 'Upload LabVIEW temp logs \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $unitTestsSection | Should -Match 'Upload unit test report legacy alias \(LV \$\{\{ matrix\.bitness \}\}-bit\)'
        $unitTestsSection | Should -Match 'UnitTestReport\.xml'
        $unitTestsSection | Should -Match "if:\s*\$\{\{\s*failure\(\)\s*\|\|\s*steps\.source_test\.outputs\.source_test_verdict\s*==\s*'fail'\s*\}\}"
    }

    It 'records strict report/testcase failure reasons with canary-mode pass-through support' {
        $content = Get-Content -Path $script:ciWorkflowPath -Raw
        $unitTestsMatch = [regex]::Match(
            $content,
            '(?ms)^  unit-tests:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        )
        $unitTestsMatch.Success | Should -BeTrue
        $unitTestsSection = $unitTestsMatch.Groups['body'].Value

        $unitTestsSection | Should -Match 'Unit test report missing at'
        $unitTestsSection | Should -Match 'Unit test report has no <testcase> entries'
        $unitTestsSection | Should -Match 'LVIE_SOURCE_TEST_STRICT:\s*\$\{\{\s*vars\.LVIE_SOURCE_TEST_STRICT \|\| ''0''\s*\}\}'
        $unitTestsSection | Should -Match 'LVIE_LUNIT_VERBOSE_GCLI:\s*\$\{\{\s*vars\.LVIE_LUNIT_VERBOSE_GCLI \|\| ''1''\s*\}\}'
        $unitTestsSection | Should -Match 'Invoke-DotnetBuildServerShutdown -Phase ''pre-lunit'''
        $unitTestsSection | Should -Match 'Invoke-DotnetBuildServerShutdown -Phase ''post-lunit'''
        $unitTestsSection | Should -Match 'Close_LabVIEW\.ps1'
        $unitTestsSection | Should -Match '--verbose-gcli'
        $unitTestsSection | Should -Match 'Unit test report parse source resolved by workflow'
        $unitTestsSection | Should -Match 'Unit test report path resolved by workflow'
        $unitTestsSection | Should -Match 'id:\s*source_test'
        $unitTestsSection | Should -Match 'source_test_verdict='
        $unitTestsSection | Should -Match 'report_fallback_used='
        $unitTestsSection | Should -Match 'Source-test canary mode active; keeping lane green'
        $unitTestsSection | Should -Not -Match 'Treating lane as skipped'
        $unitTestsSection | Should -Not -Match "\$unitTestYear -eq '2020'"
    }

    It 'keeps canonical-first parse policy with legacy fallback and strict-only error annotations' {
        $content = Get-Content -Path $script:runUnitTestsPath -Raw
        $content | Should -Match 'Resolve-ReportOsSegment'
        $content | Should -Match 'UnitTestReport-\{0\}-\{1\}\.xml'
        $content | Should -Match 'Canonical unit test report missing at'
        $content | Should -Match 'Canonical unit test report unreadable at'
        $content | Should -Match 'Unit test report parse source:'
        $content | Should -Match 'Unit test report parse path:'
        $content | Should -Match 'No <testcase> entries found in report'
        $content | Should -Match '\$env:GITHUB_ACTIONS -eq "true" -and \$Script:SourceTestStrictMode'
    }
}
