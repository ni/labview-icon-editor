$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '..\scripts\dev-mode-intents.ps1')
}

Describe "ConvertTo-DevModeIntent" {
    It "parses multiple intents with required prefix and caps to three" {
        $phrase = "/devmode unbind 2023 64-bit and bind 2023 32-bit and bind 2023 64-bit and bind 2023 32-bit"
        $intents = ConvertTo-DevModeIntent -Phrase $phrase

        $intents.Count | Should -Be 3
        $intents[0].Mode | Should -Be 'unbind'
        $intents[0].Bitness | Should -Be '64'
        $intents[1].Mode | Should -Be 'bind'
        $intents[1].Bitness | Should -Be '32'
        $intents | ForEach-Object { $_.ForceRequested } | Should -Contain $false
    }
}

Describe "Get-DevModeIntentPlan" {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'reports') -Force | Out-Null
    }

    It "blocks mismatched tokens when Force is not requested" {
        $summaryPath = Join-Path $repoRoot 'reports\dev-mode-bind.json'
        @(
            @{ bitness = '64'; expected_path = $repoRoot; current_path = 'C:\other\repo' }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

        $intents = ConvertTo-DevModeIntent -Phrase "/devmode bind 2023 64-bit"
        $plan = Get-DevModeIntentPlan -Intents $intents -RepositoryPath $repoRoot -SummaryPath $summaryPath

        $plan[0].Action | Should -Be 'blocked'
        $plan[0].ForceApplied | Should -BeFalse
        $plan[0].Reason | Should -Match 'Force'
    }

    It "marks skip when current_path already matches expected_path for bind" {
        $summaryPath = Join-Path $repoRoot 'reports\dev-mode-bind.json'
        @(
            @{ bitness = '64'; expected_path = $repoRoot; current_path = $repoRoot }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

        $intents = ConvertTo-DevModeIntent -Phrase "/devmode bind 2023 64-bit"
        $plan = Get-DevModeIntentPlan -Intents $intents -RepositoryPath $repoRoot -SummaryPath $summaryPath

        $plan[0].Action | Should -Be 'skip'
        $plan[0].Reason | Should -Match 'already bound'
    }
}

Describe "Invoke-DevModeIntents" {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'reports') -Force | Out-Null
        $script:summaryPath = Join-Path $repoRoot 'reports\dev-mode-bind.json'
        @(
            @{ bitness = '64'; expected_path = $repoRoot; current_path = 'C:\other\repo' }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

        $script:bindScript = Join-Path $repoRoot 'BindDevelopmentMode.ps1'
        Set-Content -LiteralPath $bindScript -Value "param()" -Encoding UTF8
    }

    It "applies Force only when requested and runs pending intents" {
        $script:captured = @()
        Mock -CommandName Invoke-BindScript -MockWith { param($BindScriptPath,$RepositoryPath,$Plan) $script:captured += $Plan } -Verifiable

        $plans = Invoke-DevModeIntents -Phrase "/devmode bind 2023 64-bit force" -RepositoryPath $repoRoot -SummaryPath $summaryPath -BindScriptPath $bindScript

        Assert-MockCalled Invoke-BindScript -Times 1 -Exactly
        $plans[0].Action | Should -Be 'pending'
        $captured[0].ForceApplied | Should -BeTrue
    }
}
