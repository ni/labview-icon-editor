[CmdletBinding()]
param(
    [string]$RepositoryPath = ".",
    [string]$SourceDistRoot,
    [string]$CommitIndexPath,
    [string]$OutputPath,
    [string[]]$ExcludePatterns = @(),
    [switch]$LeanExclude
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
# LeanExclude preset documented in docs/vscode-tasks.md; defaults ship full content for parity.

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not $SourceDistRoot) {
    $SourceDistRoot = Join-Path $repo "builds/source-distribution"
}
if (-not (Test-Path -LiteralPath $SourceDistRoot)) {
    throw "Source distribution root not found: $SourceDistRoot"
}
if (-not $CommitIndexPath) {
    $CommitIndexPath = Join-Path $repo "builds/cache/commit-index.json"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repo "builds/artifacts/sd-bundle.zip"
}

$stage = Join-Path ([IO.Path]::GetTempPath()) ("sd-bundle-" + [Guid]::NewGuid())
$distTarget = Join-Path $stage 'LabVIEWIconAPI'
New-Item -ItemType Directory -Path $distTarget -Force | Out-Null

$sourceItems = Get-ChildItem -LiteralPath $SourceDistRoot -Force
foreach ($item in $sourceItems) {
    Copy-Item -LiteralPath $item.FullName -Destination $distTarget -Recurse -Force
}

$effectiveExcludes = @()
if ($ExcludePatterns) { $effectiveExcludes += $ExcludePatterns }
if ($LeanExclude) {
    # Optional lean preset for non-essential extras; defaults keep full content for reproducibility
    $effectiveExcludes += @(
        '.git', '.github', '.devcontainer', '.secrets', '.config',
        '*.md', '*.rst', '*.adoc', '*.txt',
        '.editorconfig', '.gitattributes', '.gitignore',
        '.pre-commit-config.yaml', '.dockerignore', '.yamllint', '.lychee.toml',
        'node_modules'
    )
}
if ($effectiveExcludes.Count -gt 0) {
    foreach ($pattern in $effectiveExcludes) {
        Get-ChildItem -LiteralPath $distTarget -Recurse -Force -Include $pattern -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if (Test-Path -LiteralPath $CommitIndexPath -PathType Leaf) {
    Copy-Item -LiteralPath $CommitIndexPath -Destination (Join-Path $stage 'commit-index.json') -Force
}
else {
    Write-Warning "commit-index.json not found at $CommitIndexPath; bundle will omit commit metadata."
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
Write-Host "[sd-bundle] Creating bundle at $OutputPath"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $OutputPath -Force
Write-Host "[sd-bundle] Bundle staged from $stage"
try { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } catch {}
