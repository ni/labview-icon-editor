#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW parity mode resolution semantics' {
    BeforeAll {
        function Resolve-ParityModeBehavior {
            param(
                [string]$ParityModeInput,
                [string]$EventName,
                [string]$RefName,
                [ValidateSet('true', 'false', 'unknown')]
                [string]$SelfHostedAvailable,
                [ValidateSet('true', 'false')]
                [string]$Requested64,
                [ValidateSet('true', 'false')]
                [string]$Requested32
            )

            $mode = if ([string]::IsNullOrWhiteSpace($ParityModeInput)) {
                if ($EventName -eq 'push' -and $RefName -eq 'develop') { 'full' } else { 'auto' }
            } else {
                $ParityModeInput.Trim().ToLowerInvariant()
            }

            if ($mode -notin @('auto', 'containers-only', 'full')) {
                throw "Invalid parity mode '$mode'"
            }

            $available = ($SelfHostedAvailable -eq 'true')
            $effective64 = 'false'
            $effective32 = 'false'
            switch ($mode) {
                'containers-only' {
                    $effective64 = 'false'
                    $effective32 = 'false'
                }
                'auto' {
                    if ($available) {
                        $effective64 = $Requested64
                        $effective32 = $Requested32
                    }
                }
                'full' {
                    if ($available) {
                        $effective64 = $Requested64
                        $effective32 = $Requested32
                    }
                }
            }

            [pscustomobject]@{
                ModeEffective = $mode
                Run64Effective = $effective64
                Run32Effective = $effective32
            }
        }

        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/labview-parity.yml'
        $script:workflowContent = Get-Content -LiteralPath $script:workflowPath -Raw
    }

    It 'defaults to auto for pull_request when parity_mode is omitted' {
        $result = Resolve-ParityModeBehavior -ParityModeInput '' -EventName 'pull_request' -RefName 'feature/test' -SelfHostedAvailable 'unknown' -Requested64 'true' -Requested32 'true'
        $result.ModeEffective | Should -Be 'auto'
    }

    It 'defaults to full for push to develop when parity_mode is omitted' {
        $result = Resolve-ParityModeBehavior -ParityModeInput '' -EventName 'push' -RefName 'develop' -SelfHostedAvailable 'true' -Requested64 'true' -Requested32 'true'
        $result.ModeEffective | Should -Be 'full'
    }

    It 'keeps containers-only mode independent of availability' {
        $result = Resolve-ParityModeBehavior -ParityModeInput 'containers-only' -EventName 'workflow_dispatch' -RefName 'develop' -SelfHostedAvailable 'true' -Requested64 'true' -Requested32 'true'
        $result.ModeEffective | Should -Be 'containers-only'
        $result.Run64Effective | Should -Be 'false'
        $result.Run32Effective | Should -Be 'false'
    }

    It 'degrades auto mode to containers-only behavior when self-hosted is unavailable' {
        $result = Resolve-ParityModeBehavior -ParityModeInput 'auto' -EventName 'workflow_dispatch' -RefName 'develop' -SelfHostedAvailable 'false' -Requested64 'true' -Requested32 'true'
        $result.Run64Effective | Should -Be 'false'
        $result.Run32Effective | Should -Be 'false'
    }

    It 'degrades full mode to effective false lanes when self-hosted is unavailable' {
        $result = Resolve-ParityModeBehavior -ParityModeInput 'full' -EventName 'push' -RefName 'develop' -SelfHostedAvailable 'unknown' -Requested64 'true' -Requested32 'true'
        $result.Run64Effective | Should -Be 'false'
        $result.Run32Effective | Should -Be 'false'
    }

    It 'throws for invalid parity mode values' {
        { Resolve-ParityModeBehavior -ParityModeInput 'fast' -EventName 'pull_request' -RefName 'x' -SelfHostedAvailable 'true' -Requested64 'true' -Requested32 'true' } | Should -Throw
    }

    It 'publishes workflow outputs for effective mode and effective self-hosted toggles' {
        $workflowContent | Should -Match 'parity_mode_effective=\$parityModeEffective'
        $workflowContent | Should -Match 'self_hosted_available=\$selfHostedAvailable'
        $workflowContent | Should -Match 'run_self_hosted_64_effective=\$runSelfHosted64Effective'
        $workflowContent | Should -Match 'run_self_hosted_32_effective=\$runSelfHosted32Effective'
        $workflowContent | Should -Match 'switch \(\$parityModeEffective\)'
    }
}
