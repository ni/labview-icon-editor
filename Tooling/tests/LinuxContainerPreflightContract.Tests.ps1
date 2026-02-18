#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Linux container preflight helper contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:repoRoot = Split-Path -Parent $script:toolingRoot
        $script:scriptPath = Join-Path $script:repoRoot 'Tooling/Invoke-LinuxContainerPreflight.ps1'
        $script:scriptContent = Get-Content -Path $script:scriptPath -Raw
    }

    It 'defines the expected helper parameters' {
        Test-Path -Path $script:scriptPath -PathType Leaf | Should -BeTrue
        $script:scriptContent | Should -Match '\[string\]\$RepoRoot\s*=\s*''\.'''
        $script:scriptContent | Should -Match '\[string\]\$ContextOutputPath\s*=\s*'''''
        $script:scriptContent | Should -Match '\[string\]\$SummaryOutputPath\s*=\s*'''''
        $script:scriptContent | Should -Match '\[switch\]\$SkipViAnalyzer'
        $script:scriptContent | Should -Match '\[switch\]\$DryRun'
    }

    It 'resolves .lvcontainer and uses ReleaseTag for parity context release input' {
        $script:scriptContent | Should -Match 'Get-LabVIEWContainerReleaseInfo\s+-RepoRoot\s+\$resolvedRepoRoot'
        $script:scriptContent | Should -Match '\$summary\.release_tag\s*=\s*\[string\]\$containerInfo\.ReleaseTag'
        $script:scriptContent | Should -Match '''--lv-release'',\s*\$summary\.release_tag'
        $script:scriptContent | Should -Match '''parity'',\s*''context'''
        $script:scriptContent | Should -Match '''parity'',\s*''run'''
    }

    It 'runs dockerized VI Analyzer worker with linux task contract shape' {
        $script:scriptContent | Should -Match 'run-vi-analyzer-linux\.sh'
        $script:scriptContent | Should -Match 'Tooling/vi-analyzer/tasks\.linux\.json'
        $script:scriptContent | Should -Match 'LVIE_VI_ANALYZER_LABVIEW_YEAR'
        $script:scriptContent | Should -Match '''bash'',\s*''-lc'''
    }

    It 'emits deterministic summary keys in dry-run mode' {
        $summaryPath = Join-Path $TestDrive 'local-linux-preflight-summary.json'
        $contextPath = Join-Path $TestDrive 'local-preflight-parity-context.json'

        & pwsh -NoProfile -File $script:scriptPath `
            -RepoRoot $script:repoRoot `
            -ContextOutputPath $contextPath `
            -SummaryOutputPath $summaryPath `
            -SkipViAnalyzer `
            -DryRun

        $LASTEXITCODE | Should -Be 0
        Test-Path -Path $summaryPath -PathType Leaf | Should -BeTrue

        $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $summary.PSObject.Properties.Name | Should -Contain 'sha'
        $summary.PSObject.Properties.Name | Should -Contain 'lvcontainer_raw'
        $summary.PSObject.Properties.Name | Should -Contain 'release_tag'
        $summary.PSObject.Properties.Name | Should -Contain 'linux_image'
        $summary.PSObject.Properties.Name | Should -Contain 'parity_context_path'
        $summary.PSObject.Properties.Name | Should -Contain 'parity_run_exit_code'
        $summary.PSObject.Properties.Name | Should -Contain 'vi_analyzer_exit_code'
        $summary.PSObject.Properties.Name | Should -Contain 'status'
        $summary.PSObject.Properties.Name | Should -Contain 'timestamp_utc'
        $summary.status | Should -Be 'dry-run'
    }
}
