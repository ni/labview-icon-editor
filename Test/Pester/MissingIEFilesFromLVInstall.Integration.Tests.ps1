$ErrorActionPreference = 'Stop'

Describe 'Verify IE Paths integration' {
    BeforeAll {
        $script:skipAll = $false
        $script:skipReason = ''
        $script:labviewVersion = $null
        $script:labviewBitness = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_BITNESS)) { '64' } else { $env:LABVIEW_BITNESS }
        $script:connectTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_CONNECT_TIMEOUT_MS)) { '120000' } else { $env:LABVIEW_CONNECT_TIMEOUT_MS }
        $script:processTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_PROCESS_TIMEOUT_MS)) { '300000' } else { $env:LABVIEW_PROCESS_TIMEOUT_MS }
        $script:bitnessesToTest = @()
        $script:missingPathsHelperLoaded = $false

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
            $regPaths = @()
            if ($Bitness -eq '32') {
                $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
                $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
            } else {
                $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
                $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
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

        function script:Invoke-Runner {
            param(
                [string]$ScriptPath,
                [string[]]$Arguments
            )

            $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
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


        $script:repoRoot = Get-RepoRoot
        $script:scriptPath = Join-Path $script:repoRoot 'Tooling\Invoke-MissingIEFilesFromLVInstall.ps1'
        $script:revertScript = Join-Path $script:repoRoot '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
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

        if (-not (Test-Path -Path $script:scriptPath)) {
            $script:skipAll = $true
            $script:skipReason = "Script not found at $script:scriptPath"
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        if (-not (Test-Path -Path $script:revertScript)) {
            $script:skipAll = $true
            $script:skipReason = "RevertDevelopmentMode.ps1 not found at $script:revertScript"
            return
        }

        $bitnessCandidates = Get-BitnessList -BitnessInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            if (-not (Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness)) {
                continue
            }

            $revertArgs = @(
                '-LabVIEWVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-RepoRoot', $script:repoRoot,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs
            )

            $revertResult = Invoke-Runner -ScriptPath $script:revertScript -Arguments $revertArgs
            if ($revertResult.ExitCode -eq 0) {
                $script:bitnessesToTest += $bitness
                continue
            }

            $missingPaths = @()
            if ($script:missingPathsHelperLoaded -and (Get-Command Get-DevModeMissingPathsFromOutput -ErrorAction SilentlyContinue)) {
                $missingPaths = Get-DevModeMissingPathsFromOutput -Output $revertResult.OutputLines
            }

            if ($missingPaths.Count -gt 0) {
                Write-Warning ("Skipping {0}-bit baseline verify; missing paths during revert: {1}" -f $bitness, ($missingPaths -join ', '))
            } else {
                Write-Warning ("Skipping {0}-bit baseline verify; revert failed with exit code {1}." -f $bitness, $revertResult.ExitCode)
            }
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available after baseline restore."
            return
        }
    }

    It 'runs VerifyIEPaths successfully' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        foreach ($bitness in $script:bitnessesToTest) {
            $scriptArgs = @(
                '-LabVIEWVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs
            )

            $result = Invoke-Runner -ScriptPath $script:scriptPath -Arguments $scriptArgs
            $result.ExitCode | Should -Be 0
        }
    }
}

