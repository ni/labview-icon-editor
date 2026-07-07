$ErrorActionPreference = 'Stop'

Describe 'Missing-in-project (dev mode, no LabVIEW) integration' {
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
        $script:missingScript = Join-Path $script:repoRoot '.github\actions\missing-in-project\Invoke-MissingInProjectCLI.ps1'

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

        if (-not (Test-Path -Path $script:missingScript)) {
            $script:skipAll = $true
            $script:skipReason = "Invoke-MissingInProjectCLI.ps1 not found at $script:missingScript"
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        $script:projectFile = Join-Path $script:repoRoot 'lv_icon_editor.lvproj'
        if (-not $script:projectFile) {
            $script:skipAll = $true
            $script:skipReason = 'No .lvproj file found in repo root.'
            return
        }

        $bitnessCandidates = Resolve-BitnessList -Bitnesses $null -FallbackInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            if (-not (Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness)) {
                continue
            }
            $script:bitnessesToTest += $bitness
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available after baseline check."
            return
        }
    }

    It 'runs missing-in-project using no-LabVIEW dev mode' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        $results = Invoke-LabVIEWStage `
            -StageName 'missing-in-project' `
            -RepoRoot $script:repoRoot `
            -LabVIEWVersion $script:labviewVersion `
            -Bitnesses $script:bitnessesToTest `
            -ConnectTimeoutMs ([int]$script:connectTimeoutMs) `
            -DevModeNoLabVIEW `
            -Action {
                param($context)
                $missingArgs = @(
                    '-LVVersion', $context.LabVIEWVersion,
                    '-Arch', $context.Bitness,
                    '-ProjectFile', $script:projectFile,
                    '-ConnectTimeoutMs', $context.ConnectTimeoutMs
                )
                $run = Invoke-LabVIEWScript -ScriptPath $script:missingScript -Arguments $missingArgs
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
