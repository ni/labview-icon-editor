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
        $program | Should -Match 'new Command\("validate", "Validate UnitTestReport\.xml using RunUnitTests\.ps1 parse-only mode\."\)'
    }

    It 'keeps runner-cli dry-run coverage for lunit run and lunit validate' {
        $content = Get-Content -Path $script:runnerCliTestsPath -Raw
        $content | Should -Match 'Lunit_run_dry_run_emits_gcli_and_parser_commands'
        $content | Should -Match 'Lunit_validate_dry_run_emits_parser_command'
    }

    It 'keeps CI unit-test lanes on runner-cli lunit run with explicit project path' {
        $content = Get-Content -Path $script:ciWorkflowPath -Raw
        $projectPathLiteral = '''--project-path'', $env:PROJECT_PATH'
        $content | Should -Match "'lunit', 'run'"
        $content | Should -Match ([regex]::Escape($projectPathLiteral))
        $content | Should -Not -Match 'run-unit-tests/RunUnitTests\.ps1'
    }
}
