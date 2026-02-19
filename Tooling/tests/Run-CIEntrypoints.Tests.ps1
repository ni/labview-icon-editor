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
        $content | Should -Match 'LVIE_RUN_MARKDOWNLINT'
        $content | Should -Match 'LVIE_MARKDOWNLINT_CONFIG_PATH'
        $content | Should -Match 'Invoke-MarkdownLint\.ps1'
        $content | Should -Match 'LVIE_RUN_PSSCRIPTANALYZER'
        $content | Should -Match 'Invoke-PSScriptAnalyzer\.ps1'
        $content | Should -Match 'LVIE_RUN_PYLAVI'
        $content | Should -Match 'Run-ViValidate\.ps1'
        $content | Should -Match 'LVIE_RUN_VI_ANALYZER'
        $content | Should -Not -Match 'Linux VI Analyzer gate'
        $content | Should -Match 'LabVIEWCLI was not found on PATH; VI Analyzer gate cannot run'
        $content | Should -Not -Match 'docker (was )?not found on PATH; Linux VI Analyzer gate cannot run'
        $content | Should -Match 'Run-ViAnalyzer\.ps1'
    }

    It 'Run-CI.ps1 exposes markdownlint control switches' {
        $content = Get-Content -Path $script:runCiPs1 -Raw
        $content | Should -Match '\.PARAMETER SkipMarkdownLint'
        $content | Should -Match '\.PARAMETER MarkdownLintConfigPath'
        $content | Should -Match '\.PARAMETER MarkdownLintOnly'
        $content | Should -Match '\[switch\]\$SkipMarkdownLint'
        $content | Should -Match '\[string\]\$MarkdownLintConfigPath'
        $content | Should -Match '\[switch\]\$MarkdownLintOnly'
        $content | Should -Match 'Invoke-MarkdownLint\.ps1'
    }

    It 'local entrypoint guidance no longer depends on C:\\dev defaults' {
        $agentsPath = Join-Path (Split-Path -Parent $script:toolingRoot) 'AGENTS.md'
        $dependencyDocPath = Join-Path (Split-Path -Parent $script:toolingRoot) 'docs\powershell-dependency-scripts.md'
        $worktreeScriptPath = Join-Path $script:toolingRoot 'New-CIWorktree.ps1'

        (Get-Content -Path $agentsPath -Raw) | Should -Not -Match 'Default to `C:\\dev`'
        (Get-Content -Path $dependencyDocPath -Raw) | Should -Not -Match 'local fallback \(`C:\\dev`\)'
        (Get-Content -Path $worktreeScriptPath -Raw) | Should -Not -Match 'defaults to C:\\dev'
    }

    It 'Close_LabVIEW uses LabVIEWCLI close semantics and avoids g-cli quit' {
        $closeScriptPath = Join-Path (Split-Path -Parent $script:toolingRoot) '.github\actions\close-labview\Close_LabVIEW.ps1'
        $content = Get-Content -Path $closeScriptPath -Raw
        $content | Should -Match 'CloseLabVIEW'
        $content | Should -Match 'LabVIEWCLI'
        $content | Should -Not -Match 'QuitLabVIEW'
        $content | Should -Not -Match 'g-cli'
    }
}
