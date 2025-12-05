<#
.SYNOPSIS
  Build a tooling distribution zip + manifest for VS Code tasks and helper scripts.

.DESCRIPTION
  - Generates a commit index scoped to the tooling payload.
  - Copies whitelisted files (tasks, scripts, configs, CLIs) into a staging folder.
  - Emits manifest.json/csv with size + sha256 + commit info.
  - Zips the staging folder to builds/artifacts/tooling-distribution.zip.

.PARAMETER RepositoryPath
  Path to the repo root.

.PARAMETER AllowDirty
  Allow running on a dirty working tree (for local/dev use).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Stamp {
    param([string]$Level = "INFO", [string]$Message)
    Write-Host ("[{0}] {1}" -f $Level, $Message)
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path

# Paths and outputs
$distRoot    = Join-Path $repoRoot 'builds/ToolingDistribution'
$artifactDir = Join-Path $repoRoot 'builds/artifacts'
$zipPath     = Join-Path $artifactDir 'tooling-distribution.zip'
$manifestJson = Join-Path $distRoot 'tooling-manifest.json'
$manifestCsv  = Join-Path $distRoot 'tooling-manifest.csv'
$commitIndexPath = Join-Path $repoRoot 'builds/cache/tooling-commit-index.json'
$commitIndexCsv  = [IO.Path]::ChangeExtension($commitIndexPath, '.csv')

# Whitelist of payload paths (repo-relative)
$includePaths = @(
    '.vscode',
    'configs',
    'scenarios',
    'runner_dependencies.vipc',
    'scripts/run-worktree-task.ps1',
    'scripts/run-requirements-summary-task.ps1',
    'scripts/task-devmode-bind.ps1',
    'scripts/clear-labview-librarypaths-all.ps1',
    'scripts/run-xcli.ps1',
    'scripts/run-worktree-tests.ps1',
    'scripts/test/Test.ps1',
    'scripts/vi-compare',
    'scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1',
    'scripts/labview/vipb-bump-worktree.ps1',
    'scripts/clear-tooling-cache.ps1',
    'Tooling/dotnet/OrchestrationCli',
    'Tooling/dotnet/IntegrationEngineCli',
    'Tooling/dotnet/DevModeAgentCli',
    'Tooling/dotnet/RequirementsSummarizer',
    'Tooling/dotnet/TestsCli',
    'Tooling/x-cli/src/XCli',
    'Tooling/x-cli/src/Telemetry'
)

Write-Stamp "INFO" "Generating tooling commit index..."
& "$repoRoot/scripts/build-source-distribution/New-CommitIndex.ps1" `
    -RepositoryPath $repoRoot `
    -IncludePaths $includePaths `
    -AllowDirty:$AllowDirty `
    -OutputPath $commitIndexPath `
    -CsvOutputPath $commitIndexCsv

Write-Stamp "INFO" "Staging payload to $distRoot"
if (Test-Path -LiteralPath $distRoot) {
    Remove-Item -LiteralPath $distRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

function Copy-Payload {
    param([string]$RepoRoot, [string]$RelPath, [string]$DestRoot)
    $src = Join-Path $RepoRoot $RelPath
    if (-not (Test-Path -LiteralPath $src)) { return }
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        $destFile = Join-Path $DestRoot $RelPath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destFile) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $destFile -Force
    } else {
        Copy-Item -Path $src -Destination (Join-Path $DestRoot (Split-Path $RelPath -Leaf)) -Recurse -Force
    }
}

foreach ($p in $includePaths) { Copy-Payload -RepoRoot $repoRoot -RelPath $p -DestRoot $distRoot }

# Load commit index
$commitIndex = Get-Content -LiteralPath $commitIndexPath | ConvertFrom-Json
$commitMap = @{}
foreach ($e in $commitIndex.entries) {
    $commitMap[$e.path.ToLowerInvariant()] = $e
}

# Build manifest entries
$manifest = @()
Get-ChildItem -LiteralPath $distRoot -File -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($distRoot.Length).TrimStart('\','/')
    $key = $rel.Replace('\','/').ToLowerInvariant()
    $commitInfo = $null
    $commitSource = 'commit-index'
    if ($commitMap.ContainsKey($key)) {
        $commitInfo = $commitMap[$key]
    }
    # Some generated files (manifest/zip) are not part of the commit index; tolerate missing commit info.
    if (-not $commitInfo -or -not $commitInfo.commit) {
        $commitSource = 'generated'
    }
    $manifest += [pscustomobject]@{
        path          = $rel.Replace('\','/')
        size_bytes    = $_.Length
        sha256        = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        commit        = if ($commitInfo) { $commitInfo.commit } else { $null }
        author        = if ($commitInfo) { $commitInfo.author } else { $null }
        date          = if ($commitInfo) { $commitInfo.date } else { $null }
        commit_source = $commitSource
    }
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestJson -Encoding UTF8
$manifest | Export-Csv -LiteralPath $manifestCsv -NoTypeInformation -Encoding UTF8

Write-Stamp "INFO" "Zipping to $zipPath"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $distRoot '*') -DestinationPath $zipPath -Force

Write-Stamp "INFO" "tooling-distribution built:"
Write-Stamp "INFO" " - manifest: $manifestJson"
Write-Stamp "INFO" " - zip     : $zipPath"
