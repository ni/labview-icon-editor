#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Run-ViAnalyzer report parsing contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:scriptPath = Join-Path $script:repoRoot 'Tooling\Run-ViAnalyzer.ps1'
        $script:fixturePath = Join-Path $script:repoRoot 'Tooling\tests\fixtures\vi-analyzer\report-with-failures.txt'

        function script:Get-FunctionDefinitionText {
            param(
                [System.Management.Automation.Language.ScriptBlockAst]$Ast,
                [string]$FunctionName
            )

            $fn = @($Ast.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $FunctionName
                    }, $true))

            if ($fn.Count -ne 1) {
                throw ("Function definition '{0}' not found exactly once in {1}" -f $FunctionName, $script:scriptPath)
            }

            return $fn[0].Extent.Text
        }

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors -and $parseErrors.Count -gt 0) {
            throw ("Failed to parse {0}: {1}" -f $script:scriptPath, $parseErrors[0].Message)
        }

        $harnessPath = Join-Path $TestDrive 'Run-ViAnalyzer.ReportParsing.Functions.ps1'
        Set-Content -Path $harnessPath -Value @(
                (Get-FunctionDefinitionText -Ast $ast -FunctionName 'Get-ViAnalyzerFailureItemList')
                ''
                (Get-FunctionDefinitionText -Ast $ast -FunctionName 'Get-OrderedUniqueFilePathList')
            ) -Encoding utf8

        . $harnessPath
    }

    It 'extracts file-level failure items from failed-tests and testing-errors sections in order' {
        (Test-Path -LiteralPath $script:fixturePath -PathType Leaf) | Should -BeTrue
        $reportText = Get-Content -Path $script:fixturePath -Raw

        $items = @(Get-ViAnalyzerFailureItemList -ReportText $reportText)
        $items.Count | Should -Be 3

        @($items.section) | Should -Be @('failed_tests', 'failed_tests', 'testing_errors')
        @($items.vi_display_name) | Should -Be @(
            'Set Run Icon Editor from Source.vi',
            'Unset Run Icon Editor from Source.vi',
            'Mass Compile Runner.vi'
        )
        @($items.file_path) | Should -Be @(
            'C:\actions-runner\_work\Tooling\Set Run Icon Editor from Source.vi',
            'C:\actions-runner\_work\Tooling\Unset Run Icon Editor from Source.vi',
            'C:\actions-runner\_work\Tooling\Mass Compile Runner.vi'
        )
        @($items.check_name) | Should -Be @('Broken VI', 'Broken VI', 'Test error out')
        @($items.message) | Should -Be @(
            'This VI is broken.',
            'This VI is broken.',
            'Unable to load dependency.'
        )
    }

    It 'extracts ordered unique failure file paths' {
        $reportText = Get-Content -Path $script:fixturePath -Raw
        $items = @(Get-ViAnalyzerFailureItemList -ReportText $reportText)
        $paths = @(Get-OrderedUniqueFilePathList -Items $items)

        $paths | Should -Be @(
            'C:\actions-runner\_work\Tooling\Set Run Icon Editor from Source.vi',
            'C:\actions-runner\_work\Tooling\Unset Run Icon Editor from Source.vi',
            'C:\actions-runner\_work\Tooling\Mass Compile Runner.vi'
        )
    }
}
