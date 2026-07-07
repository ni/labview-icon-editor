$ErrorActionPreference = 'Stop'

Describe 'Development Mode integration' {
    BeforeAll {
        $script:skipAll = $false
        $script:skipReason = ''
        $script:installRoots = @{}
        $script:bitnessesToTest = @()
        $script:missingPathsHelperLoaded = $false
        $script:labviewVersion = $null
        $script:labviewBitness = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_BITNESS)) { '64' } else { $env:LABVIEW_BITNESS }
        $script:connectTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_CONNECT_TIMEOUT_MS)) { '120000' } else { $env:LABVIEW_CONNECT_TIMEOUT_MS }
        $script:processTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_PROCESS_TIMEOUT_MS)) { '300000' } else { $env:LABVIEW_PROCESS_TIMEOUT_MS }
        $script:runDevModeTests = $false

        if (-not [string]::IsNullOrWhiteSpace($env:RUN_DEV_MODE_TESTS)) {
            $flag = $env:RUN_DEV_MODE_TESTS.Trim().ToLowerInvariant()
            $script:runDevModeTests = @('1', 'true', 'yes', 'y') -contains $flag
        }

        function script:Get-RepoRoot {
            $root = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
            return $root.Path
        }

        function script:Get-LabVIEWInstallRoot {
            param(
                [string]$Version,
                [string]$Bitness
            )

            $candidates = @()
            if ($Bitness -eq '32') {
                $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
                $regPaths = @("HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version")
            } else {
                $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
                $regPaths = @("HKLM:\SOFTWARE\National Instruments\LabVIEW $Version")
            }

            foreach ($candidate in $candidates) {
                if (Test-Path -Path $candidate) {
                    return $candidate
                }
            }

            foreach ($regPath in $regPaths) {
                try {
                    $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
                    foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                        $value = $props.$name
                        if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                            return $value
                        }
                    }
                } catch {
                    continue
                }
            }

            return $null
        }

        function script:Get-BitnessList {
            param(
                [string]$BitnessInput
            )

            if ([string]::IsNullOrWhiteSpace($BitnessInput)) {
                return @('64')
            }

            $normalized = $BitnessInput.Trim().ToLowerInvariant()
            if (@('both', 'all', 'auto') -contains $normalized) {
                return @('64', '32')
            }

            $parts = $normalized -split '[,; ]+' | Where-Object { $_ }
            $bitnesses = foreach ($part in $parts) {
                switch ($part) {
                    '32' { '32' }
                    '64' { '64' }
                }
            }

            $bitnesses = $bitnesses | Where-Object { $_ } | Select-Object -Unique
            if (-not $bitnesses) {
                return @('64')
            }

            return @($bitnesses)
        }

        function script:Get-LabVIEWPathMap {
            param(
                [string]$InstallRoot
            )

            return @{
                IconApiFolder = Join-Path $InstallRoot 'vi.lib\LabVIEW Icon API'
                IconApiZip    = Join-Path $InstallRoot 'vi.lib\LabVIEW Icon API.zip'
                Lvlibp        = Join-Path $InstallRoot 'resource\plugins\lv_icon.lvlibp'
                Ship          = Join-Path $InstallRoot 'resource\plugins\lv_icon.ship'
            }
        }

        function script:Invoke-LabVIEWScript {
            param(
                [string]$ScriptPath,
                [string[]]$Arguments
            )

            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
            # Use PowerShell argument passing to preserve embedded spaces.
            $rawOutput = & $pwsh -NoProfile -File $ScriptPath @Arguments 2>&1
            $exitCode = $LASTEXITCODE
            $lines = @()
            foreach ($entry in $rawOutput) {
                if ($null -ne $entry) {
                    $lines += [string]$entry
                }
            }
            $lines | Out-Host
            return [pscustomobject]@{
                ExitCode    = $exitCode
                OutputLines = $lines
            }
        }

        function script:Get-ScriptArgumentList {
            param(
                [string]$LabVIEWVersion,
                [string]$RepoRoot,
                [string]$Bitness
            )

            return @(
                '-LabVIEWVersion', $LabVIEWVersion,
                '-RepoRoot', $RepoRoot,
                '-SupportedBitness', $Bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs
            )
        }

        $script:repoRoot = Get-RepoRoot
        $script:actionsRoot = Join-Path $script:repoRoot '.github\actions'
        $script:setScript = Join-Path $script:actionsRoot 'set-development-mode\Set_Development_Mode.ps1'
        $script:revertScript = Join-Path $script:actionsRoot 'revert-development-mode\RevertDevelopmentMode.ps1'
        $script:closeScript = Join-Path $script:actionsRoot 'close-labview\Close_LabVIEW.ps1'
        $script:missingPathsHelper = Join-Path $script:repoRoot 'Tooling\support\DevModeMissingPaths.ps1'
        $script:versionHelper = Join-Path $script:repoRoot 'Tooling\support\LabVIEWVersion.ps1'

        if (Test-Path -Path $script:missingPathsHelper) {
            . $script:missingPathsHelper
            $script:missingPathsHelperLoaded = $true
        }

        if (Test-Path -Path $script:versionHelper) {
            . $script:versionHelper
            $versionInput = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '' } else { $env:LABVIEW_VERSION }
            $versionInfo = Get-LabVIEWVersionInfo -VersionInput $versionInput -RepoRoot $script:repoRoot
            $script:labviewVersion = $versionInfo.Year
        }

        if ([string]::IsNullOrWhiteSpace($script:labviewVersion)) {
            $script:labviewVersion = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '2021' } else { $env:LABVIEW_VERSION }
        }

        if (-not $script:runDevModeTests) {
            $script:skipAll = $true
            $script:skipReason = 'Set RUN_DEV_MODE_TESTS=1 to enable dev-mode integration tests.'
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        $bitnessCandidates = Get-BitnessList -BitnessInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            $root = Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness
            if ($root) {
                $script:installRoots[$bitness] = $root
                $script:bitnessesToTest += $bitness
            }
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "LabVIEW $script:labviewVersion installs not found for requested bitness: $script:labviewBitness."
            return
        }

        $script:bitnessesToTest = $script:bitnessesToTest | Select-Object -Unique

        $filteredBitnesses = New-Object System.Collections.Generic.List[string]
        foreach ($bitness in $script:bitnessesToTest) {
            $scriptArgs = Get-ScriptArgumentList -LabVIEWVersion $script:labviewVersion -RepoRoot $script:repoRoot -Bitness $bitness
            $result = Invoke-LabVIEWScript -ScriptPath $script:revertScript -Arguments $scriptArgs
            if ($result.ExitCode -eq 0) {
                $filteredBitnesses.Add($bitness)
                continue
            }

            $missingPaths = @()
            if ($script:missingPathsHelperLoaded -and (Get-Command Get-DevModeMissingPathsFromOutput -ErrorAction SilentlyContinue)) {
                $missingPaths = Get-DevModeMissingPathsFromOutput -Output $result.OutputLines
            }

            if ($missingPaths -and $missingPaths.Count -gt 0) {
                Write-Warning ("Skipping {0}-bit tests; missing paths during baseline restore: {1}" -f $bitness, ($missingPaths -join ', '))
                continue
            }

            throw "Baseline restore failed for $bitness-bit with exit code $($result.ExitCode)."
        }

        $script:bitnessesToTest = $filteredBitnesses.ToArray()
        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = 'No supported bitnesses after baseline restore.'
            return
        }
    }

    AfterAll {
        if (-not $script:skipAll) {
            foreach ($bitness in $script:bitnessesToTest) {
                $scriptArgs = Get-ScriptArgumentList -LabVIEWVersion $script:labviewVersion -RepoRoot $script:repoRoot -Bitness $bitness
                $result = Invoke-LabVIEWScript -ScriptPath $script:revertScript -Arguments $scriptArgs
                if ($result.ExitCode -ne 0) {
                    throw "Failed to restore LabVIEW setup for $bitness-bit; exit code $($result.ExitCode)."
                }
            }
        }
    }

    It "runs Set_Development_Mode.ps1 successfully" {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        foreach ($bitness in $script:bitnessesToTest) {
            $scriptArgs = Get-ScriptArgumentList -LabVIEWVersion $script:labviewVersion -RepoRoot $script:repoRoot -Bitness $bitness
            $result = Invoke-LabVIEWScript -ScriptPath $script:setScript -Arguments $scriptArgs
            $result.ExitCode | Should -Be 0
            (Get-Process -Name LabVIEW -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
        }
    }

    It "applies expected PrepareIESource changes" {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        foreach ($bitness in $script:bitnessesToTest) {
            $paths = Get-LabVIEWPathMap -InstallRoot $script:installRoots[$bitness]
            (Test-Path -Path $paths.Ship) | Should -BeTrue
            (Test-Path -Path $paths.Lvlibp) | Should -BeFalse
            (Test-Path -Path $paths.IconApiFolder) | Should -BeFalse
            (Test-Path -Path $paths.IconApiZip) | Should -BeTrue
        }
    }

    It "runs RevertDevelopmentMode.ps1 successfully" {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        foreach ($bitness in $script:bitnessesToTest) {
            $scriptArgs = Get-ScriptArgumentList -LabVIEWVersion $script:labviewVersion -RepoRoot $script:repoRoot -Bitness $bitness
            $result = Invoke-LabVIEWScript -ScriptPath $script:revertScript -Arguments $scriptArgs
            $result.ExitCode | Should -Be 0
            (Get-Process -Name LabVIEW -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
        }
    }

    It "applies expected RestoreSetupLVSource changes" {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        foreach ($bitness in $script:bitnessesToTest) {
            $paths = Get-LabVIEWPathMap -InstallRoot $script:installRoots[$bitness]
            (Test-Path -Path $paths.Lvlibp) | Should -BeTrue
            (Test-Path -Path $paths.Ship) | Should -BeFalse
            (Test-Path -Path $paths.IconApiFolder) | Should -BeTrue
            (Test-Path -Path $paths.IconApiZip) | Should -BeFalse
        }
    }

}


