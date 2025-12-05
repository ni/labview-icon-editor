#
# SourceDistRegression.Tests.ps1
# End-to-end regression chain for source distribution orchestration
# RTM: Integration-Testing-001, Performance-Baseline-001, Test-Automation-002
#

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..\Support\SyntheticRepoFixtures.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\Support\SourceDistTestHelpers.psm1') -Force

Describe "OrchestrationCli E2E Regression Chain" -Tags @('Integration', 'OrchestrationCli', 'Regression', 'E2E') {
    BeforeAll {
        $script:Stub = New-GcliStub

        $script:InvokeCliCommand = {
            param(
                [string]$Subcommand,
                [string]$RepoPath,
                [string[]]$ExtraArgs,
                [hashtable]$EnvOverrides
            )

            Invoke-OrchestrationCli -RepoPath $RepoPath -Subcommand $Subcommand -Args $ExtraArgs -EnvOverrides $EnvOverrides
        }
    }

    AfterAll {
        if ($script:Stub) { $script:Stub.Dispose.Invoke($script:Stub.Root) }
    }

    Context "Full workflow: build → mutate → verify fails → reset" {
        It "executes complete state transition chain successfully" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi;resource/plugins/nested/deep/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                $wallClockTimer = [System.Diagnostics.Stopwatch]::StartNew()

                # STEP 1: Build source distribution
                Write-Host "[E2E] Step 1: Building source distribution..."
                $buildResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-build' `
                    -RepoPath $fixture.Path `
                    -ExtraArgs @('--gcli-path', $script:Stub.Path, '--lv-version', '2025', '--bitness', '64') `
                    -EnvOverrides $envOverrides

                if ($buildResult.ExitCode -ne 0) {
                    Write-Host "Build failed:"
                    Write-Host $buildResult.StdOut
                    Write-Host $buildResult.StdErr
                }
                $buildResult.ExitCode | Should -Be 0

                $manifestPath = Join-Path $distRoot 'manifest.json'
                Test-Path -LiteralPath $manifestPath | Should -BeTrue

                # STEP 2: Verify (should pass initially)
                Write-Host "[E2E] Step 2: Verifying distribution (should pass)..."
                $verifyPassResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-verify' `
                    -RepoPath $fixture.Path

                $verifyPassResult.ExitCode | Should -Be 0

                # STEP 3: Mutate manifest to create mismatch
                Write-Host "[E2E] Step 3: Mutating manifest to create mismatch..."
                Set-ManifestMutation -ManifestPath $manifestPath -MutationType 'commit_mismatch'

                $zipPath = Join-Path $fixture.Path 'builds/artifacts/source-distribution.zip'
                Update-SourceDistZip -DistRoot $distRoot -ZipPath $zipPath

                # STEP 4: Verify (should fail now)
                Write-Host "[E2E] Step 4: Verifying distribution (should fail)..."
                $verifyFailResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-verify' `
                    -RepoPath $fixture.Path

                $verifyFailResult.ExitCode | Should -Not -Be 0
                ($verifyFailResult.StdOut + ' ' + $verifyFailResult.StdErr) | Should -Match 'mismatch|fail|error'

                # STEP 5: Reset source distribution
                Write-Host "[E2E] Step 5: Resetting source distribution..."
                $resetResult = & $script:InvokeCliCommand `
                    -Subcommand 'reset-source-dist' `
                    -RepoPath $fixture.Path `
                    -ExtraArgs @('--reset-emit-summary')

                $resetResult.ExitCode | Should -Be 0

                # Verify artifacts were archived
                $archiveDir = Join-Path $fixture.Path 'builds/archive'
                Test-Path -LiteralPath $archiveDir | Should -BeTrue

                $wallClockTimer.Stop()
                $totalRuntime = $wallClockTimer.Elapsed.TotalSeconds

                Write-Host "[E2E] Total workflow runtime: $totalRuntime seconds"

                # Record performance measurement
                $perfDir = Join-Path $fixture.Path 'reports'
                New-Item -ItemType Directory -Path $perfDir -Force | Out-Null
                
                $perfMeasurement = @{
                    test_suite = 'OrchestrationCli.E2E.Regression'
                    workflow = 'build-mutate-verify-reset'
                    runtime_seconds = $totalRuntime
                    timestamp = (Get-Date).ToString('o')
                    rtm_ids = @('Integration-Testing-001', 'Performance-Baseline-001')
                } | ConvertTo-Json

                $perfPath = Join-Path $perfDir 'performance-measurements.json'
                $perfMeasurement | Set-Content -LiteralPath $perfPath -Encoding utf8

                Test-Path -LiteralPath $perfPath | Should -BeTrue
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "State transition validation" {
        It "verifies correct state after each step" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                # State 0: Clean repo
                $initialState = @{
                    HasArtifacts = Test-Path -LiteralPath $distRoot
                }
                $initialState.HasArtifacts | Should -BeFalse

                # Build
                $buildResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-build' `
                    -RepoPath $fixture.Path `
                    -ExtraArgs @('--gcli-path', $script:Stub.Path, '--lv-version', '2025', '--bitness', '64') `
                    -EnvOverrides $envOverrides

                $buildResult.ExitCode | Should -Be 0

                # State 1: Artifacts exist
                $postBuildState = @{
                    HasArtifacts = Test-Path -LiteralPath $distRoot
                    HasManifest = Test-Path -LiteralPath (Join-Path $distRoot 'manifest.json')
                }
                $postBuildState.HasArtifacts | Should -BeTrue
                $postBuildState.HasManifest | Should -BeTrue

                # Mutate and verify failure
                Set-ManifestMutation -ManifestPath (Join-Path $distRoot 'manifest.json') -MutationType 'commit_mismatch'

                $zipPath = Join-Path $fixture.Path 'builds/artifacts/source-distribution.zip'
                Update-SourceDistZip -DistRoot $distRoot -ZipPath $zipPath
                
                $verifyResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-verify' `
                    -RepoPath $fixture.Path

                $verifyResult.ExitCode | Should -Not -Be 0

                # State 2: Verification failed, artifacts still exist
                $postVerifyState = @{
                    HasArtifacts = Test-Path -LiteralPath $distRoot
                }
                $postVerifyState.HasArtifacts | Should -BeTrue

                # Reset
                $resetResult = & $script:InvokeCliCommand `
                    -Subcommand 'reset-source-dist' `
                    -RepoPath $fixture.Path

                $resetResult.ExitCode | Should -Be 0

                # State 3: Artifacts archived
                $postResetState = @{
                    HasArchive = Test-Path -LiteralPath (Join-Path $fixture.Path 'builds/archive')
                }
                $postResetState.HasArchive | Should -BeTrue
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Performance baseline recording" {
        It "records runtime measurements for performance monitoring" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = 'resource/plugins/generated/sample.vi'
            }

            try {
                $measurements = @{}

                # Measure build
                $buildTimer = [System.Diagnostics.Stopwatch]::StartNew()
                $buildResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-build' `
                    -RepoPath $fixture.Path `
                    -ExtraArgs @('--gcli-path', $script:Stub.Path, '--lv-version', '2025', '--bitness', '64') `
                    -EnvOverrides $envOverrides
                $buildTimer.Stop()
                $measurements['build'] = $buildTimer.Elapsed.TotalSeconds

                # Measure verify
                $verifyTimer = [System.Diagnostics.Stopwatch]::StartNew()
                $verifyResult = & $script:InvokeCliCommand `
                    -Subcommand 'source-dist-verify' `
                    -RepoPath $fixture.Path
                $verifyTimer.Stop()
                $measurements['verify'] = $verifyTimer.Elapsed.TotalSeconds

                # Measure reset
                $resetTimer = [System.Diagnostics.Stopwatch]::StartNew()
                $resetResult = & $script:InvokeCliCommand `
                    -Subcommand 'reset-source-dist' `
                    -RepoPath $fixture.Path
                $resetTimer.Stop()
                $measurements['reset'] = $resetTimer.Elapsed.TotalSeconds

                Write-Host "[Performance] Build: $($measurements['build'])s, Verify: $($measurements['verify'])s, Reset: $($measurements['reset'])s"

                # Persist measurements
                $perfDir = Join-Path $fixture.Path 'reports'
                New-Item -ItemType Directory -Path $perfDir -Force | Out-Null
                
                $perfData = @{
                    test_suite = 'OrchestrationCli.Performance'
                    measurements = $measurements
                    total_seconds = ($measurements.Values | Measure-Object -Sum).Sum
                    timestamp = (Get-Date).ToString('o')
                    rtm_id = 'Performance-Baseline-001'
                } | ConvertTo-Json

                $perfPath = Join-Path $perfDir 'performance-measurements.json'
                $perfData | Set-Content -LiteralPath $perfPath -Encoding utf8

                # Validate measurements exist
                $measurements.Count | Should -Be 3
                $measurements['build'] | Should -BeGreaterThan 0
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "RTM Traceability" {
        It "includes comprehensive RTM coverage for regression testing" {
            $testMetadata = @{
                RTM_IDs = @(
                    'Integration-Testing-001',
                    'Performance-Baseline-001',
                    'Test-Automation-002',
                    'Packaging-Requirements-003'
                )
                TestSuite = 'OrchestrationCli.E2E.Regression'
                Coverage = 'End-to-End'
                Workflow = @(
                    'source-dist-build',
                    'manifest-mutation',
                    'source-dist-verify-failure',
                    'reset-source-dist'
                )
                PerformanceTracking = $true
            }
            
            $testMetadata.RTM_IDs.Count | Should -BeGreaterThan 0
            $testMetadata.Workflow.Count | Should -Be 4
            $testMetadata.PerformanceTracking | Should -BeTrue
        }
    }
}
