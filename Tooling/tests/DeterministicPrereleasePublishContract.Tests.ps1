#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Deterministic prerelease publish helper contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:scriptPath = Join-Path $script:toolingRoot 'Invoke-DeterministicPrereleasePublish.ps1'
        $script:scriptContent = Get-Content -Path $script:scriptPath -Raw
    }

    It 'exists and parses without syntax errors' {
        (Test-Path -LiteralPath $script:scriptPath -PathType Leaf) | Should -BeTrue

        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw ("Invoke-DeterministicPrereleasePublish.ps1 parse failed: {0}" -f $errors[0].Message)
        }
    }

    It 'dispatches CI Pipeline with strict publish intent inputs' {
        $script:scriptContent | Should -Match '''workflow'', ''run'', ''CI Pipeline'''
        $script:scriptContent | Should -Match '''-f'', ''publish_prerelease=true'''
        $script:scriptContent | Should -Match '''-f'', \("expected_sha=\{0\}" -f \$targetSha\)'
        $script:scriptContent | Should -Match '''-f'', ''strict_sha=true'''
    }

    It 'uses temporary ci-run branch refs and cleanup semantics' {
        $script:scriptContent | Should -Match 'ci-run-prerelease-'
        $script:scriptContent | Should -Match '''push'', ''origin'', \$pushRefSpec'
        $script:scriptContent | Should -Match '''push'', ''origin'', ''--delete'', \$BranchName'
        $script:scriptContent | Should -Match '\[switch\]\$KeepDispatchBranch'
    }

    It 'validates merge-commit and merged develop PR association before dispatch' {
        $script:scriptContent | Should -Match '@\(\$commit\.parents\)\.Count'
        $script:scriptContent | Should -Match '\$parentCount -lt 2'
        $script:scriptContent | Should -Match '/commits/\{1\}/pulls'
        $script:scriptContent | Should -Match 'base\.ref'
        $script:scriptContent | Should -Match 'merge_commit_sha'
        $script:scriptContent | Should -Match '''develop'''
    }
}
