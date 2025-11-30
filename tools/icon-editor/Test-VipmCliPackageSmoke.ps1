[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ReleaseNotesPath = 'Tooling/deployment/release_notes.md',
    [ValidateSet('g-cli','vipm')]
    [string]$BuildToolchain = 'g-cli',
    [string]$JobName = 'Build VI Package',
    [switch]$Execute,
    [switch]$CloseLabVIEW,
    [switch]$DownloadArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Resolve-RepoRoot {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        $Candidate = (Join-Path $PSScriptRoot '..' '..')
    }
    return (Resolve-Path -LiteralPath $Candidate -ErrorAction Stop).ProviderPath
}

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$TargetPath
    )
    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        return [System.IO.Path]::GetFullPath($TargetPath)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $TargetPath))
}

$repoRoot = Resolve-RepoRoot -Candidate $RepoRoot
$workspace = $repoRoot
$releaseNotesFull = Resolve-AbsolutePath -BasePath $workspace -TargetPath $ReleaseNotesPath
if (-not (Test-Path -LiteralPath $releaseNotesFull -PathType Leaf)) {
    if ($Execute) {
        throw "Release notes file not found at '$releaseNotesFull'. Supply -ReleaseNotesPath or sync the deployment assets."
    }
    $releaseNotesDir = Split-Path -Parent $releaseNotesFull
    if (-not (Test-Path -LiteralPath $releaseNotesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $releaseNotesDir -Force | Out-Null
    }
    "# vipmcli smoke release notes`nGenerated $(Get-Date -Format o)" | Set-Content -LiteralPath $releaseNotesFull -Encoding UTF8
    Write-Host "[vipmcli-package-smoke] Created placeholder release notes at $releaseNotesFull" -ForegroundColor DarkGray
}

$replayScript = Join-Path $repoRoot 'src/tools/icon-editor/Replay-BuildVipJob.ps1'
if (-not (Test-Path -LiteralPath $replayScript -PathType Leaf)) {
    throw "Replay-BuildVipJob.ps1 not found at '$replayScript'."
}

$pwshArgs = @(
    '-NoLogo','-NoProfile',
    '-File',$replayScript,
    '-Workspace',$workspace,
    '-ReleaseNotesPath',$releaseNotesFull,
    '-JobName',$JobName,
    '-BuildToolchain',$BuildToolchain
)

if (-not $Execute) {
    $pwshArgs += @('-SkipReleaseNotes','-SkipVipbUpdate','-SkipBuild')
}
if ($CloseLabVIEW) { $pwshArgs += '-CloseLabVIEW' }
if ($DownloadArtifacts) { $pwshArgs += '-DownloadArtifacts' }

Write-Host "[vipmcli-package-smoke] RepoRoot    : $repoRoot"
Write-Host "[vipmcli-package-smoke] ReleaseNotes: $releaseNotesFull"
Write-Host "[vipmcli-package-smoke] Toolchain   : $BuildToolchain"
Write-Host ("[vipmcli-package-smoke] Mode        : {0}" -f ($(if ($Execute) { 'execute (runs build_vip.ps1)' } else { 'prepare-only (Skip build/update)' })))

& pwsh @pwshArgs
if ($LASTEXITCODE -ne 0) {
    throw "vipmcli package smoke failed with exit code $LASTEXITCODE."
}

Write-Host "[vipmcli-package-smoke] Completed successfully."
