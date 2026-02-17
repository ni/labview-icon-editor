#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'VI Analyzer contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:tasksPath = Join-Path $script:repoRoot 'Tooling\vi-analyzer\tasks.json'
        $script:ciPath = Join-Path $script:repoRoot '.github\workflows\ci.yml'
        $script:runViAnalyzerPath = Join-Path $script:repoRoot 'Tooling\Run-ViAnalyzer.ps1'
    }

    It 'defines exactly three deterministic VI Analyzer tasks' {
        (Test-Path -LiteralPath $script:tasksPath -PathType Leaf) | Should -BeTrue

        $tasksDoc = Get-Content -Raw -Path $script:tasksPath | ConvertFrom-Json
        ($tasksDoc.PSObject.Properties.Name -contains 'tasks') | Should -BeTrue

        $tasks = @($tasksDoc.tasks)
        $tasks.Count | Should -Be 3
        @($tasks.id) | Should -Be @('labview-icon-api', 'plugins', 'tooling')
    }

    It 'resolves all VI Analyzer task config files from the task registry' {
        $tasks = @((Get-Content -Raw -Path $script:tasksPath | ConvertFrom-Json).tasks)
        foreach ($task in $tasks) {
            [string]::IsNullOrWhiteSpace([string]$task.config_path) | Should -BeFalse
            $configPath = if ([System.IO.Path]::IsPathRooted([string]$task.config_path)) {
                [string]$task.config_path
            } else {
                Join-Path $script:repoRoot ([string]$task.config_path)
            }

            (Test-Path -LiteralPath $configPath -PathType Leaf) | Should -BeTrue
        }
    }

    It 'wires vi-analyzer into CI and publish/pipeline required job sets' {
        (Test-Path -LiteralPath $script:ciPath -PathType Leaf) | Should -BeTrue

        $content = Get-Content -Raw -Path $script:ciPath
        $content | Should -Match '(?ms)^\s*vi-analyzer:\s*$'
        $content | Should -Match '(?ms)^\s*vi-analyzer:\s*.*?needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate\s*\]'
        $content | Should -Match '(?ms)^\s*vi-analyzer:\s*.*?runs-on:\s*ubuntu-latest'
        $content | Should -Match '(?ms)^\s*vi-analyzer:\s*.*?Run VI Analyzer tasks \(Linux container\)'
        $content | Should -Match '(?ms)^\s*vi-analyzer:\s*.*?run-vi-analyzer-linux\.sh'
        $content | Should -Match '(?ms)publish-gate:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $content | Should -Match '(?ms)pipeline-contract:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $content | Should -Match '(?ms)\$requiredCommon\s*=\s*@\(\s*.*?''vi-analyzer'''
    }

    It 'enforces non-zero analyzed tests and file-level failure extraction in Run-ViAnalyzer' {
        (Test-Path -LiteralPath $script:runViAnalyzerPath -PathType Leaf) | Should -BeTrue

        $content = Get-Content -Raw -Path $script:runViAnalyzerPath
        $content | Should -Match 'Resolve-LabVIEWCliPortFromContract'
        $content | Should -Match 'RunVIAnalyzer'
        $content | Should -Match 'analyzed_total'
        $content | Should -Match 'No tests were analyzed'
        $content | Should -Match 'Failed Tests'
        $content | Should -Match 'Testing Errors'
        $content | Should -Match 'failure_items'
        $content | Should -Match 'failure_file_paths'
    }
}
