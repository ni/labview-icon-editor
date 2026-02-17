#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Workflow trigger policy contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:ciWorkflowPath = Join-Path $script:repoRoot '.github\workflows\ci.yml'
        $script:runnerCliWorkflowPath = Join-Path $script:repoRoot '.github\workflows\runner-cli.yml'
    }

    It 'keeps CI push triggers on long-lived branches and removes PR-branch push patterns' {
        (Test-Path -LiteralPath $script:ciWorkflowPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:ciWorkflowPath -Raw

        $pushBlock = [regex]::Match($content, '(?ms)^\s*push:\s*\r?\n(?<body>.*?)(?=^\s*pull_request:\s*)')
        $pushBlock.Success | Should -BeTrue
        $pushContent = $pushBlock.Groups['body'].Value

        $pushContent | Should -Match '(?m)^\s*-\s*main\s*$'
        $pushContent | Should -Match '(?m)^\s*-\s*develop\s*$'
        $pushContent | Should -Match '(?m)^\s*-\s*release/\*\s*$'
        $pushContent | Should -Not -Match '(?m)^\s*-\s*feature/\*\s*$'
        $pushContent | Should -Not -Match '(?m)^\s*-\s*hotfix/\*\s*$'

        $content | Should -Match '(?ms)^\s*pull_request:\s*$'
    }

    It 'keeps Runner CLI push triggers on long-lived branches and removes PR-branch push patterns' {
        (Test-Path -LiteralPath $script:runnerCliWorkflowPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:runnerCliWorkflowPath -Raw

        $pushBlock = [regex]::Match($content, '(?ms)^\s*push:\s*\r?\n(?<body>.*?)(?=^\s*pull_request:\s*)')
        $pushBlock.Success | Should -BeTrue
        $pushContent = $pushBlock.Groups['body'].Value

        $pushContent | Should -Match '(?m)^\s*-\s*main\s*$'
        $pushContent | Should -Match '(?m)^\s*-\s*develop\s*$'
        $pushContent | Should -Match '(?m)^\s*-\s*release/\*\s*$'
        $pushContent | Should -Not -Match '(?m)^\s*-\s*feature/\*\s*$'
        $pushContent | Should -Not -Match '(?m)^\s*-\s*hotfix/\*\s*$'
        $pushContent | Should -Not -Match '(?m)^\s*-\s*integrate/\*\s*$'

        $content | Should -Match '(?ms)^\s*pull_request:\s*$'
    }
}
