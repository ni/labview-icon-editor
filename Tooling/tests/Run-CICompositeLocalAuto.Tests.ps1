#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Run-CICompositeLocal-Auto success contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:scriptPath = Join-Path $script:toolingRoot 'Run-CICompositeLocal-Auto.ps1'
        if (-not (Test-Path -Path $script:scriptPath -PathType Leaf)) {
            throw "Run-CICompositeLocal-Auto.ps1 not found at $script:scriptPath"
        }

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw ("Failed to parse Run-CICompositeLocal-Auto.ps1: {0}" -f $errors[0].Message)
        }

        function Import-FunctionText {
            param(
                [Parameter(Mandatory = $true)]
                [System.Management.Automation.Language.Ast]$Ast,
                [Parameter(Mandatory = $true)]
                [string]$FunctionName
            )

            $node = $Ast.Find({
                param($candidate)
                $candidate -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $candidate.Name -eq $FunctionName
            }, $true)

            if (-not $node) {
                throw "Function '$FunctionName' not found in Run-CICompositeLocal-Auto.ps1"
            }

            $functionScript = [scriptblock]::Create($node.Extent.Text)
            . $functionScript
            $definition = (Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop).Definition
            Set-Item -Path ("Function:\script:{0}" -f $FunctionName) -Value $definition
            Remove-Item -Path ("Function:\{0}" -f $FunctionName) -ErrorAction SilentlyContinue
        }

        Import-FunctionText -Ast $ast -FunctionName 'Test-FreshFileSince'
        Import-FunctionText -Ast $ast -FunctionName 'Test-SuccessTargetSatisfied'
        Import-FunctionText -Ast $ast -FunctionName 'Get-AttemptStatusFromRunResult'
        Import-FunctionText -Ast $ast -FunctionName 'Initialize-CsvHeader'
        Import-FunctionText -Ast $ast -FunctionName 'Write-AutoHistoryEntry'
    }

    It 'classifies non-zero child exit as failure even without exception' {
        $status = Get-AttemptStatusFromRunResult -RunExitCode 5 -ErrorMessage $null
        $status | Should -Be 'exit:5'
    }

    It 'classifies explicit exception text as error status' {
        $status = Get-AttemptStatusFromRunResult -RunExitCode 0 -ErrorMessage 'boom'
        $status | Should -Be 'error:boom'
    }

    It 'fails SuccessTarget=ppl when either PPL artifact is missing or stale' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-auto-ppl-missing-{0}" -f [guid]::NewGuid().ToString('N'))
        $pluginDir = Join-Path $repoRoot 'resource\plugins'
        New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

        try {
            $attemptStart = (Get-Date).ToUniversalTime()

            $x86Path = Join-Path $pluginDir 'lv_icon_x86.lvlibp'
            Set-Content -Path $x86Path -Value 'stale' -Encoding ascii
            (Get-Item -Path $x86Path).LastWriteTimeUtc = $attemptStart.AddMinutes(-2)

            $result = Test-SuccessTargetSatisfied -Target 'ppl' -RepoRoot $repoRoot -AttemptStartUtc $attemptStart
            $result.Satisfied | Should -BeFalse
            $result.Detail | Should -Match 'missing/stale'
        }
        finally {
            if (Test-Path -Path $repoRoot -PathType Container) {
                Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'succeeds SuccessTarget=ppl when both PPL artifacts are fresh' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-auto-ppl-fresh-{0}" -f [guid]::NewGuid().ToString('N'))
        $pluginDir = Join-Path $repoRoot 'resource\plugins'
        New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

        try {
            $attemptStart = (Get-Date).ToUniversalTime()
            Start-Sleep -Milliseconds 200

            $x86Path = Join-Path $pluginDir 'lv_icon_x86.lvlibp'
            $x64Path = Join-Path $pluginDir 'lv_icon_x64.lvlibp'
            Set-Content -Path $x86Path -Value 'fresh-x86' -Encoding ascii
            Set-Content -Path $x64Path -Value 'fresh-x64' -Encoding ascii

            $result = Test-SuccessTargetSatisfied -Target 'ppl' -RepoRoot $repoRoot -AttemptStartUtc $attemptStart
            $result.Satisfied | Should -BeTrue
        }
        finally {
            if (Test-Path -Path $repoRoot -PathType Container) {
                Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'succeeds SuccessTarget=ppl-single for selected 64-bit output' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-auto-ppl-single-fresh-{0}" -f [guid]::NewGuid().ToString('N'))
        $pluginDir = Join-Path $repoRoot 'resource\plugins'
        New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

        try {
            $attemptStart = (Get-Date).ToUniversalTime()
            Start-Sleep -Milliseconds 200

            $x64Path = Join-Path $pluginDir 'lv_icon_x64.lvlibp'
            Set-Content -Path $x64Path -Value 'fresh-x64' -Encoding ascii

            $result = Test-SuccessTargetSatisfied -Target 'ppl-single' -RepoRoot $repoRoot -AttemptStartUtc $attemptStart -LabVIEWBitness '64'
            $result.Satisfied | Should -BeTrue
            $result.Detail | Should -Match 'Fresh single-bitness PPL found'
        }
        finally {
            if (Test-Path -Path $repoRoot -PathType Container) {
                Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'fails SuccessTarget=ppl-single when LabVIEWBitness is not single' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-auto-ppl-single-invalid-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $repoRoot -ItemType Directory -Force | Out-Null

        try {
            $attemptStart = (Get-Date).ToUniversalTime()
            $result = Test-SuccessTargetSatisfied -Target 'ppl-single' -RepoRoot $repoRoot -AttemptStartUtc $attemptStart -LabVIEWBitness 'both'
            $result.Satisfied | Should -BeFalse
            $result.Detail | Should -Match "requires LabVIEWBitness 32 or 64"
        }
        finally {
            if (Test-Path -Path $repoRoot -PathType Container) {
                Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'writes auto-run history with heuristic and diagnostics columns' {
        $csvPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-auto-history-{0}.csv" -f [guid]::NewGuid().ToString('N'))
        try {
            Initialize-CsvHeader -Path $csvPath -Header 'timestamp,attempt,status,duration_seconds,connect_timeout_ms,process_timeout_ms,heuristic_code,diagnostics_path'
            Write-AutoHistoryEntry `
                -Path $csvPath `
                -AttemptLabel 'attempt-1' `
                -Status 'exit:1' `
                -DurationSeconds 12.3 `
                -ConnectTimeoutMs 180000 `
                -ProcessTimeoutMs 300000 `
                -HeuristicCode 'SEQ_BOTH_FAIL' `
                -DiagnosticsPath 'C:\tmp\diag.json'

            $rows = Get-Content -Path $csvPath
            $rows.Count | Should -Be 2
            $rows[0] | Should -Be 'timestamp,attempt,status,duration_seconds,connect_timeout_ms,process_timeout_ms,heuristic_code,diagnostics_path'
            $rows[1] | Should -Match 'attempt-1'
            $rows[1] | Should -Match 'SEQ_BOTH_FAIL'
            $rows[1] | Should -Match 'diag.json'
        }
        finally {
            if (Test-Path -Path $csvPath -PathType Leaf) {
                Remove-Item -Path $csvPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
