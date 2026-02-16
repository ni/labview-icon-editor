#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Run-CI parity entrypoint contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:runCiPs1 = Join-Path $script:toolingRoot 'Run-CI.ps1'
        $script:runCiSh = Join-Path $script:toolingRoot 'Run-CI.sh'
    }

    It 'keeps only canonical parity entrypoint scripts' {
        $expected = @('Run-CI.ps1', 'Run-CI.sh')
        $actual = @(Get-ChildItem -Path $script:toolingRoot -File -Filter 'Run-CI*' | Select-Object -ExpandProperty Name | Sort-Object)
        $actual | Should -Be $expected
    }

    It 'Run-CI.ps1 exists and parses without syntax errors' {
        (Test-Path -LiteralPath $script:runCiPs1 -PathType Leaf) | Should -BeTrue

        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:runCiPs1, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw ("Run-CI.ps1 parse failed: {0}" -f $errors[0].Message)
        }
    }

    It 'Run-CI.sh enforces mandatory build-spec and required local gates' {
        (Test-Path -LiteralPath $script:runCiSh -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:runCiSh -Raw
        $content | Should -Match '--build-spec'
        $content | Should -Match '--build-spec true'
        $content | Should -Not -Match 'run_args\+=\(false\)'
        $content | Should -Match 'LVIE_PARITY_BUILD_SPEC disable is unsupported'
        $content | Should -Match 'LVIE_RUN_PSSCRIPTANALYZER'
        $content | Should -Match 'Invoke-PSScriptAnalyzer\.ps1'
        $content | Should -Match 'LVIE_RUN_PYLAVI'
        $content | Should -Match 'Run-ViValidate\.ps1'
        $content | Should -Match 'LVIE_RUN_VI_ANALYZER'
        $content | Should -Match 'Run-ViAnalyzer\.ps1'
    }
}
