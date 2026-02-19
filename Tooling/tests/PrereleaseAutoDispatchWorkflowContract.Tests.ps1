#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Prerelease auto dispatch workflow contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github\workflows\prerelease-auto-dispatch.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
    }

    It 'exists and listens to CI Pipeline workflow_run completion events' {
        (Test-Path -LiteralPath $script:workflowPath -PathType Leaf) | Should -BeTrue
        $script:workflowContent | Should -Match '(?ms)on:\s*\r?\n\s*workflow_run:\s*\r?\n\s*workflows:\s*\r?\n\s*-\s*CI Pipeline'
        $script:workflowContent | Should -Match '(?ms)workflow_run:[\s\S]*types:\s*[\s\S]*-\s*completed'
    }

    It 'gates execution to successful develop push source runs' {
        $script:workflowContent | Should -Match "github\.event\.workflow_run\.conclusion == 'success'"
        $script:workflowContent | Should -Match "github\.event\.workflow_run\.event == 'push'"
        $script:workflowContent | Should -Match "github\.event\.workflow_run\.head_branch == 'develop'"
    }

    It 'checks merge-commit and merged-develop association before dispatching' {
        $script:workflowContent | Should -Match 'parentCount < 2'
        $script:workflowContent | Should -Match 'listPullRequestsAssociatedWithCommit'
        $script:workflowContent | Should -Match "baseRef === 'develop'"
        $script:workflowContent | Should -Match 'merge_commit_sha'
        $script:workflowContent | Should -Match "eligible-merged-develop-pr-merge-commit"
    }

    It 'dispatches deterministic helper in release-priority mode for source sha' {
        $script:workflowContent | Should -Match 'Invoke-DeterministicPrereleasePublish\.ps1'
        $script:workflowContent | Should -Match '-ReleasePriority'
        $script:workflowContent | Should -Match '-Sha "\$env:SOURCE_SHA"'
        $script:workflowContent | Should -Match 'GH_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}'
    }
}
