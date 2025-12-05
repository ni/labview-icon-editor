#
# SyntheticRepoFixtures.psm1
# Shared test helpers for creating synthetic git repositories with build artifacts
# RTM: Test-Framework-001, Test-Automation-002
#

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.SYNOPSIS
Creates a g-cli stub executable for testing.

.DESCRIPTION
Compiles a minimal C# stub that mimics g-cli behavior for integration tests.
The stub reads environment variables to control output behavior.

.PARAMETER StubRoot
Root directory where stub source and executable will be created.

.OUTPUTS
Path to the compiled g-cli.exe stub.

.NOTES
RTM: Test-Framework-001
Requires Windows csc.exe from .NET Framework.
#>
function New-GcliStub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StubRoot
    )

    New-Item -ItemType Directory -Path $StubRoot -Force | Out-Null

    $stubExe = Join-Path $StubRoot 'g-cli.exe'
    $sourcePath = Join-Path $StubRoot 'gcli_stub.cs'
    
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
        throw "Unable to locate csc.exe under $env:WINDIR\Microsoft.NET. This is a known Windows-specific dependency (see technical debt register)."
    }

    & $cscPath /nologo /target:exe /out:$stubExe /platform:anycpu $sourcePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to compile g-cli stub via csc.exe (exit $LASTEXITCODE)."
    }

    if (-not (Test-Path -LiteralPath $stubExe -PathType Leaf)) {
        throw "g-cli stub executable not found at $stubExe after compilation."
    }

    return $stubExe
}

<#
.SYNOPSIS
Creates a synthetic git repository with LabVIEW project structure.

.DESCRIPTION
Generates a temporary git repository with standard LabVIEW Icon Editor structure,
including vi.lib content, resource plugins, and commit index.

.PARAMETER IncludeSupport
Include additional support files like configs, scripts, and Tooling directory.

.PARAMETER IncludeBuildsArtifacts
Pre-populate builds directory with fake artifacts for testing reset scenarios.

.OUTPUTS
PSCustomObject with Path, CommitIndexPath, HeadCommit, and Dispose properties.

.NOTES
RTM: Test-Framework-001, Packaging-Requirements-003
#>
function New-SyntheticRepo {
    [CmdletBinding()]
    param(
        [switch]$IncludeSupport,
        [switch]$IncludeBuildsArtifacts
    )

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("synth-repo-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # LabVIEW Icon API structure
    $iconApi = Join-Path $root 'vi.lib/LabVIEW Icon API'
    New-Item -ItemType Directory -Path $iconApi -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $iconApi 'icon.txt') -Value 'icon' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $iconApi 'icon-extra.txt') -Value 'icon2' -Encoding utf8

    # Resource plugins
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

    # Minimal reset script for source distribution to support orchestration tests
    $resetScriptDir = Join-Path $root 'scripts/build-source-distribution'
    New-Item -ItemType Directory -Path $resetScriptDir -Force | Out-Null
    $resetScriptPath = Join-Path $resetScriptDir 'Reset-SourceDistributionWorkspace.ps1'
    @'
