# Shared helpers for Source Distribution integration tests
# ASCII only per editing constraints

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CscPath {
    $frameworkSegments = @('Microsoft.NET\Framework64','Microsoft.NET\Framework')
    foreach ($segment in $frameworkSegments) {
        if (-not $env:WINDIR) { continue }
        $root = [System.IO.Path]::Combine($env:WINDIR, $segment)
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $versions = Get-ChildItem -Path $root -Directory -Filter 'v*' | Sort-Object Name -Descending
        foreach ($versionDir in $versions) {
            $probe = Join-Path $versionDir.FullName 'csc.exe'
            if (Test-Path -LiteralPath $probe -PathType Leaf) {
                return $probe
            }
        }
    }
    throw 'Unable to locate csc.exe under %WINDIR%'
}

function New-GcliStub {
    param(
        [string]$Root
    )
    if (-not $Root) {
        $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("gcli-stub-" + [guid]::NewGuid())
    }
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $stubExe = Join-Path $Root 'g-cli.exe'
    $sourcePath = Join-Path $Root 'gcli_stub.cs'
    $code = @'
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
            if (!string.IsNullOrEmpty(logDir)) Directory.CreateDirectory(logDir);
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
                    if (trimmed.Length == 0) continue;
                    var normalized = trimmed.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
                    var destination = Path.Combine(distRoot, normalized);
                    var dir = Path.GetDirectoryName(destination);
                    if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                    File.WriteAllText(destination, "payload::" + trimmed);
                }
            }
        }

        return 0;
    }
}
'@
    $code | Set-Content -LiteralPath $sourcePath -Encoding utf8
    $csc = Get-CscPath
    & $csc /nologo /target:exe /out:$stubExe /platform:anycpu $sourcePath | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $stubExe -PathType Leaf)) {
        throw "Failed to compile g-cli stub (exit $LASTEXITCODE)"
    }

    return [pscustomobject]@{
        Path = $stubExe
        Root = $Root
        Dispose = { param($r) if ($r -and (Test-Path -LiteralPath $r)) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue } }
    }
}

function New-SourceDistFixture {
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
    '<Project/>' | Set-Content -LiteralPath $projectPath -Encoding utf8

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
            generator = 'SourceDistTestHelpers'
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

function Invoke-OrchestrationCli {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Subcommand,
        [string[]]$Args,
        [hashtable]$EnvOverrides,
        [int]$TimeoutSeconds = 0
    )

    $projCandidates = @()
    $projCandidates += Join-Path $RepoPath 'Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj'
    $workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $projCandidates += Join-Path $workspaceRoot.Path 'Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj'

    $proj = $projCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $proj) {
        throw "OrchestrationCli project not found. Probed: $($projCandidates -join '; ')"
    }

    $envSnapshot = @{}
    if ($EnvOverrides) {
        foreach ($key in $EnvOverrides.Keys) {
            $envSnapshot[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $EnvOverrides[$key], 'Process')
        }
    }

    try {
        $cliArgs = @(
            'run','--project', $proj, '--', $Subcommand,
            '--repo', $RepoPath,
            '--bitness', '64'
        )
        if ($TimeoutSeconds -gt 0) {
            $cliArgs += @('--timeout-sec', "$TimeoutSeconds")
        }
        if ($Args) { $cliArgs += $Args }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'dotnet'
        foreach ($a in $cliArgs) { $psi.ArgumentList.Add($a) }
        $psi.WorkingDirectory = $RepoPath
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
    }
    finally {
        if ($EnvOverrides) {
            foreach ($key in $EnvOverrides.Keys) {
                [Environment]::SetEnvironmentVariable($key, $envSnapshot[$key], 'Process')
            }
        }
    }
}

function Update-SourceDistZip {
    param(
        [Parameter(Mandatory)][string]$DistRoot,
        [Parameter(Mandatory)][string]$ZipPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($DistRoot, $ZipPath)
}

Export-ModuleMember -Function Get-CscPath, New-GcliStub, New-SourceDistFixture, Invoke-OrchestrationCli, Update-SourceDistZip
