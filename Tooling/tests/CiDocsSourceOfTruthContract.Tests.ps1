#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI docs source-of-truth contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:guardScript = Join-Path $script:repoRoot 'Tooling\Test-CiDocsSourceOfTruth.ps1'
    }

    It 'passes against the repository workspace' {
        { & $script:guardScript -RepoRoot $script:repoRoot } | Should -Not -Throw
    }

    It 'fails when stale issue-status claim appears in core docs' {
        $tempRoot = Join-Path $TestDrive 'repo'
        $workflowDir = Join-Path $tempRoot '.github\workflows'
        $docsDir = Join-Path $tempRoot 'docs'
        $ciActionsDir = Join-Path $tempRoot 'docs\ci\actions'
        $toolingDir = Join-Path $tempRoot 'Tooling'

        New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
        New-Item -Path $docsDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $docsDir 'ci') -ItemType Directory -Force | Out-Null
        New-Item -Path $ciActionsDir -ItemType Directory -Force | Out-Null
        New-Item -Path $toolingDir -ItemType Directory -Force | Out-Null

        $dispatchInputs = @(
            'dispatch_tag',
            'allow_baseline_update',
            'expected_sha',
            'strict_sha',
            'publish_prerelease',
            'force_gcli_lunit',
            'vipc_apply_info',
            'source_test_mode',
            'source_test_labview_year_override'
        )

        $jobs = @(
            'run-metadata',
            'prerelease-context',
            'runner-cli-build',
            'runner-cli-build-win',
            'version-gate',
            'core-conformance-hosted-linux',
            'core-conformance-hosted-windows',
            'conformance-full',
            'powershell-lint',
            'vip-prerelease-requirements-lint',
            'docs-lint',
            'pylavi-validate',
            'changes',
            'apply-deps-64',
            'apply-deps-32',
            'vi-analyzer',
            'version',
            'unit-tests',
            'build-ppl-x86',
            'build-ppl-x64',
            'build-vip',
            'build-ppl-linux-container',
            'build-ppl-windows-container',
            'codex-skill-layer-asset',
            'publish-gate',
            'publish-prerelease',
            'pipeline-contract',
            'required-context'
        )

        $ciLines = @(
            'name: CI Pipeline',
            'on:',
            '  push:',
            '    branches:',
            '      - main',
            '      - develop',
            '      - release/*',
            '  pull_request:',
            '    branches:',
            '      - main',
            '      - develop',
            '      - release/*',
            '      - feature/*',
            '      - hotfix/*',
            '  workflow_dispatch:',
            '    inputs:'
        )

        foreach ($dispatchInputName in $dispatchInputs) {
            $ciLines += "      ${dispatchInputName}:"
            $ciLines += '        required: false'
        }

        $ciLines += 'jobs:'
        foreach ($job in $jobs) {
            $ciLines += "  ${job}:"
            if ($job -eq 'required-context') {
                $ciLines += '    name: CI Required / Lint+Contract'
            }
            if ($job -eq 'prerelease-context') {
                $ciLines += '    steps:'
                $ciLines += '      - run: |'
                $ciLines += '          release-priority'
                $ciLines += '          pr-fast'
                $ciLines += '          full'
                continue
            }
            $ciLines += '    runs-on: ubuntu-latest'
        }

        Set-Content -Path (Join-Path $workflowDir 'ci.yml') -Encoding utf8 -Value ($ciLines -join [Environment]::NewLine)

        $coreDocs = @(
            'README.md',
            'CONTRIBUTING.md',
            'docs/README.md',
            'docs/ci-workflows.md',
            'docs/ci/troubleshooting-faq.md',
            'docs/manual-instructions.md',
            'docs/automated-setup.md',
            'docs/powershell-dependency-scripts.md',
            'docs/ci/actions/build-vi-package.md',
            'docs/ci/actions/runner-setup-guide.md',
            'Tooling/README.md',
            'AGENTS.md'
        )

        foreach ($relative in $coreDocs) {
            $fullPath = Join-Path $tempRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            $directory = Split-Path -Path $fullPath -Parent
            if (-not (Test-Path -Path $directory -PathType Container)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            Set-Content -Path $fullPath -Encoding utf8 -Value @(
                '# Document',
                '',
                'Source of truth: .github/workflows/ci.yml'
            )
        }

        Set-Content -Path (Join-Path $tempRoot 'README.md') -Encoding utf8 -Value @(
            '# Document',
            '',
            'This stale issue-status gate claim should fail.'
        )

        { & $script:guardScript -RepoRoot $tempRoot } | Should -Throw '*stale-issue-status-gate*'
    }
}
