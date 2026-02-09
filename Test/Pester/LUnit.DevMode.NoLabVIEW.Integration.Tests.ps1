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
        $script:labviewNumericVersion = ''
        $script:hasLabVIEWCli = $false
        $script:hasGcli = $false
        $script:enableGcliFallback = $false
        $script:stageLogRoot = Join-Path $PSScriptRoot 'tmp\lunit-stage-logs'

        if (-not [string]::IsNullOrWhiteSpace($env:RUN_DEV_MODE_TESTS)) {
            $flag = $env:RUN_DEV_MODE_TESTS.Trim().ToLowerInvariant()
            $script:runDevModeTests = @('1', 'true', 'yes', 'y') -contains $flag
        }
        if (-not [string]::IsNullOrWhiteSpace($env:LVIE_ENABLE_GCLI_LUNIT_FALLBACK)) {
            $fallbackFlag = $env:LVIE_ENABLE_GCLI_LUNIT_FALLBACK.Trim().ToLowerInvariant()
            $script:enableGcliFallback = @('1', 'true', 'yes', 'y', 'on') -contains $fallbackFlag
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

        $versionHelper = Join-Path $script:repoRoot 'Tooling\support\LabVIEWVersion.ps1'
        if (Test-Path -Path $versionHelper) {
            . $versionHelper
            $versionInfo = Get-LabVIEWVersionInfo -VersionInput $versionInput -RepoRoot $script:repoRoot
            $script:labviewNumericVersion = $versionInfo.NumericVersion
        } else {
            $script:labviewNumericVersion = '21.0'
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

        $script:hasLabVIEWCli = [bool](Get-Command LabVIEWCLI -ErrorAction SilentlyContinue)
        $script:hasGcli = [bool](Get-Command g-cli -ErrorAction SilentlyContinue)
        if (-not $script:hasLabVIEWCli) {
            $script:skipAll = $true
            $script:skipReason = 'LabVIEWCLI is not available in PATH.'
            return
        }
        if ($script:enableGcliFallback -and -not $script:hasGcli) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli fallback is enabled for this test but g-cli is not available in PATH.'
            return
        }

        $script:projectFile = Join-Path $script:repoRoot 'lv_icon_editor.lvproj'
        if (-not (Test-Path -Path $script:projectFile)) {
            $script:skipAll = $true
            $script:skipReason = "Project file not found: $script:projectFile"
            return
        }

        function Test-LUnitPackageInstalled {
            param(
                [string]$NumericVersion,
                [ValidateSet('32', '64')]
                [string]$Bitness,
                [Parameter(Mandatory = $true)]
                [string]$PackageId
            )

            $dbRoot = Join-Path $env:ProgramData 'JKI\VIPM\databases'
            if (-not (Test-Path -Path $dbRoot -PathType Container)) {
                return $false
            }

            $dbFolder = if ($Bitness -eq '64') { "LV $NumericVersion (64-bit)" } else { "LV $NumericVersion" }
            $pkgPath = Join-Path (Join-Path $dbRoot $dbFolder) $PackageId
            return (Test-Path -Path $pkgPath -PathType Container)
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

            $canUseLabVIEWCli = Test-LUnitPackageInstalled -NumericVersion $script:labviewNumericVersion -Bitness $bitness -PackageId 'astemes_lib_lunit_cli'
            $canUseGcli = $script:enableGcliFallback -and $script:hasGcli -and (Test-LUnitPackageInstalled -NumericVersion $script:labviewNumericVersion -Bitness $bitness -PackageId 'sas_workshops_lib_lunit_for_g_cli')

            if (-not $canUseLabVIEWCli) {
                Write-Warning ("Skipping {0}-bit LUnit; dependency 'astemes_lib_lunit_cli' is required for LabVIEWCLI mode (LV {1})." -f $bitness, $script:labviewNumericVersion)
                continue
            }

            if ($script:enableGcliFallback -and -not $canUseGcli) {
                Write-Warning ("Skipping {0}-bit LUnit; fallback enabled but dependency 'sas_workshops_lib_lunit_for_g_cli' is missing (LV {1})." -f $bitness, $script:labviewNumericVersion)
                continue
            }

            $script:bitnessesToTest += $bitness
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available for LUnit (LabVIEWCLI package missing, fallback package missing when enabled, or LabVIEW not installed)."
            return
        }
    }

    It 'runs LUnit in dev mode' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        if (Test-Path -Path $script:stageLogRoot) {
            Remove-Item -Path $script:stageLogRoot -Recurse -Force
        }
        New-Item -Path $script:stageLogRoot -ItemType Directory -Force | Out-Null

        $previousStageLogRoot = $env:LVIE_STAGE_LOG_ROOT
        $env:LVIE_STAGE_LOG_ROOT = $script:stageLogRoot
        try {
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
                    if ($script:enableGcliFallback) {
                        $unitArgs += '-EnableGcliFallback'
                    }
                    $run = Invoke-LabVIEWScript -ScriptPath $script:lunitScript -Arguments $unitArgs
                    return $run
                }
        }
        finally {
            if ($null -eq $previousStageLogRoot) {
                Remove-Item Env:LVIE_STAGE_LOG_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:LVIE_STAGE_LOG_ROOT = $previousStageLogRoot
            }
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

        $summaryFile = Get-ChildItem -Path $script:stageLogRoot -Filter 'labview-stage-lunit-*-summary.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        $summaryFile | Should -Not -BeNullOrEmpty

        $summary = Get-Content -Path $summaryFile.FullName -Raw | ConvertFrom-Json
        $summary.LogFile | Should -Not -BeNullOrEmpty
        (Test-Path -Path $summary.LogFile -PathType Leaf) | Should -BeTrue

        $logEntries = Get-Content -Path $summary.LogFile -ErrorAction Stop | ForEach-Object {
            $_ | ConvertFrom-Json
        }

        foreach ($result in $ran) {
            $entry = $logEntries | Where-Object { $_.Bitness -eq $result.Bitness } | Select-Object -Last 1
            $entry | Should -Not -BeNullOrEmpty
            $tailText = @($entry.Steps.Action.OutputTail) -join "`n"
            $tailText | Should -Match 'Executing LabVIEWCLI LUnit operation|Falling back to g-cli LUnit execution'
        }
    }
}
