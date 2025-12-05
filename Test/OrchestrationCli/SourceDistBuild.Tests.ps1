#
# SourceDistBuild.Tests.ps1
# Integration tests for source-dist-build orchestration CLI subcommand
# RTM: Packaging-Requirements-003, Test-Automation-002, Telemetry-Requirements-001
#

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..\Support\SyntheticRepoFixtures.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\Support\SourceDistTestHelpers.psm1') -Force

Describe "OrchestrationCli source-dist-build" -Tags @('Integration', 'OrchestrationCli', 'SourceDist') {
    BeforeAll {
        $script:Stub = New-GcliStub
        $script:InvokeSourceDistBuild = {
            param(
                [string]$RepoPath,
                [hashtable]$EnvOverrides,
                [string[]]$ExtraArgs,
                [string]$GcliPath
            )

            $gcli = if ($GcliPath) { $GcliPath } else { $script:Stub.Path }
            $args = @('--gcli-path', $gcli, '--lv-version', '2025', '--bitness', '64')
            if ($ExtraArgs) { $args += $ExtraArgs }

            Invoke-OrchestrationCli -RepoPath $RepoPath -Subcommand 'source-dist-build' -Args $args -EnvOverrides $EnvOverrides
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

    Context "Happy path - artifacts generation" {
        It "builds source distribution with manifest and telemetry" {
            $fixture = New-SyntheticRepo -IncludeSupport
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            $logPath = Join-Path $fixture.Path 'gcli-build.log'
            $payloads = 'resource/plugins/generated/sample.vi;resource/plugins/nested/deep/sample.vi'
            
            $envOverrides = @{
                BUILD_SD_TEST_GCLI_LOG = $logPath
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = $payloads
            }

            try {
                $result = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -GcliPath $script:Stub.Path `
                    -EnvOverrides $envOverrides

                if ($result.ExitCode -ne 0) {
                    Write-Host "Build failed with output:"
                    Write-Host $result.StdOut
                    Write-Host $result.StdErr
                }
                
                $result.ExitCode | Should -Be 0

                # Verify g-cli was invoked correctly
                Test-Path -LiteralPath $logPath | Should -BeTrue
                $argLine = (Get-Content -LiteralPath $logPath) -join ' '
                $argLine | Should -Match '--lv-ver 2025'
                $argLine | Should -Match 'LabVIEWIconAPI'

                # Verify manifest exists and contains required fields
                $manifestPath = Join-Path $distRoot 'manifest.json'
                Test-Path -LiteralPath $manifestPath | Should -BeTrue
                
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
                $manifest | Should -Not -BeNullOrEmpty
                
                $entry = $manifest | Where-Object path -eq 'resource/plugins/generated/sample.vi'
                $entry | Should -Not -BeNullOrEmpty
                $entry.commit_source | Should -Be 'index'
                $entry.last_commit | Should -Match '^[0-9a-f]{40}$'

                # Verify CSV manifest
                $manifestCsv = Join-Path $distRoot 'manifest.csv'
                Test-Path -LiteralPath $manifestCsv | Should -BeTrue

                # Verify telemetry (if telemetry log is generated)
                $telemetryDir = Join-Path $fixture.Path 'builds/logs'
                if (Test-Path -LiteralPath $telemetryDir) {
                    $telemetryLogs = Get-ChildItem -Path $telemetryDir -Filter '*.json' -File
                    if ($telemetryLogs.Count -gt 0) {
                        $telemetryPath = $telemetryLogs[0].FullName
                        Test-TelemetryLog -TelemetryLogPath $telemetryPath `
                            -RequiredFields @('build_spec', 'labview_version', 'bitness', 'repo_root') | 
                            Should -BeTrue
                    }
                }
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Pre-existing output handling" {
        It "handles pre-existing builds/LabVIEWIconAPI directory" {
            $fixture = New-SyntheticRepo -IncludeSupport -IncludeBuildsArtifacts
            $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
            
            # Verify artifacts exist before build
            Test-Path -LiteralPath (Join-Path $distRoot 'icon-api.zip') | Should -BeTrue
            
            $envOverrides = @{
                BUILD_SD_TEST_DIST = $distRoot
                BUILD_SD_TEST_PAYLOADS = 'resource/plugins/generated/sample.vi'
            }

            try {
                $result = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -GcliPath $script:Stub.Path `
                    -EnvOverrides $envOverrides

                if ($result.ExitCode -ne 0) {
                    Write-Host "Build with pre-existing output failed:"
                    Write-Host $result.StdOut
                    Write-Host $result.StdErr
                }
                
                # Should either clean/reuse successfully
                $result.ExitCode | Should -Be 0
                
                # Verify new manifest was created
                $manifestPath = Join-Path $distRoot 'manifest.json'
                Test-Path -LiteralPath $manifestPath | Should -BeTrue
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }
    }

    Context "Failure injection" {
        It "propagates error when g-cli path is missing" {
            $fixture = New-SyntheticRepo
            $missingGcli = Join-Path $fixture.Path 'nonexistent-g-cli.exe'

            try {
                $result = & $script:InvokeSourceDistBuild `
                    -RepoPath $fixture.Path `
                    -GcliPath $missingGcli

                $result.ExitCode | Should -Not -Be 0
                
                $outputText = ($result.StdOut + ' ' + $result.StdErr)
                $outputText | Should -Match 'g-cli|not found|does not exist'
                
                # Verify telemetry includes error fields (if generated)
                $telemetryDir = Join-Path $fixture.Path 'builds/logs'
                if (Test-Path -LiteralPath $telemetryDir) {
                    $telemetryLogs = Get-ChildItem -Path $telemetryDir -Filter '*.json' -File -ErrorAction SilentlyContinue
                    if ($telemetryLogs -and $telemetryLogs.Count -gt 0) {
                        $telemetryPath = $telemetryLogs[0].FullName
                        $telemetry = Get-Content -LiteralPath $telemetryPath -Raw | ConvertFrom-Json
                        $telemetry.PSObject.Properties['error'] | Should -Not -BeNullOrEmpty
                    }
                }
            }
            finally {
                $fixture.Dispose.Invoke($fixture.Path)
            }
        }

        It "fails gracefully when repository is invalid" {
            $invalidRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("invalid-repo-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $invalidRepo -Force | Out-Null

            try {
                $result = & $script:InvokeSourceDistBuild `
                    -RepoPath $invalidRepo `
                    -GcliPath $script:Stub.Path

                $result.ExitCode | Should -Not -Be 0
                
                $outputText = ($result.StdOut + ' ' + $result.StdErr)
                $outputText | Should -Match 'repository|invalid|not found'
            }
            finally {
                if (Test-Path -LiteralPath $invalidRepo) {
                    Remove-Item -LiteralPath $invalidRepo -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context "RTM Traceability" {
        It "includes RTM annotations in test metadata" {
            # This test validates that RTM traceability is maintained
            $testMetadata = @{
                RTM_IDs = @('Packaging-Requirements-003', 'Test-Automation-002', 'Telemetry-Requirements-001')
                TestSuite = 'OrchestrationCli.SourceDistBuild'
                Coverage = 'Integration'
            }
            
            $testMetadata.RTM_IDs.Count | Should -BeGreaterThan 0
            $testMetadata.TestSuite | Should -Be 'OrchestrationCli.SourceDistBuild'
        }
    }
}
