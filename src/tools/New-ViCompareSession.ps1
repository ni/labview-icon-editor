#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$SessionsRoot,
    [string]$Prefix = 'vi-compare',
    [string]$RunId,
    [switch]$RequireArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) {
        return (Resolve-Path '.').Path
    }
    return (Get-Item $Root).FullName
}

$RepoRoot = Resolve-RepoRoot -Root $RepoRoot

if ($SessionsRoot) {
    if (-not [System.IO.Path]::IsPathRooted($SessionsRoot)) {
        $SessionsRoot = Join-Path $RepoRoot $SessionsRoot
    }
} else {
    $SessionsRoot = $RepoRoot
}
$SessionsRoot = [System.IO.Path]::GetFullPath($SessionsRoot)
if (-not (Test-Path -LiteralPath $SessionsRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $SessionsRoot | Out-Null
}

if (-not $RunId) {
    $RunId = (Get-Date -Format 'yyyyMMddHHmmssfff')
}

$sessionName = "{0}-{1}" -f $Prefix, $RunId
$sessionPath = Join-Path $SessionsRoot $sessionName
$suffix = 1
while (Test-Path -LiteralPath $sessionPath -PathType Container) {
    $sessionName = "{0}-{1}-{2:D2}" -f $Prefix, $RunId, $suffix
    $sessionPath = Join-Path $SessionsRoot $sessionName
    $suffix++
}

New-Item -ItemType Directory -Force -Path $sessionPath | Out-Null
$infoPath = Join-Path $sessionPath 'session-info.json'
$createdAt = Get-Date
$sessionInfo = [ordered]@{
    schema           = 'icon-editor/vi-compare-session@v1'
    session          = $sessionName
    runId            = $RunId
    createdAt        = $createdAt.ToString('o')
    requireArtifacts = $RequireArtifacts.IsPresent
    status           = 'pending'
    outputs          = @{}
}
$sessionInfo | ConvertTo-Json -Depth 6 | Out-File -FilePath $infoPath -Encoding UTF8

[pscustomobject]@{
    SessionId        = $RunId
    SessionName      = $sessionName
    SessionPath      = $sessionPath
    InfoPath         = $infoPath
    RequireArtifacts = [bool]$RequireArtifacts
    CreatedAt        = $createdAt.ToString('o')
}
