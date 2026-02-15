#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:GuardScript = Join-Path $Script:ToolingRoot 'Test-SoloMaintainerWorkflowContract.ps1'
}

Describe 'Test-SoloMaintainerWorkflowContract.ps1' {
    BeforeEach {
        $Script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-solo-contract-{0}" -f [guid]::NewGuid().ToString('N'))

        $workflowDir = Join-Path $Script:TempDir '.github\workflows'
        $toolingTestsDir = Join-Path $Script:TempDir 'Tooling\tests'
        New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
        New-Item -Path $toolingTestsDir -ItemType Directory -Force | Out-Null

        $workflowContents = @{
            'ci.yml' = @(
                'name: CI'
                'on:'
                '  pull_request:'
                'jobs:'
                '  pipeline-contract:'
                '    runs-on: ubuntu-latest'
                '    steps: []'
            ) -join [Environment]::NewLine
            'ci-composite.yml' = @(
                'name: CI Composite'
                'on:'
                '  push:'
                '  workflow_dispatch:'
                'jobs:'
                '  pipeline-contract:'
                '    runs-on: ubuntu-latest'
                '    steps: []'
                '  prerelease-context:'
                '    runs-on: ubuntu-latest'
                '    steps:'
                '      - run: |'
                '          publishMode = ''manual-intent'''
                '          publishReason = ''manual-intent-required-develop-push-merged-pr-detected'''
            ) -join [Environment]::NewLine
            'labview-parity.yml' = @(
                'name: LabVIEW Parity'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'development-mode-toggle.yml' = @(
                'name: Toggle Development Mode'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'runner-cli.yml' = @(
                'name: Runner CLI'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'runner-audit.yml' = @(
                'name: Runner Audit'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'stale-issues.yml' = @(
                'name: Stale Issues'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'labels-sync.yml' = @(
                'name: Label Sync'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'label-metadata-gate.yml' = @(
                'name: Label Metadata Gate'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'label-metadata-audit.yml' = @(
                'name: Label Metadata Audit'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'label-metadata-normalize.yml' = @(
                'name: Label Metadata Normalize'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'repo-agnostic-issue-routing.yml' = @(
                'name: Repo-Agnostic Issue Routing'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'ci-debt-train.yml' = @(
                'name: CI Debt Train'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'ci-debt-policy-gate.yml' = @(
                'name: CI Debt Policy Gate'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
        }

        foreach ($entry in $workflowContents.GetEnumerator()) {
            $fullPath = Join-Path $workflowDir $entry.Key
            Set-Content -LiteralPath $fullPath -Value $entry.Value -Encoding utf8
        }
    }

    AfterEach {
        if (Test-Path -LiteralPath $Script:TempDir -PathType Container) {
            Remove-Item -LiteralPath $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'passes when solo-maintainer contract is satisfied' {
        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Not -Throw
    }

    It 'fails when a core workflow file is missing' {
        Remove-Item -LiteralPath (Join-Path $Script:TempDir '.github\workflows\runner-audit.yml') -Force
        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*missing-core-workflow*'
    }

    It 'fails when pipeline-contract job is missing' {
        Set-Content -LiteralPath (Join-Path $Script:TempDir '.github\workflows\ci.yml') -Value @(
            'name: CI'
            'on:'
            '  pull_request:'
            'jobs:'
            '  lint:'
            '    runs-on: ubuntu-latest'
            '    steps: []'
        ) -Encoding utf8

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*missing-pipeline-contract-job*'
    }

    It 'fails when development-mode-toggle is not manual-only' {
        Set-Content -LiteralPath (Join-Path $Script:TempDir '.github\workflows\development-mode-toggle.yml') -Value @(
            'name: Toggle Development Mode'
            'on:'
            '  push:'
            '  workflow_dispatch:'
            'jobs: {}'
        ) -Encoding utf8

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*development-mode-toggle-not-manual*'
    }

    It 'passes when development-mode-toggle includes workflow_dispatch and workflow_call only' {
        Set-Content -LiteralPath (Join-Path $Script:TempDir '.github\workflows\development-mode-toggle.yml') -Value @(
            'name: Toggle Development Mode'
            'on:'
            '  workflow_call:'
            '  workflow_dispatch:'
            'jobs: {}'
        ) -Encoding utf8

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Not -Throw
    }

    It 'fails when a collaboration-heavy workflow has non-manual triggers' {
        Set-Content -LiteralPath (Join-Path $Script:TempDir '.github\workflows\ci-debt-train.yml') -Value @(
            'name: CI Debt Train'
            'on:'
            '  schedule:'
            '    - cron: ''30 9 * * 1'''
            '  workflow_dispatch:'
            'jobs: {}'
        ) -Encoding utf8

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*workflow-not-manual-only*'
    }

    It 'fails when ci-composite still includes auto publish mode' {
        Add-Content -LiteralPath (Join-Path $Script:TempDir '.github\workflows\ci-composite.yml') -Value "publishMode = 'auto'"

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*publish-not-explicit-intent*'
    }
}