param(
    [string]$RepoPath,
    [switch]$ArchiveExisting,
    [switch]$SkipCleanup,
    [switch]$RunCommitIndex,
    [switch]$RunFullBuild,
    [string]$Runner,
    [switch]$DryRun,
    [switch]$EmitSummaryToConsole,
    [string]$SummaryJsonPath,
    [string[]]$AdditionalPaths
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$buildsDir = Join-Path $RepoPath 'builds/LabVIEWIconAPI'
$archiveRoot = Join-Path $RepoPath 'builds/archive'
$reportsRoot = Join-Path $RepoPath 'builds/reports'
$logsRoot = Join-Path $RepoPath 'builds/logs'
$summaryPath = if ($SummaryJsonPath) { $SummaryJsonPath } else { Join-Path $RepoPath 'builds/reset-summary.json' }

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null

$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$dest = Join-Path $archiveRoot $timestamp
New-Item -ItemType Directory -Path $dest -Force | Out-Null

function Move-IfExists {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (Test-Path -LiteralPath $Source) {
        $destDir = Split-Path -Parent $Destination
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Move-Item -LiteralPath $Source -Destination $Destination -Force
        return $true
    }
    return $false
}

$archived = @()
$movedBuilds = Move-IfExists -Source $buildsDir -Destination (Join-Path $dest 'LabVIEWIconAPI')
if ($movedBuilds) {
    $archived += Get-ChildItem -Path (Join-Path $dest 'LabVIEWIconAPI') -Recurse -File -ErrorAction SilentlyContinue
}

if ($AdditionalPaths) {
    foreach ($extra in $AdditionalPaths) {
        if (-not $extra) { continue }
        $candidate = Join-Path $RepoPath $extra
        $target = Join-Path $dest (Split-Path -Leaf $candidate)
        if (Move-IfExists -Source $candidate -Destination $target) {
            $archived += Get-ChildItem -Path $target -Recurse -File -ErrorAction SilentlyContinue
        }
    }
}

$archivedCount = ($archived | Measure-Object).Count
$remainingCount = 0
if (Test-Path -LiteralPath $buildsDir) {
    $remainingCount = (Get-ChildItem -Path $buildsDir -Recurse -File -ErrorAction SilentlyContinue).Count
}

$summary = [pscustomobject]@{
    archived_count = $archivedCount
    remaining_count = $remainingCount
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
}

if ($EmitSummaryToConsole) {
    $summary | ConvertTo-Json -Depth 5 | Write-Output
}
if ($summaryPath) {
    $summaryDir = Split-Path -Parent $summaryPath
    if ($summaryDir -and -not (Test-Path -LiteralPath $summaryDir)) {
        New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8
}

$logPath = Join-Path $logsRoot 'reset-source-dist.log'
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $logPath -Encoding utf8

Write-Host "[reset] archived to $dest"
exit 0
'@ | Set-Content -LiteralPath $resetScriptPath -Encoding utf8

    # Project file
    $projectPath = Join-Path $root 'lv_icon_editor.lvproj'
    "<Project/>" | Set-Content -LiteralPath $projectPath -Encoding utf8

    # Builds directory structure
    $buildCache = Join-Path $root 'builds/cache'
    New-Item -ItemType Directory -Path $buildCache -Force | Out-Null

    # Initialize git repository
    git -C $root init | Out-Null
    git -C $root config user.name 'Test User'
    git -C $root config user.email 'tester@example.com'
    git -C $root add . | Out-Null
    git -C $root commit -m 'seed' | Out-Null
    $head = (git -C $root rev-parse HEAD).Trim()
    $date = (git -C $root show -s --format=%ai HEAD).Trim()

    # Create commit index
    $commitIndexPath = Join-Path $buildCache 'commit-index.json'
    $commitEntries = @(
        @{ path = 'resource/plugins/generated/sample.vi'; commit = $head; author = 'Test User'; date = $date; isContainer = $false }
        @{ path = 'resource/plugins/nested/deep/sample.vi'; commit = $head; author = 'Test User'; date = $date; isContainer = $false }
    )
    $commitIndexJson = @{
        entries = $commitEntries
        metadata = @{
            generator = 'SyntheticRepoFixtures'
            generated_at = (Get-Date).ToString('o')
        }
    } | ConvertTo-Json -Depth 5
    $commitIndexJson | Set-Content -LiteralPath $commitIndexPath -Encoding utf8

    # Optionally add pre-existing build artifacts
    if ($IncludeBuildsArtifacts) {
        $artifactDir = Join-Path $root 'builds/LabVIEWIconAPI'
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $artifactDir 'icon-api.zip') -Value 'fake-zip-content' -Encoding utf8
        
        $manifestContent = @{
            build_spec = 'source-dist'
            labview_version = '2025'
            bitness = '64'
            last_commit = $head
            timestamp = (Get-Date).ToString('o')
        } | ConvertTo-Json
        Set-Content -LiteralPath (Join-Path $artifactDir 'manifest.json') -Value $manifestContent -Encoding utf8
    }

    return [pscustomobject]@{
        Path = $root
        CommitIndexPath = $commitIndexPath
        HeadCommit = $head
        Dispose = { 
            param($target) 
            if ($target -and (Test-Path -LiteralPath $target)) { 
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue 
            } 
        }
    }
}

<#
.SYNOPSIS
Validates telemetry log output structure.

.DESCRIPTION
Checks that structured telemetry logs contain required fields for compliance.

.PARAMETER TelemetryLogPath
Path to the JSON telemetry log file.

.PARAMETER RequiredFields
Array of field names that must exist in the telemetry log.

.OUTPUTS
Boolean indicating whether all required fields are present.

.NOTES
RTM: Telemetry-Requirements-001
#>
function Test-TelemetryLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TelemetryLogPath,
        
        [Parameter(Mandatory)]
        [string[]]$RequiredFields
    )

    if (-not (Test-Path -LiteralPath $TelemetryLogPath)) {
        Write-Warning "Telemetry log not found: $TelemetryLogPath"
        return $false
    }

    $content = Get-Content -LiteralPath $TelemetryLogPath -Raw | ConvertFrom-Json
    
    foreach ($field in $RequiredFields) {
        if (-not (Get-Member -InputObject $content -Name $field -MemberType NoteProperty)) {
            Write-Warning "Missing required telemetry field: $field"
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS
Mutates a manifest file to create mismatch conditions for testing.

.DESCRIPTION
Deliberately corrupts manifest fields to test verification failure paths.

.PARAMETER ManifestPath
Path to the manifest.json file to mutate.

.PARAMETER MutationType
Type of mutation: 'commit_mismatch', 'missing_field', 'invalid_json'

.NOTES
RTM: Test-Framework-001
#>
function Set-ManifestMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,
        
        [Parameter(Mandatory)]
        [ValidateSet('commit_mismatch', 'missing_field', 'invalid_json')]
        [string]$MutationType
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    switch ($MutationType) {
        'commit_mismatch' {
            $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
            if ($manifest -is [System.Collections.IEnumerable]) {
                foreach ($item in $manifest) {
                    if ($item.PSObject.Properties['last_commit']) {
                        $item.last_commit = '0000000000000000000000000000000000000000'
                    }
                }
            }
            elseif ($manifest.PSObject.Properties['last_commit']) {
                $manifest.last_commit = '0000000000000000000000000000000000000000'
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
        }
        'missing_field' {
            $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
            if ($manifest -is [System.Collections.IEnumerable]) {
                foreach ($item in $manifest) {
                    if ($item.PSObject.Properties['last_commit']) {
                        $item.PSObject.Properties.Remove('last_commit')
                    }
                }
            }
            elseif ($manifest.PSObject.Properties['last_commit']) {
                $manifest.PSObject.Properties.Remove('last_commit')
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
        }
        'invalid_json' {
            Set-Content -LiteralPath $ManifestPath -Value '{ invalid json content' -Encoding utf8
        }
    }
}

Export-ModuleMember -Function @(
    'New-GcliStub',
    'New-SyntheticRepo',
    'Test-TelemetryLog',
    'Set-ManifestMutation'
)
