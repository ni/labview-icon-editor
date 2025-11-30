#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [string]$LabVIEWExePath = 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe',
    [string]$ScenarioPath,
    [string]$OutputRoot,
    [string]$LabVIEWIniPath,
    [switch]$DryRun
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

if (-not $ScenarioPath) {
    $ScenarioPath = Join-Path $RepoRoot 'scenarios/vi-attr/vi-diff-requests.json'
} elseif (-not [System.IO.Path]::IsPathRooted($ScenarioPath)) {
    $ScenarioPath = Join-Path $RepoRoot $ScenarioPath
}
$ScenarioPath = (Resolve-Path -LiteralPath $ScenarioPath -ErrorAction Stop).Path

if (-not $OutputRoot) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputRoot = Join-Path $RepoRoot (Join-Path '.tmp-tests/vi-compare-replays' ("dev-mode-guard-{0}" -f $stamp))
} elseif (-not [System.IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot $OutputRoot
}

function Get-LabVIEWIniPath {
    param(
        [string]$ExePath,
        [string]$Override
    )
    if ($Override) {
        return (Resolve-Path -LiteralPath $Override -ErrorAction Stop).Path
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "LabVIEW path not found: $ExePath"
    }
    $item = Get-Item -LiteralPath $ExePath
    if ($item.PSIsContainer) {
        $root = $item.FullName
    } else {
        $root = $item.DirectoryName
    }
    $iniPath = Join-Path $root 'LabVIEW.ini'
    if (-not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
        throw "LabVIEW.ini not found at $iniPath"
    }
    return (Resolve-Path -LiteralPath $iniPath -ErrorAction Stop).Path
}

$iniPath = Get-LabVIEWIniPath -ExePath $LabVIEWExePath -Override $LabVIEWIniPath

function Backup-IniFile {
    param([string]$Path)
    $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) 'labview-ini-backups'
    if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $backupDir ("LabVIEW.ini.{0}.bak" -f $stamp)
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

function Remove-RepoPathFromIni {
    param(
        [string]$IniPath,
        [string]$RepoPath
    )
    $repoNormalized = [System.IO.Path]::GetFullPath($RepoPath).TrimEnd('\','/')
    $regex = 'LocalHost\.LibraryPaths\s*='
    $lines = Get-Content -LiteralPath $IniPath
    $modified = $false
    $updatedLines = $lines | ForEach-Object {
        if ($_ -match $regex) {
            $prefix = ($Matches[0])
            $value = $_.Substring($prefix.Length).Trim()
            $tokens = $value -split ';'
            $filtered = $tokens | Where-Object {
                $candidate = $_.Trim().Trim('"')
                if (-not $candidate) { return $false }
                try {
                    $candidateNormalized = [System.IO.Path]::GetFullPath($candidate).TrimEnd('\','/')
                } catch {
                    $candidateNormalized = $candidate
                }
                return -not ($candidateNormalized -ieq $repoNormalized)
            }
            $modified = $true
            $joined = ($filtered -join ';').Trim(';')
            return ($prefix + ' ' + $joined).Trim()
        }
        return $_
    }
    if ($modified) {
        Set-Content -LiteralPath $IniPath -Value $updatedLines -Encoding UTF8
    }
    return $modified
}

$backupPath = Backup-IniFile -Path $iniPath
Write-Host ("[dev-mode-test] Backed up LabVIEW.ini to {0}" -f $backupPath)

$restoreScript = {
    param($IniPath, $BackupPath)
    if ($BackupPath -and (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        Copy-Item -LiteralPath $BackupPath -Destination $IniPath -Force
        Write-Host ("[dev-mode-test] Restored LabVIEW.ini from {0}" -f $BackupPath)
    }
}

$modifiedIni = $false
try {
    $modifiedIni = Remove-RepoPathFromIni -IniPath $iniPath -RepoPath $RepoRoot
    if (-not $modifiedIni) {
        Write-Warning "[dev-mode-test] LabVIEW.ini did not contain the repo path before corruption."
    } else {
        Write-Host "[dev-mode-test] Removed repo root from LocalHost.LibraryPaths."
    }

    $summaryPath = Join-Path $OutputRoot 'vi-comparison-summary.json'
    if (Test-Path -LiteralPath $summaryPath) {
        Remove-Item -LiteralPath $summaryPath -Force
    }

    $replayParams = @{
        RepoRoot     = $RepoRoot
        ScenarioPath = $ScenarioPath
        OutputRoot   = $OutputRoot
        LabVIEWExePath = $LabVIEWExePath
    }
    if ($DryRun) { $replayParams['DryRun'] = $true }

    Write-Host "[dev-mode-test] Invoking Replay-ViCompareScenario.ps1 with corrupted dev-mode..."
    & (Join-Path $RepoRoot 'tools/icon-editor/Replay-ViCompareScenario.ps1') @replayParams

    if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        throw "[dev-mode-test] Expected replay summary not found at $summaryPath"
    }

    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -Depth 6
    $devModeStatus = $summary.labview?.devMode?.status
    if ($devModeStatus -ne 'repo-not-listed') {
        $detail = $summary.labview?.devMode?.message
        throw "[dev-mode-test] Expected labview.devMode.status to be 'repo-not-listed', found '$devModeStatus'. Detail: $detail"
    }
    Write-Host "[dev-mode-test] Assertion passed: labview.devMode.status = repo-not-listed."
} finally {
    & $restoreScript -IniPath $iniPath -BackupPath $backupPath
    if ($backupPath -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        Remove-Item -LiteralPath $backupPath -Force
    }
}
