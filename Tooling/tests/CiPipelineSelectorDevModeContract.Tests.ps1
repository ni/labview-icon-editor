#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:GuardScript = Join-Path $Script:ToolingRoot 'Test-CiPipelineSelectorDevModeContract.ps1'
}

Describe 'Test-CiPipelineSelectorDevModeContract.ps1' {
    BeforeEach {
        $Script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-ci-contract-{0}" -f [guid]::NewGuid().ToString('N'))

        $requiredDirectories = @(
            '.github/workflows',
            'Tooling/container-parity'
        )
        foreach ($relativeDir in $requiredDirectories) {
            $fullDir = Join-Path $Script:TempDir ($relativeDir -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            New-Item -Path $fullDir -ItemType Directory -Force | Out-Null
        }

        $fileMap = @{
            '.github/workflows/ci.yml' = @(
                'name: CI'
                'jobs: {}'
            ) -join [Environment]::NewLine
            '.github/workflows/ci-composite.yml' = @(
                'name: CI Composite'
                'jobs: {}'
            ) -join [Environment]::NewLine
            '.github/workflows/labview-parity.yml' = @(
                'name: LabVIEW Parity'
                'jobs: {}'
            ) -join [Environment]::NewLine
            '.github/workflows/development-mode-toggle.yml' = @(
                'name: Development Mode Toggle'
                'on:'
                '  workflow_dispatch:'
                'jobs: {}'
            ) -join [Environment]::NewLine
            'Tooling/container-parity/runlabview-windows.ps1' = @(
                '$ErrorActionPreference = ''Stop'''
                'Write-Host ''windows container parity script'''
            ) -join [Environment]::NewLine
            'Tooling/container-parity/runlabview-linux.sh' = @(
                '#!/usr/bin/env bash'
                'set -euo pipefail'
                'echo "linux container parity script"'
            ) -join [Environment]::NewLine
        }

        foreach ($entry in $fileMap.GetEnumerator()) {
            $fullPath = Join-Path $Script:TempDir ($entry.Key -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            Set-Content -LiteralPath $fullPath -Value $entry.Value -Encoding utf8
        }
    }

    AfterEach {
        if (Test-Path -LiteralPath $Script:TempDir -PathType Container) {
            Remove-Item -LiteralPath $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'passes when CI selector/dev-mode forbidden patterns are absent' {
        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Not -Throw
    }

    It 'fails when ci.yml invokes Set_Development_Mode.ps1' {
        $ciPath = Join-Path $Script:TempDir '.github\workflows\ci.yml'
        Add-Content -LiteralPath $ciPath -Value 'run: .github/actions/set-development-mode/Set_Development_Mode.ps1'

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*workflow-devmode-script*'
    }

    It 'fails when development-mode-toggle invokes RevertDevelopmentMode.ps1' {
        $togglePath = Join-Path $Script:TempDir '.github\workflows\development-mode-toggle.yml'
        Add-Content -LiteralPath $togglePath -Value 'run: .github/actions/revert-development-mode/RevertDevelopmentMode.ps1'

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*workflow-devmode-script*'
    }

    It 'fails when ci-composite includes devmode-no-labview-smoke references' {
        $ciCompositePath = Join-Path $Script:TempDir '.github\workflows\ci-composite.yml'
        Add-Content -LiteralPath $ciCompositePath -Value '  devmode-no-labview-smoke:'

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*workflow-devmode-smoke-job*'
    }

    It 'passes in ci-only scope when ci-composite.yml is missing' {
        $ciCompositePath = Join-Path $Script:TempDir '.github\workflows\ci-composite.yml'
        Remove-Item -LiteralPath $ciCompositePath -Force

        { & $Script:GuardScript -RepoRoot $Script:TempDir -Scope ci-only } | Should -Not -Throw
    }

    It 'fails in all scope when ci-composite.yml is missing' {
        $ciCompositePath = Join-Path $Script:TempDir '.github\workflows\ci-composite.yml'
        Remove-Item -LiteralPath $ciCompositePath -Force

        { & $Script:GuardScript -RepoRoot $Script:TempDir -Scope all } | Should -Throw '*missing-target-file*'
    }

    It 'fails when runlabview-windows.ps1 contains selector plumbing' {
        $windowsScriptPath = Join-Path $Script:TempDir 'Tooling\container-parity\runlabview-windows.ps1'
        Add-Content -LiteralPath $windowsScriptPath -Value '$selectorViPath = ''Tooling\Run Icon Editor from Source Selector.vi'''

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*container-selector-plumbing*'
    }

    It 'fails when runlabview-linux.sh contains CI dev-mode plumbing' {
        $linuxScriptPath = Join-Path $Script:TempDir 'Tooling\container-parity\runlabview-linux.sh'
        Add-Content -LiteralPath $linuxScriptPath -Value 'ENABLE_DEVMODE_RAW="${CONTAINER_PARITY_ENABLE_DEVMODE:-false}"'

        { & $Script:GuardScript -RepoRoot $Script:TempDir } | Should -Throw '*container-devmode-plumbing*'
    }

    It 'fails in ci-only scope when development-mode-toggle invokes Set_Development_Mode.ps1' {
        $togglePath = Join-Path $Script:TempDir '.github\workflows\development-mode-toggle.yml'
        Add-Content -LiteralPath $togglePath -Value 'run: .github/actions/set-development-mode/Set_Development_Mode.ps1'

        { & $Script:GuardScript -RepoRoot $Script:TempDir -Scope ci-only } | Should -Throw '*workflow-devmode-script*'
    }
}
