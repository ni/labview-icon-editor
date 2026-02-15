#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Test-RunnerCliWave1WorkflowContract.ps1' {
    BeforeAll {
        $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
        $Script:ContractScript = Join-Path $Script:ToolingRoot 'Test-RunnerCliWave1WorkflowContract.ps1'
        if (-not (Test-Path -LiteralPath $Script:ContractScript -PathType Leaf)) {
            throw "Contract script not found at $Script:ContractScript"
        }

        $Script:RepoRoot = (Resolve-Path -Path (Join-Path $Script:ToolingRoot '..')).Path
    }

    It 'passes against repository workflow files' {
        { & $Script:ContractScript -RepoRoot $Script:RepoRoot } | Should -Not -Throw
    }

    It 'fails when ci-composite.yml is missing runner-cli vipc apply invocation marker' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-wave1-contract-{0}" -f [guid]::NewGuid().ToString('N'))
        $workflowDir = Join-Path $tempRoot '.github\workflows'
        New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null

        try {
            $ciSource = Join-Path $Script:RepoRoot '.github\workflows\ci.yml'
            $ciCompositeSource = Join-Path $Script:RepoRoot '.github\workflows\ci-composite.yml'
            $ciDest = Join-Path $workflowDir 'ci.yml'
            $ciCompositeDest = Join-Path $workflowDir 'ci-composite.yml'

            Copy-Item -LiteralPath $ciSource -Destination $ciDest -Force
            Copy-Item -LiteralPath $ciCompositeSource -Destination $ciCompositeDest -Force

            $ciCompositeContent = Get-Content -LiteralPath $ciCompositeDest -Raw
            $ciCompositeContent = $ciCompositeContent -replace "'vipc', 'apply'", "'vipc', 'applx'"
            Set-Content -LiteralPath $ciCompositeDest -Value $ciCompositeContent -Encoding utf8

            { & $Script:ContractScript -RepoRoot $tempRoot } | Should -Throw '*missing-required-pattern*'
        }
        finally {
            if (Test-Path -LiteralPath $tempRoot -PathType Container) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
