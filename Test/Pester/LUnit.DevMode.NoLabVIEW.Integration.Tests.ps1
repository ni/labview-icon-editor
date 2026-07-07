$ErrorActionPreference = 'Stop'

Describe 'LUnit (dev mode, no LabVIEW) integration' {
    BeforeAll {
        $script:skipAll = $false
        $script:skipReason = ''
        $script:labviewVersion = $null
        $script:labviewBitness = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_BITNESS)) { '64' } else { $env:LABVIEW_BITNESS }
        $script:connectTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_CONNECT_TIMEOUT_MS)) { '120000' } else { $env:LABVIEW_CONNECT_TIMEOUT_MS }
        $script:bitnessesToTest = @()
        $script:projectFile = $null
        $script:runDevModeTests = $false

        if (-not [string]::IsNullOrWhiteSpace($env:RUN_DEV_MODE_TESTS)) {
            $flag = $env:RUN_DEV_MODE_TESTS.Trim().ToLowerInvariant()
            $script:runDevModeTests = @('1', 'true', 'yes', 'y') -contains $flag
        }

        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:stageModule = Join-Path $script:repoRoot 'Tooling\support\LabVIEWStage.ps1'
        $script:lunitScript = Join-Path $script:repoRoot '.github\actions\run-unit-tests\RunUnitTests.ps1'

        if (-not (Test-Path -Path $script:stageModule)) {
            $script:skipAll = $true
            $script:skipReason = "LabVIEWStage.ps1 not found at $script:stageModule"
            return
        }
        . $script:stageModule

        $versionInput = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '' } else { $env:LABVIEW_VERSION }
        $script:labviewVersion = Resolve-LabVIEWVersion -VersionInput $versionInput -RepoRoot $script:repoRoot

        if ([string]::IsNullOrWhiteSpace($script:labviewVersion)) {
            $script:labviewVersion = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '2021' } else { $env:LABVIEW_VERSION }
        }

        if (-not $script:runDevModeTests) {
            $script:skipAll = $true
            $script:skipReason = 'Set RUN_DEV_MODE_TESTS=1 to enable this integration test.'
            return
        }

        if (-not (Test-Path -Path $script:lunitScript)) {
            $script:skipAll = $true
            $script:skipReason = "RunUnitTests.ps1 not found at $script:lunitScript"
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        $script:projectFile = Join-Path $script:repoRoot 'lv_icon_editor.lvproj'
        if (-not (Test-Path -Path $script:projectFile)) {
            $script:skipAll = $true
            $script:skipReason = "Project file not found: $script:projectFile"
            return
        }

        $bitnessCandidates = Resolve-BitnessList -Bitnesses $null -FallbackInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            $installRoot = Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness
            if (-not $installRoot) {
                continue
            }

            $lunitPath = Join-Path $installRoot 'vi.lib\Astemes\LUnit'
            if (-not (Test-Path -Path $lunitPath)) {
                Write-Warning ("Skipping {0}-bit LUnit; dependency not found at {1}." -f $bitness, $lunitPath)
                continue
            }

            $script:bitnessesToTest += $bitness
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available for LUnit."
            return
        }
    }

    It 'runs LUnit in dev mode' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        $results = Invoke-LabVIEWStage `
            -StageName 'lunit' `
            -RepoRoot $script:repoRoot `
            -LabVIEWVersion $script:labviewVersion `
            -Bitnesses $script:bitnessesToTest `
            -ConnectTimeoutMs ([int]$script:connectTimeoutMs) `
            -DevModeNoLabVIEW `
            -Action {
                param($context)
                $unitArgs = @(
                    '-LabVIEWVersion', $context.LabVIEWVersion,
                    '-SupportedBitness', $context.Bitness,
                    '-ProjectPath', $script:projectFile,
                    '-ConnectTimeoutMs', $context.ConnectTimeoutMs
                )
                $run = Invoke-LabVIEWScript -ScriptPath $script:lunitScript -Arguments $unitArgs
                return $run
            }

        if (-not $results -or $results.Count -eq 0) {
            Set-ItResult -Skipped -Because 'No matching LabVIEW installs.'
            return
        }

        $ran = $results | Where-Object { -not $_.Skipped }
        if (-not $ran -or $ran.Count -eq 0) {
            $reason = ($results | Where-Object { $_.Skipped } | Select-Object -First 1).SkipReason
            Set-ItResult -Skipped -Because $reason
            return
        }

        foreach ($result in $ran) {
            $result.Succeeded | Should -BeTrue -Because ($result.Error)
        }
    }
}
