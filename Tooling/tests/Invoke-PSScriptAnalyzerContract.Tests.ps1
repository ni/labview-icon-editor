#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Invoke-PSScriptAnalyzer FailOnIssues contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:scriptPath = Join-Path $script:repoRoot 'Tooling\Invoke-PSScriptAnalyzer.ps1'

        $script:tempRepo = Join-Path $TestDrive 'repo'
        $script:tempTooling = Join-Path $script:tempRepo 'Tooling'
        New-Item -Path $script:tempTooling -ItemType Directory -Force | Out-Null

        $script:settingsPath = Join-Path $script:tempTooling 'PSScriptAnalyzerSettings.psd1'
        $script:baselinePath = Join-Path $script:tempTooling 'PSScriptAnalyzerBaseline.json'
        $script:filePath = Join-Path $script:tempRepo 'sample.ps1'

        '@{ }' | Out-File -FilePath $script:settingsPath -Encoding utf8
        '[]' | Out-File -FilePath $script:baselinePath -Encoding utf8
        'Write-Host "sample"' | Out-File -FilePath $script:filePath -Encoding utf8
    }

    BeforeEach {
        function global:Invoke-ScriptAnalyzer {
            param(
                [string]$Path,
                [string]$Settings
            )

            return @(
                [pscustomobject]@{
                    RuleName   = 'PSAvoidUsingWriteHost'
                    Severity   = 'Warning'
                    Message    = 'Avoid Write-Host'
                    ScriptPath = $Path
                    Line       = 1
                    Column     = 1
                }
            )
        }
    }

    AfterEach {
        Remove-Item -Path Function:\Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
    }

    It 'accepts quoted false for FailOnIssues and does not throw on new findings' {
        {
            & $script:scriptPath `
                -RepoRoot $script:tempRepo `
                -SettingsPath $script:settingsPath `
                -BaselinePath $script:baselinePath `
                -FailOnIssues 'false'
        } | Should -Not -Throw
    }

    It 'treats quoted true for FailOnIssues as enforcing mode' {
        {
            & $script:scriptPath `
                -RepoRoot $script:tempRepo `
                -SettingsPath $script:settingsPath `
                -BaselinePath $script:baselinePath `
                -FailOnIssues 'true'
        } | Should -Throw '*PSScriptAnalyzer detected new issues*'
    }

    It 'rejects invalid FailOnIssues string values with a clear error' {
        {
            & $script:scriptPath `
                -RepoRoot $script:tempRepo `
                -SettingsPath $script:settingsPath `
                -BaselinePath $script:baselinePath `
                -FailOnIssues 'maybe'
        } | Should -Throw "*Parameter 'FailOnIssues' expects a Boolean value*"
    }
}
