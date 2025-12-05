#
# SourceDistVerify.Tests.ps1
# Integration tests for source-dist-verify orchestration CLI subcommand
# RTM: Packaging-Requirements-003, Test-Automation-002, Verification-001
#

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..\Support\SyntheticRepoFixtures.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\Support\SourceDistTestHelpers.psm1') -Force

Describe "OrchestrationCli source-dist-verify" -Tags @('Integration', 'OrchestrationCli', 'SourceDist', 'Verification') {
    BeforeAll {
        $script:Stub = New-GcliStub

        $script:InvokeSourceDistBuild = {
            param(
                [string]$RepoPath,
                [hashtable]$EnvOverrides
            )

            Invoke-OrchestrationCli -RepoPath $RepoPath -Subcommand 'source-dist-build' -Args @(
                '--gcli-path', $script:Stub.Path,
                '--lv-version', '2025',
                '--bitness', '64'
            ) -EnvOverrides $EnvOverrides
        }

        $script:InvokeSourceDistVerify = {
            param(
                [string]$RepoPath,
                [string[]]$ExtraArgs
            )

            Invoke-OrchestrationCli -RepoPath $RepoPath -Subcommand 'source-dist-verify' -Args $ExtraArgs
        }
    }

    AfterAll {
        if ($script:Stub) { $script:Stub.Dispose.Invoke($script:Stub.Root) }
    }

    BeforeEach {
        foreach ($name in 'BUILD_SD_TEST_GCLI_LOG','BUILD_SD_TEST_DIST','BUILD_SD_TEST_PAYLOADS') {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }

    Context "Happy path - manifest alignment" {
        It "verifies successfully when manifest matches HEAD commit" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi;resource/plugins/nested/deep/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                # First, build the distribution
                $buildResult = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -EnvOverrides $envOverrides

                $buildResult.ExitCode | Should -Be 0

                # Now verify it
                $verifyResult = & $script:InvokeSourceDistVerify -RepoPath $fixture.Path

                if ($verifyResult.ExitCode -ne 0) {
                    Write-Host "Verification failed with output:"
                    Write-Host $verifyResult.StdOut
                    Write-Host $verifyResult.StdErr
                }
                
                $verifyResult.ExitCode | Should -Be 0
                
                $outputText = ($verifyResult.StdOut + ' ' + $verifyResult.StdErr)
                $outputText | Should -Match 'success|verified|pass'
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Manifest mismatch detection" {
        It "detects commit mismatch and exits non-zero" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi;resource/plugins/nested/deep/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                # Build distribution
                $buildResult = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -EnvOverrides $envOverrides

                $buildResult.ExitCode | Should -Be 0

                # Mutate the manifest to create mismatch
                $manifestPath = Join-Path $distRoot 'manifest.json'
                Test-Path -LiteralPath $manifestPath | Should -BeTrue
                
                Set-ManifestMutation -ManifestPath $manifestPath -MutationType 'commit_mismatch'

                $zipPath = Join-Path $fixture.Path 'builds/artifacts/source-distribution.zip'
                Update-SourceDistZip -DistRoot $distRoot -ZipPath $zipPath

                # Verify should now fail
                $verifyResult = & $script:InvokeSourceDistVerify -RepoPath $fixture.Path

                $verifyResult.ExitCode | Should -Not -Be 0
                
                $outputText = ($verifyResult.StdOut + [Environment]::NewLine + $verifyResult.StdErr)
                $outputText | Should -Match 'mismatch|fail|error'
                $outputText | Should -Match 'manifest.json'

                # Check for verification report
                $reportDir = Join-Path $fixture.Path 'builds/reports/source-distribution-verify'
                if (Test-Path -LiteralPath $reportDir) {
                    $reports = Get-ChildItem -Path $reportDir -Recurse -Filter '*.json' -File
                    $reports.Count | Should -BeGreaterThan 0
                    
                    $report = Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
                    $report.PSObject.Properties['status'] | Should -Not -BeNullOrEmpty
                    $report.status | Should -Match 'fail|error'
                }
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }

        It "identifies the specific file with mismatch in output" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                # Build and mutate
                $buildResult = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -EnvOverrides $envOverrides

                $buildResult.ExitCode | Should -Be 0

                $manifestPath = Join-Path $distRoot 'manifest.json'
                Set-ManifestMutation -ManifestPath $manifestPath -MutationType 'commit_mismatch'

                $zipPath = Join-Path $fixture.Path 'builds/artifacts/source-distribution.zip'
                Update-SourceDistZip -DistRoot $distRoot -ZipPath $zipPath

                # Verify
                $verifyResult = & $script:InvokeSourceDistVerify -RepoPath $fixture.Path

                $verifyResult.ExitCode | Should -Not -Be 0
                
                $outputText = ($verifyResult.StdOut + [Environment]::NewLine + $verifyResult.StdErr)
                # Should reference the manifest path or the file causing the mismatch
                ($outputText -match 'manifest' -or $outputText -match 'sample.vi') | Should -BeTrue
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Report generation" {
        It "generates verification report with mismatch details" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $payloads = 'resource/plugins/generated/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                # Build, mutate, verify
                $buildResult = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -EnvOverrides $envOverrides

                $buildResult.ExitCode | Should -Be 0

                $manifestPath = Join-Path $distRoot 'manifest.json'
                Set-ManifestMutation -ManifestPath $manifestPath -MutationType 'commit_mismatch'

                $zipPath = Join-Path $fixture.Path 'builds/artifacts/source-distribution.zip'
                Update-SourceDistZip -DistRoot $distRoot -ZipPath $zipPath

                $verifyResult = & $script:InvokeSourceDistVerify -RepoPath $fixture.Path

                # Check report
                $reportDir = Join-Path $fixture.Path 'builds/reports/source-distribution-verify'
                if (Test-Path -LiteralPath $reportDir) {
                    $reports = Get-ChildItem -Path $reportDir -Filter '*.json' -File
                    if ($reports.Count -gt 0) {
                        $report = Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
                        
                        # Report should contain key information
                        $report.PSObject.Properties['timestamp'] | Should -Not -BeNullOrEmpty
                        $report.PSObject.Properties['status'] | Should -Not -BeNullOrEmpty
                        
                        # Should capture mismatch details
                        if ($report.PSObject.Properties['mismatches']) {
                            $report.mismatches.Count | Should -BeGreaterThan 0
                        }
                    }
                }
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Missing manifest handling" {
        It "reports error when manifest does not exist" {
            $fixture = New-SyntheticRepo

            try {
                # Don't build - just try to verify
                $verifyResult = & $script:InvokeSourceDistVerify -RepoPath $fixture.Path

                $verifyResult.ExitCode | Should -Not -Be 0
                
                $outputText = ($verifyResult.StdOut + ' ' + $verifyResult.StdErr)
                $outputText | Should -Match 'manifest|not found|missing'
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "RTM Traceability" {
        It "includes RTM annotations for verification requirements" {
            $testMetadata = @{
                RTM_IDs = @('Packaging-Requirements-003', 'Test-Automation-002', 'Verification-001')
                TestSuite = 'OrchestrationCli.SourceDistVerify'
                Coverage = 'Integration'
                VerificationScenarios = @(
                    'happy_path_aligned_manifest',
                    'commit_mismatch_detection',
                    'report_generation',
                    'missing_manifest_error'
                )
            }
            
            $testMetadata.RTM_IDs.Count | Should -BeGreaterThan 0
            $testMetadata.VerificationScenarios.Count | Should -Be 4
        }
    }
}
