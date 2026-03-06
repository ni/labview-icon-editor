#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Pylavi composite contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $actionPath = Join-Path $repoRoot '.github/actions/pylavi-ci/action.yml'
        if (-not (Test-Path -LiteralPath $actionPath -PathType Leaf)) {
            throw "Composite action not found: $actionPath"
        }

        $script:content = Get-Content -LiteralPath $actionPath -Raw
    }

    It 'defines required inputs and outputs for deterministic pylavi contract' {
        foreach ($token in @(
            'validate_args:',
            'label:',
            'report_only:',
            'expected_reason:',
            'expected_vi_path:',
            'fail_if_expected_missing:',
            'absolute_roots:'
        )) {
            $script:content | Should -Match ([regex]::Escape($token))
        }

        foreach ($outputToken in @('status:', 'exit_code:', 'log_path:', 'offenders_path:', 'summary_path:')) {
            $script:content | Should -Match ([regex]::Escape($outputToken))
        }
    }

    It 'installs pylavi directly and runs vi_validate without runner-cli dependency' {
        $script:content | Should -Match 'actions/setup-python@v5'
        $script:content | Should -Match 'python -m pip install pylavi'
        $script:content | Should -Match 'vi_validate @validateArgs'
        $script:content | Should -Match '--gt 19 --lt 21 --no-suspend-on-run --breakpoints --no-code --no-absolute-path'
        $script:content | Should -Not -Match 'LVIE_RUNNER_CLI_PATH'
        $script:content | Should -Not -Match 'runner-cli\.exe'
        $script:content | Should -Not -Match 'Tooling/runner-cli'
    }

    It 'supports report-only and strict failure behavior' {
        $script:content | Should -Match 'report_only'
        $script:content | Should -Match 'expected_failure_observed'
        $script:content | Should -Match 'Expected failure signature was not observed'
        $script:content | Should -Match 'if \(\$status -eq ''warn''\)'
        $script:content | Should -Match 'if \(\$status -eq ''fail''\)'
        $script:content | Should -Match 'first_offender_reason'
        $script:content | Should -Match 'first_offender_vi_path'
        $script:content | Should -Match 'GITHUB_STEP_SUMMARY'
        $script:content | Should -Match '::error'
    }
}
