$ErrorActionPreference = 'Stop'

Describe 'Build lvlibp (dev mode, no LabVIEW) integration' {
    BeforeAll {
        $script:skipAll = $false
        $script:skipReason = ''
        $script:labviewVersion = $null
        $script:labviewBitness = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_BITNESS)) { '64' } else { $env:LABVIEW_BITNESS }
        $script:connectTimeoutMs = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_CONNECT_TIMEOUT_MS)) { '120000' } else { $env:LABVIEW_CONNECT_TIMEOUT_MS }
        $script:bitnessesToTest = @()
        $script:runDevModeTests = $false
        $script:versionInfo = $null

        if (-not [string]::IsNullOrWhiteSpace($env:RUN_DEV_MODE_TESTS)) {
            $flag = $env:RUN_DEV_MODE_TESTS.Trim().ToLowerInvariant()
            $script:runDevModeTests = @('1', 'true', 'yes', 'y') -contains $flag
        }

        function script:Get-LocalVersionInfo {
            param(
                [string]$RepoRoot
            )

            Push-Location -Path $RepoRoot
            try {
                $latestRaw = git describe --tags --abbrev=0 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $latestRaw = ''
                    $global:LASTEXITCODE = 0
                }

                if ([string]::IsNullOrWhiteSpace($latestRaw)) {
                    $maj = 0
                    $min = 1
                    $pat = 0
                } else {
                    $latest = $latestRaw.Trim().TrimStart('v') -replace '-build.*'
                    $parts = $latest.Split('.')
                    $maj = [int]$parts[0]
                    $min = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }
                    $pat = if ($parts.Length -gt 2) { [int]$parts[2] } else { 0 }
                }

                $build = [int](git rev-list --count HEAD)
                $commit = (git rev-parse HEAD).Trim()

                return [pscustomobject]@{
                    Major  = $maj
                    Minor  = $min
                    Patch  = $pat
                    Build  = $build
                    Commit = $commit
                }
            } catch {
                return [pscustomobject]@{
                    Major  = 0
                    Minor  = 1
                    Patch  = 0
                    Build  = 0
                    Commit = 'local'
                }
            } finally {
                Pop-Location
            }
        }

        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:stageModule = Join-Path $script:repoRoot 'Tooling\support\LabVIEWStage.ps1'
        $script:buildScript = Join-Path $script:repoRoot '.github\actions\build-lvlibp\Build_lvlibp.ps1'

        if (-not (Test-Path -Path $script:stageModule)) {
            $script:skipAll = $true
            $script:skipReason = "LabVIEWStage.ps1 not found at $script:stageModule"
            return
        }
        . $script:stageModule

        $versionInput = if ([string]::IsNullOrWhiteSpace($env:LABVIEW_VERSION)) { '' } else { $env:LABVIEW_VERSION }
        $script:labviewVersion = Resolve-LabVIEWVersion -VersionInput $versionInput -RepoRoot $script:repoRoot

        if ([string]::IsNullOrWhiteSpace($script:labviewVersion)) {
            $script:labviewVersion = '2021'
        }

        if (-not $script:runDevModeTests) {
            $script:skipAll = $true
            $script:skipReason = 'Set RUN_DEV_MODE_TESTS=1 to enable this integration test.'
            return
        }

        if (-not (Test-Path -Path $script:buildScript)) {
            $script:skipAll = $true
            $script:skipReason = "Build_lvlibp.ps1 not found at $script:buildScript"
            return
        }

        if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
            $script:skipAll = $true
            $script:skipReason = 'g-cli not found in PATH.'
            return
        }

        $script:versionInfo = Get-LocalVersionInfo -RepoRoot $script:repoRoot

        $bitnessCandidates = Resolve-BitnessList -Bitnesses $null -FallbackInput $script:labviewBitness
        foreach ($bitness in $bitnessCandidates) {
            if (-not (Get-LabVIEWInstallRoot -Version $script:labviewVersion -Bitness $bitness)) {
                continue
            }
            $script:bitnessesToTest += $bitness
        }

        if (-not $script:bitnessesToTest -or $script:bitnessesToTest.Count -eq 0) {
            $script:skipAll = $true
            $script:skipReason = "No LabVIEW $script:labviewVersion installs available for requested bitness."
            return
        }
    }

    It 'builds lvlibp in dev mode' {
        if ($script:skipAll) {
            Set-ItResult -Skipped -Because $script:skipReason
            return
        }

        $results = Invoke-LabVIEWStage `
            -StageName 'build-lvlibp' `
            -RepoRoot $script:repoRoot `
            -LabVIEWVersion $script:labviewVersion `
            -Bitnesses $script:bitnessesToTest `
            -ConnectTimeoutMs ([int]$script:connectTimeoutMs) `
            -DevModeNoLabVIEW `
            -Action {
                param($context)

                $pluginsDir = Join-Path $context.RepoRoot 'resource\plugins'
                $currentFile = Join-Path $pluginsDir 'lv_icon.lvlibp'
                $targetFile = if ($context.Bitness -eq '32') {
                    Join-Path $pluginsDir 'lv_icon_x86.lvlibp'
                } else {
                    Join-Path $pluginsDir 'lv_icon_x64.lvlibp'
                }

                if (Test-Path -Path $currentFile) {
                    Remove-Item -Path $currentFile -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path -Path $targetFile) {
                    Remove-Item -Path $targetFile -Force -ErrorAction SilentlyContinue
                }

                $buildArgs = @(
                    '-LabVIEWVersion', $context.LabVIEWVersion,
                    '-SupportedBitness', $context.Bitness,
                    '-RepoRoot', $context.RepoRoot,
                    '-Major', $script:versionInfo.Major,
                    '-Minor', $script:versionInfo.Minor,
                    '-Patch', $script:versionInfo.Patch,
                    '-Build', $script:versionInfo.Build,
                    '-Commit', $script:versionInfo.Commit,
                    '-ConnectTimeoutMs', $context.ConnectTimeoutMs
                )

                $run = Invoke-LabVIEWScript -ScriptPath $script:buildScript -Arguments $buildArgs
                if ($run.ExitCode -ne 0) {
                    return $run
                }

                if (-not (Test-Path -Path $currentFile)) {
                    throw "lvlibp output not found at $currentFile"
                }

                Move-Item -Path $currentFile -Destination $targetFile -Force

                if (-not (Test-Path -Path $targetFile)) {
                    throw "lvlibp output not moved to $targetFile"
                }

                return [pscustomobject]@{
                    ExitCode    = 0
                    OutputLines = $run.OutputLines
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
    }
}
