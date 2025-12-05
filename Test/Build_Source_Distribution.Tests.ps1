
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:NewBuildSdFixture = $null
$script:InvokeBuildSourceDistribution = $null

Describe "Build_Source_Distribution.ps1" {
    BeforeAll {
        $script:Subject = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\build-source-distribution\Build_Source_Distribution.ps1')).Path
        $script:PwshPath = (Get-Command pwsh).Source
        $script:StubRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gcli-stub-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:StubRoot -Force | Out-Null

        $stubExe = Join-Path $script:StubRoot 'g-cli.exe'
        $sourcePath = Join-Path $script:StubRoot 'gcli_stub.cs'
        $stubCode = @"
using System;
using System.IO;

class Program
{
    static int Main(string[] args)
    {
        var logPath = Environment.GetEnvironmentVariable("BUILD_SD_TEST_GCLI_LOG");
        if (!string.IsNullOrEmpty(logPath))
        {
            var logDir = Path.GetDirectoryName(logPath);
            if (!string.IsNullOrEmpty(logDir))
            {
                Directory.CreateDirectory(logDir);
            }
            File.WriteAllLines(logPath, args);
        }

        var distRoot = Environment.GetEnvironmentVariable("BUILD_SD_TEST_DIST");
        if (!string.IsNullOrEmpty(distRoot))
        {
            Directory.CreateDirectory(distRoot);
            var payloads = Environment.GetEnvironmentVariable("BUILD_SD_TEST_PAYLOADS");
            if (!string.IsNullOrEmpty(payloads))
            {
                var entries = payloads.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var entry in entries)
                {
                    var trimmed = entry.Trim();
                    if (trimmed.Length == 0) { continue; }
                    var normalized = trimmed.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
                    var destination = Path.Combine(distRoot, normalized);
                    var dir = Path.GetDirectoryName(destination);
                    if (!string.IsNullOrEmpty(dir))
                    {
                        Directory.CreateDirectory(dir);
                    }
                    File.WriteAllText(destination, "payload::" + trimmed);
                }
            }
        }

        return 0;
    }
}
"@
            $stubCode | Set-Content -LiteralPath $sourcePath -Encoding utf8

            $cscPath = $null
            $frameworkRoots = @()
            $frameworkSegments = @('Microsoft.NET\Framework64','Microsoft.NET\Framework')
            foreach ($segment in $frameworkSegments) {
                if ($env:WINDIR) {
                    $frameworkRoots += [System.IO.Path]::Combine($env:WINDIR, $segment)
                }
            }
            foreach ($root in $frameworkRoots) {
                if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
                $versions = Get-ChildItem -Path $root -Directory -Filter 'v*' | Sort-Object Name -Descending
                foreach ($versionDir in $versions) {
                    $probe = Join-Path $versionDir.FullName 'csc.exe'
                    if (Test-Path -LiteralPath $probe -PathType Leaf) {
                        $cscPath = $probe
                        break
                    }
                }
                if ($cscPath) { break }
            }
            if (-not $cscPath) {
                throw "Unable to locate csc.exe under $env:WINDIR\Microsoft.NET."
            }

            & $cscPath /nologo /target:exe /out:$stubExe /platform:anycpu $sourcePath | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to compile g-cli stub via csc.exe (exit $LASTEXITCODE)."
            }

            if (-not (Test-Path -LiteralPath $stubExe -PathType Leaf)) {
                throw "g-cli stub executable not found at $stubExe after compilation."
            }
            $script:StubExePath = $stubExe

        $script:NewBuildSdFixture = {
            param(
                [switch]$IncludeSupport
            )

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("buildsd-fixture-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            $iconApi = Join-Path $root 'vi.lib/LabVIEW Icon API'
            New-Item -ItemType Directory -Path $iconApi -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $iconApi 'icon.txt') -Value 'icon' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $iconApi 'icon-extra.txt') -Value 'icon2' -Encoding utf8

            $plugins = Join-Path $root 'resource/plugins'
            New-Item -ItemType Directory -Path $plugins -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $plugins 'seed.txt') -Value 'plugin' -Encoding utf8

            if ($IncludeSupport) {
                $configDir = Join-Path $root 'configs/vscode'
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $configDir 'task-schema.sample.json') -Value '{}' -Encoding utf8
                foreach ($file in 'vi-compare-run-request.sample.json','vi-compare-run-request.failure.json','vi-compare-run-request.disabled.json') {
                    $cfg = Join-Path $root "configs/$file"
                    New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
                    Set-Content -LiteralPath $cfg -Value '{}' -Encoding utf8
                }
                $viCompareDir = Join-Path $root 'scripts/vi-compare'
                New-Item -ItemType Directory -Path $viCompareDir -Force | Out-Null
                foreach ($file in 'run-vi-history-suite-sd.ps1','RunViCompareReplay.ps1') {
                    Set-Content -LiteralPath (Join-Path $viCompareDir $file) -Value 'param()' -Encoding utf8
                }
                $tooling = Join-Path $root 'Tooling'
                New-Item -ItemType Directory -Path $tooling -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $tooling 'readme.txt') -Value 'tooling' -Encoding utf8
            }

            $projectPath = Join-Path $root 'lv_icon_editor.lvproj'
            "<Project/>" | Set-Content -LiteralPath $projectPath -Encoding utf8

            $buildCache = Join-Path $root 'builds/cache'
            New-Item -ItemType Directory -Path $buildCache -Force | Out-Null

            git -C $root init | Out-Null
            git -C $root config user.name 'Test User'
            git -C $root config user.email 'tester@example.com'
            git -C $root add . | Out-Null
            git -C $root commit -m 'seed' | Out-Null
            $head = (git -C $root rev-parse HEAD).Trim()
            $date = (git -C $root show -s --format=%ai HEAD).Trim()

            $commitIndexPath = Join-Path $buildCache 'commit-index.json'
            $commitEntries = @(
                @{ path = 'resource/plugins/generated/sample.vi'; commit = $head; author = 'Test User'; date = $date; isContainer = $false }
                @{ path = 'resource/plugins/nested/deep/sample.vi'; commit = $head; author = 'Test User'; date = $date; isContainer = $false }
            )
            $commitIndexJson = @{
                entries = $commitEntries
                metadata = @{
                    generator = 'Build_Source_Distribution.Tests'
                    generated_at = (Get-Date).ToString('o')
                }
            } | ConvertTo-Json -Depth 5
            $commitIndexJson | Set-Content -LiteralPath $commitIndexPath -Encoding utf8

            return [pscustomobject]@{
                Path = $root
                CommitIndexPath = $commitIndexPath
                Dispose = { param($target) if ($target -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue } }
            }
        }

        $script:InvokeBuildSourceDistribution = {
            param(
                [string]$RepoPath,
                [string]$CommitIndexPath,
                [string[]]$ExtraArgs,
                [hashtable]$EnvOverrides
            )

            $envSnapshot = @{}
            if ($EnvOverrides) {
                foreach ($key in $EnvOverrides.Keys) {
                    $envSnapshot[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
                    [Environment]::SetEnvironmentVariable($key, $EnvOverrides[$key], 'Process')
                }
            }

            try {
                $cliArgs = @(
                    '-NoProfile',
                    '-NonInteractive',
                    '-File', $script:Subject,
                    '-RepositoryPath', $RepoPath,
                    '-Package_LabVIEW_Version', '2025',
                    '-SupportedBitness', '64',
                    '-CommitIndexPath', $CommitIndexPath,
                    '-SkipAssetIsolation'
                )
                if ($ExtraArgs) { $cliArgs += $ExtraArgs }
                $output = & $script:PwshPath @cliArgs 2>&1
                $code = $LASTEXITCODE
                return [pscustomobject]@{ ExitCode = $code; Output = $output }
            }
            finally {
                if ($EnvOverrides) {
                    foreach ($key in $EnvOverrides.Keys) {
                        [Environment]::SetEnvironmentVariable($key, $envSnapshot[$key], 'Process')
                    }
                }
            }
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:StubRoot) {
            Remove-Item -LiteralPath $script:StubRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    BeforeEach {
        foreach ($name in 'BUILD_SD_TEST_GCLI_LOG','BUILD_SD_TEST_DIST','BUILD_SD_TEST_PAYLOADS') {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }


    It "enforces the RepositoryPath parameter" {
        $result = & $script:PwshPath -NoProfile -NonInteractive -File $script:Subject 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($result -join ' ') | Should -Match 'RepositoryPath'
    }

    It "fails when g-cli is unavailable" {
        $fixture = & $script:NewBuildSdFixture
        try {
            $missingPath = Join-Path $fixture.Path 'missing-gcli.exe'
            $run = & $script:InvokeBuildSourceDistribution -RepoPath $fixture.Path -CommitIndexPath $fixture.CommitIndexPath -ExtraArgs @('-GcliPath', $missingPath)
            $run.ExitCode | Should -Not -Be 0
            ($run.Output -join ' ') | Should -Match 'g-cli is required'
        }
        finally {
            $fixture.Dispose.Invoke($fixture.Path)
        }
    }

    It "invokes g-cli with LabVIEWIconAPI and records manifest metadata" {
        $fixture = & $script:NewBuildSdFixture -IncludeSupport
        $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
        $logPath = Join-Path $fixture.Path 'gcli-args.log'
        $payloads = 'resource/plugins/generated/sample.vi;resource/plugins/nested/deep/sample.vi'
        $envOverrides = @{
            BUILD_SD_TEST_GCLI_LOG = $logPath
            BUILD_SD_TEST_DIST = $distRoot
            BUILD_SD_TEST_PAYLOADS = $payloads
        }

        try {
            $run = & $script:InvokeBuildSourceDistribution -RepoPath $fixture.Path -CommitIndexPath $fixture.CommitIndexPath -EnvOverrides $envOverrides -ExtraArgs @('-GcliPath', $script:StubExePath)
            if ($run.ExitCode -ne 0) {
                Write-Host ($run.Output -join [Environment]::NewLine)
            }
            $run.ExitCode | Should -Be 0

            Test-Path -LiteralPath $logPath | Should -BeTrue
            $argLine = (Get-Content -LiteralPath $logPath) -join ' '
            $argLine | Should -Match '--lv-ver 2025'
            $argLine | Should -Match '-b LabVIEWIconAPI'

            $manifestPath = Join-Path $distRoot 'manifest.json'
            $manifestCsv = Join-Path $distRoot 'manifest.csv'
            Test-Path -LiteralPath $manifestPath | Should -BeTrue
            Test-Path -LiteralPath $manifestCsv | Should -BeTrue
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            ($manifest | Where-Object path -eq 'resource/plugins/generated/sample.vi') | Should -Not -BeNullOrEmpty
            $entry = $manifest | Where-Object path -eq 'resource/plugins/generated/sample.vi'
            $entry.commit_source | Should -Be 'index'
            $entry.last_commit | Should -Match '^[0-9a-f]{40}$'
            ($manifest | Where-Object path -eq 'resource/plugins/nested/deep/sample.vi') | Should -Not -BeNullOrEmpty
        }
        finally {
            $fixture.Dispose.Invoke($fixture.Path)
        }
    }

    It "writes artifacts under an override output root" {
        $fixture = & $script:NewBuildSdFixture -IncludeSupport
        $overrideRoot = Join-Path $fixture.Path 'custom\sd-output'
        $logPath = Join-Path $fixture.Path 'gcli-args-override.log'
        $envOverrides = @{
            BUILD_SD_TEST_GCLI_LOG = $logPath
            BUILD_SD_TEST_DIST = $overrideRoot
            BUILD_SD_TEST_PAYLOADS = 'resource/plugins/generated/sample.vi'
        }

        try {
            $run = & $script:InvokeBuildSourceDistribution -RepoPath $fixture.Path -CommitIndexPath $fixture.CommitIndexPath -EnvOverrides $envOverrides -ExtraArgs @('-GcliPath', $script:StubExePath, '-OverrideOutputRoot', $overrideRoot)
            if ($run.ExitCode -ne 0) {
                Write-Host ($run.Output -join [Environment]::NewLine)
            }
            $run.ExitCode | Should -Be 0
            Test-Path -LiteralPath (Join-Path $overrideRoot 'manifest.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $fixture.Path 'builds/LabVIEWIconAPI') | Should -BeFalse
        }
        finally {
            $fixture.Dispose.Invoke($fixture.Path)
        }
    }

    It "emits empty manifests when the payload contains no files" {
        $fixture = & $script:NewBuildSdFixture
        $distRoot = Join-Path $fixture.Path 'builds/LabVIEWIconAPI'
        $envOverrides = @{
            BUILD_SD_TEST_DIST = $distRoot
        }

        try {
            $run = & $script:InvokeBuildSourceDistribution -RepoPath $fixture.Path -CommitIndexPath $fixture.CommitIndexPath -EnvOverrides $envOverrides -ExtraArgs @('-GcliPath', $script:StubExePath)
            if ($run.ExitCode -ne 0) {
                Write-Host ($run.Output -join [Environment]::NewLine)
            }
            $run.ExitCode | Should -Be 0
            $manifestPath = Join-Path $distRoot 'manifest.json'
            Test-Path -LiteralPath $manifestPath | Should -BeTrue
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.Count | Should -Be 0
            Test-Path -LiteralPath (Join-Path $distRoot 'manifest.csv') | Should -BeTrue
        }
        finally {
            $fixture.Dispose.Invoke($fixture.Path)
        }
    }
}
