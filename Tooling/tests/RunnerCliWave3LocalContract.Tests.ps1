#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Test-RunnerCliWave3LocalContract.ps1' {
    BeforeAll {
        $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
        $Script:ContractScript = Join-Path $Script:ToolingRoot 'Test-RunnerCliWave3LocalContract.ps1'
        if (-not (Test-Path -LiteralPath $Script:ContractScript -PathType Leaf)) {
            throw "Contract script not found at $Script:ContractScript"
        }

        $Script:RepoRoot = (Resolve-Path -Path (Join-Path $Script:ToolingRoot '..')).Path
    }

    It 'passes against local orchestration and dev-mode action files' {
        { & $Script:ContractScript -RepoRoot $Script:RepoRoot } | Should -Not -Throw
    }

    It 'fails when Run-CI.ps1 loses runner-cli ppl build marker' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-wave3-contract-{0}" -f [guid]::NewGuid().ToString('N'))
        $workflowDir = Join-Path $tempRoot '.github\actions'
        $toolingDir = Join-Path $tempRoot 'Tooling'
        New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
        New-Item -Path $toolingDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $workflowDir 'set-development-mode') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $workflowDir 'revert-development-mode') -ItemType Directory -Force | Out-Null

        try {
            $localSource = Join-Path $Script:RepoRoot 'Tooling\Run-CI.ps1'
            $setSource = Join-Path $Script:RepoRoot '.github\actions\set-development-mode\Set_Development_Mode.ps1'
            $revertSource = Join-Path $Script:RepoRoot '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'

            $localDest = Join-Path $toolingDir 'Run-CI.ps1'
            $setDest = Join-Path $workflowDir 'set-development-mode\Set_Development_Mode.ps1'
            $revertDest = Join-Path $workflowDir 'revert-development-mode\RevertDevelopmentMode.ps1'

            Copy-Item -LiteralPath $localSource -Destination $localDest -Force
            Copy-Item -LiteralPath $setSource -Destination $setDest -Force
            Copy-Item -LiteralPath $revertSource -Destination $revertDest -Force

            $localContent = Get-Content -LiteralPath $localDest -Raw
            $localContent = $localContent -replace "'ppl',\s*'build'", "'ppl', 'buld'"
            Set-Content -LiteralPath $localDest -Value $localContent -Encoding utf8

            { & $Script:ContractScript -RepoRoot $tempRoot } | Should -Throw '*missing-required-pattern*'
        }
        finally {
            if (Test-Path -LiteralPath $tempRoot -PathType Container) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
