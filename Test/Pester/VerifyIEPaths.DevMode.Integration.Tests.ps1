$ErrorActionPreference = 'Stop'

Describe 'Verify IE Paths (dev mode) integration' {
    BeforeAll {
        $script:skipAll = $false
        $script:skipReason = ''
        $script:labviewVersion = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '2021' } else { $env:LABVIEW_VERSION }
        $script:labviewBitness = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_BITNESS)) { '64' } else { $env:LABVIEW_BITNESS }
        $script:connectTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_CONNECT_TIMEOUT_MS)) { '120000' } else { $env:LABVIEW_CONNECT_TIMEOUT_MS }
        $script:processTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_PROCESS_TIMEOUT_MS)) { '300000' } else { $env:LABVIEW_PROCESS_TIMEOUT_MS }
        $script:bitnessesToTest = @()

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
            & $pwsh -NoProfile -File $ScriptPath @Arguments | Out-Host
            return $LASTEXITCODE
        }

        $script:repoRoot = Get-RepoRoot
        $script:setScript = Join-Path $script:repoRoot '.github\actions\set-development-mode\Set_Development_Mode.ps1'
        $script:revertScript = Join-Path $script:repoRoot '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
        $script:verifyScript = Join-Path $script:repoRoot 'Tooling\Invoke-MissingIEFilesFromLVInstall.ps1'
        $script:statusHelper = Join-Path $script:repoRoot 'Tooling\support\VerifyIEPathsStatus.ps1'

        if (-not $script:runDevModeTests) {
            $script:skipAll = $true
            $script:skipReason = 'Set RUN_DEV_MODE_TESTS=1 to enable this integration test.'
            return
        }

        if ($script:labviewVersion -ne '2021') {
            $script:skipAll = $true
            $script:skipReason = 'Only LabVIEW 2021 (21.0) is supported by this test suite.'
            return
        }

        if (-not (Test-Path -Path $script:setScript)) {
            $script:skipAll = $true
            $script:skipReason = "Set_Development_Mode.ps1 not found at $script:setScript"
            return
        }

        if (-not (Test-Path -Path $script:revertScript)) {
            $script:skipAll = $true
            $script:skipReason = "RevertDevelopmentMode.ps1 not found at $script:revertScript"
            return
        }

        if (-not (Test-Path -Path $script:verifyScript)) {
            $script:skipAll = $true
            $script:skipReason = "VerifyIEPaths runner not found at $script:verifyScript"
            return
        }

        if (-not (Test-Path -Path $script:statusHelper)) {
            $script:skipAll = $true
            $script:skipReason = "VerifyIEPaths status helper not found at $script:statusHelper"
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        $bitnessCandidates = Get-BitnessList -BitnessInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            if (-not (Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness)) {
                continue
            }

            $revertArgs = @(
                '-MinimumSupportedLVVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs,
                '-RepoRoot', $script:repoRoot
            )

            $exitCode = Invoke-Runner -ScriptPath $script:revertScript -Arguments $revertArgs
            if ($exitCode -eq 0) {
                $script:bitnessesToTest += $bitness
                continue
            }

            Write-Warning ("Skipping {0}-bit dev-mode verify; baseline revert failed with exit code {1}." -f $bitness, $exitCode)
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available after baseline restore."
            return
        }
    }

    It 'detects missing paths after enabling development mode' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        . $script:statusHelper

        foreach ($bitness in $script:bitnessesToTest) {
            $setArgs = @(
                '-MinimumSupportedLVVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs,
                '-RepoRoot', $script:repoRoot
            )

            $archiveRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'labview-icon-editor'
            $archiveDir = Join-Path -Path $archiveRoot -ChildPath ("verify-iepaths-$bitness-" + [Guid]::NewGuid().ToString('N'))
            New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null

            $runStartUtc = (Get-Date).ToUniversalTime()

            $verifyArgs = @(
                '-MinimumSupportedLVVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs,
                '-IgnoreStatusFailure',
                '-IgnoreGcliExitCode',
                '-StatusFileArchiveDirectory', $archiveDir
            )

            $revertArgs = @(
                '-MinimumSupportedLVVersion', $script:labviewVersion,
                '-SupportedBitness', $bitness,
                '-ConnectTimeoutMs', $script:connectTimeoutMs,
                '-ProcessTimeoutMs', $script:processTimeoutMs,
                '-RepoRoot', $script:repoRoot
            )

            try {
                $exitCode = Invoke-Runner -ScriptPath $script:revertScript -Arguments $revertArgs
                $exitCode | Should -Be 0

                $exitCode = Invoke-Runner -ScriptPath $script:setScript -Arguments $setArgs
                $exitCode | Should -Be 0

                $exitCode = Invoke-Runner -ScriptPath $script:verifyScript -Arguments $verifyArgs
                $exitCode | Should -Be 0

                $archivedStatus = Get-ChildItem -Path $archiveDir -File -Filter 'missing_IE_paths*.txt' -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTimeUtc -ge $runStartUtc } |
                    Sort-Object -Property LastWriteTimeUtc -Descending |
                    Select-Object -First 1

                if (-not $archivedStatus) {
                    throw "Archived VerifyIEPaths status file not found in $archiveDir"
                }

                $statusInfo = Get-VerifyIEPathsStatus -StatusFilePath $archivedStatus.FullName
                $statusInfo.MissingPaths.Count | Should -BeGreaterThan 0
                ($statusInfo.MissingPaths | Where-Object { $_ -match 'LabVIEW Icon API' }).Count | Should -BeGreaterThan 0
                ($statusInfo.MissingPaths | Where-Object { $_ -match 'lv_icon\.lvlibp' }).Count | Should -BeGreaterThan 0
            } finally {
                $null = Invoke-Runner -ScriptPath $script:revertScript -Arguments $revertArgs
                Remove-Item -Path $archiveDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
