#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:ResolverScript = Join-Path $Script:ToolingRoot 'Resolve-CIWorktreeRoot.ps1'
    . $Script:ResolverScript
}

Describe 'Resolve-CIWorktreeRoot' {
    It 'prefers explicit worktree root over runner_temp and contract roots' {
        $explicit = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-explicit-$([guid]::NewGuid().ToString('N'))\"
        $runnerTemp = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-runner-$([guid]::NewGuid().ToString('N'))"
        $contract = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-contract-$([guid]::NewGuid().ToString('N'))"

        $result = Resolve-CIWorktreeRoot -Mode 'runner_temp' -ExplicitWorktreeRoot $explicit -RunnerTemp $runnerTemp -ContractWorktreeRoot $contract

        $result.Source | Should -Be 'explicit'
        $result.Path | Should -Be ([System.IO.Path]::GetFullPath($explicit).TrimEnd('\'))
        [System.IO.Path]::IsPathRooted($result.Path) | Should -BeTrue
    }

    It 'uses runner_temp root when mode is runner_temp and no explicit root is provided' {
        $runnerTemp = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-runner-$([guid]::NewGuid().ToString('N'))"
        $contract = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-contract-$([guid]::NewGuid().ToString('N'))"

        $result = Resolve-CIWorktreeRoot -Mode 'runner_temp' -RunnerTemp $runnerTemp -ContractWorktreeRoot $contract

        $result.Source | Should -Be 'runner_temp'
        $result.Path | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $runnerTemp 'lvie\w')).TrimEnd('\'))
        [System.IO.Path]::IsPathRooted($result.Path) | Should -BeTrue
    }

    It 'falls back to contract root when runner_temp mode is selected but runner temp is missing' {
        $contract = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-contract-$([guid]::NewGuid().ToString('N'))"

        $result = Resolve-CIWorktreeRoot -Mode 'runner_temp' -RunnerTemp '' -ContractWorktreeRoot $contract

        $result.Source | Should -Be 'contract'
        $result.Path | Should -Be ([System.IO.Path]::GetFullPath($contract).TrimEnd('\'))
    }

    It 'uses contract root when mode is contract' {
        $runnerTemp = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-runner-$([guid]::NewGuid().ToString('N'))"
        $contract = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-contract-$([guid]::NewGuid().ToString('N'))"

        $result = Resolve-CIWorktreeRoot -Mode 'contract' -RunnerTemp $runnerTemp -ContractWorktreeRoot $contract

        $result.Source | Should -Be 'contract'
        $result.Path | Should -Be ([System.IO.Path]::GetFullPath($contract).TrimEnd('\'))
    }

    It 'throws when no path source can be resolved' {
        { Resolve-CIWorktreeRoot -Mode 'contract' -RunnerTemp '' -ContractWorktreeRoot '' } | Should -Throw '*Unable to resolve worktree root*'
    }
}
