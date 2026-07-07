#Requires -Version 7.0
<#
.SYNOPSIS
    Runs PSScriptAnalyzer with repo settings and optional baseline enforcement.

.DESCRIPTION
    Scans PowerShell scripts in the repository, applies a shared ruleset,
    and optionally compares results against a baseline file to fail only on
    newly introduced issues.

.PARAMETER RepoRoot
    Repository root. Defaults to the parent of this script.

.PARAMETER SettingsPath
    Path to a PSScriptAnalyzer settings file (.psd1).

.PARAMETER BaselinePath
    Path to the baseline JSON file.

.PARAMETER UpdateBaseline
    Regenerate the baseline from current analyzer results.

.PARAMETER FailOnIssues
    Fail when new issues are detected.

.PARAMETER WriteSummary
    Write a summary to the GitHub Step Summary file.

.PARAMETER SummaryPath
    Optional override path for summary output (defaults to GITHUB_STEP_SUMMARY).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$SettingsPath,

    [Parameter(Mandatory = $false)]
    [string]$BaselinePath,

    [switch]$UpdateBaseline,

    [Parameter(Mandatory = $false)]
    [bool]$FailOnIssues = $true,

    [switch]$WriteSummary,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

function Resolve-DefaultPath {
    param([string]$Root, [string]$RelativePath, [string]$Override)

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return (Resolve-Path -Path $Override -ErrorAction Stop).Path
    }

    return (Join-Path $Root $RelativePath)
}

function Get-AnalyzerFileList {
    param([string]$Root)

    $excludeTokens = @(
        "${([System.IO.Path]::DirectorySeparatorChar)}.git${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}builds${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}TestResults${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}artifacts${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}node_modules${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}packages${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}dist${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}bin${([System.IO.Path]::DirectorySeparatorChar)}",
        "${([System.IO.Path]::DirectorySeparatorChar)}obj${([System.IO.Path]::DirectorySeparatorChar)}"
    )

    $files = Get-ChildItem -Path $Root -Recurse -File -Include *.ps1, *.psm1 -ErrorAction SilentlyContinue
    if (-not $files) {
        return @()
    }

    return $files | Where-Object {
        $path = $_.FullName
        foreach ($token in $excludeTokens) {
            if ($path -like "*$token*") {
                return $false
            }
        }
        return $true
    } | Select-Object -ExpandProperty FullName
}

function Convert-IssueRecord {
    param(
        [object]$Issue,
        [string]$Root
    )

    $relative = [System.IO.Path]::GetRelativePath($Root, $Issue.ScriptPath)
    return [pscustomobject]@{
        RuleName = $Issue.RuleName
        Severity = [string]$Issue.Severity
        Message  = $Issue.Message
        Path     = $relative
        Line     = $Issue.Line
        Column   = $Issue.Column
    }
}

function Get-IssueKey {
    param([object]$Issue)

    return "{0}|{1}|{2}|{3}|{4}|{5}" -f $Issue.RuleName, ([string]$Issue.Severity), $Issue.Path, $Issue.Line, $Issue.Column, $Issue.Message
}

function Read-Baseline {
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    $raw = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    return ($raw | ConvertFrom-Json)
}

function Write-Baseline {
    param([string]$Path, [object[]]$Issues)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    $Issues | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding utf8
}

function Resolve-SummaryPath {
    param(
        [string]$OverridePath,
        [string]$RepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return $OverridePath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_PSSCRIPTANALYZER_SUMMARY_PATH)) {
        return $env:LVIE_PSSCRIPTANALYZER_SUMMARY_PATH
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        return $env:GITHUB_STEP_SUMMARY
    }

    if ($env:GITHUB_ACTIONS -eq 'true') {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Join-Path $RepoRoot 'TestResults\psscriptanalyzer-summary.md')
    }

    return $null
}

function Write-Summary {
    param(
        [string]$Path,
        [int]$FileCount,
        [int]$TotalIssues,
        [object[]]$NewIssues
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $lines = @()
    $lines += "## PowerShell Static Analysis"
    $lines += ("- Files scanned: {0}" -f $FileCount)
    $lines += ("- Issues found: {0}" -f $TotalIssues)
    $lines += ("- New issues: {0}" -f $NewIssues.Count)
    if ($NewIssues.Count -gt 0) {
        $lines += ""
        $lines += "### New Issues"
        foreach ($issue in ($NewIssues | Select-Object -First 25)) {
            $lines += ("- {0}:{1} [{2}] {3}" -f $issue.Path, $issue.Line, $issue.RuleName, $issue.Message)
        }
        if ($NewIssues.Count -gt 25) {
            $lines += ("- ... ({0} more)" -f ($NewIssues.Count - 25))
        }
    }
    $lines += ""

    $lines | Out-File -FilePath $Path -Append -Encoding utf8
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$settingsPath = Resolve-DefaultPath -Root $repoRoot -RelativePath 'Tooling/PSScriptAnalyzerSettings.psd1' -Override $SettingsPath
$baselinePath = Resolve-DefaultPath -Root $repoRoot -RelativePath 'Tooling/PSScriptAnalyzerBaseline.json' -Override $BaselinePath

if (-not (Test-Path -Path $settingsPath)) {
    throw "PSScriptAnalyzer settings file not found at $settingsPath"
}

$files = Get-AnalyzerFileList -Root $repoRoot
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No PowerShell files found to analyze."
    return
}

$results = foreach ($file in $files) {
    Invoke-ScriptAnalyzer -Path $file -Settings $settingsPath
}
$normalized = @()
if ($results) {
    $normalized = $results | ForEach-Object { Convert-IssueRecord -Issue $_ -Root $repoRoot } |
        Sort-Object -Property Path, Line, Column, RuleName
}

if ($UpdateBaseline) {
    Write-Baseline -Path $baselinePath -Issues $normalized
    Write-Host ("Baseline updated: {0} issue(s) recorded at {1}" -f $normalized.Count, $baselinePath)
    return
}

if (-not (Test-Path -Path $baselinePath)) {
    throw "Baseline file not found at $baselinePath. Run Invoke-PSScriptAnalyzer.ps1 -UpdateBaseline to create one."
}

$baseline = Read-Baseline -Path $baselinePath
$baselineSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($entry in $baseline) {
    $baselineSet.Add((Get-IssueKey -Issue $entry)) | Out-Null
}

$newIssues = @()
foreach ($issue in $normalized) {
    $key = Get-IssueKey -Issue $issue
    if (-not $baselineSet.Contains($key)) {
        $newIssues += $issue
    }
}

if ($WriteSummary) {
    $summaryPath = Resolve-SummaryPath -OverridePath $SummaryPath -RepoRoot $repoRoot
    if ([string]::IsNullOrWhiteSpace($summaryPath)) {
        if ($env:GITHUB_ACTIONS -eq 'true') {
            Write-Warning "WriteSummary requested, but no summary path was provided and GITHUB_STEP_SUMMARY is not set."
        } else {
            Write-Host "WriteSummary skipped: no summary path provided."
        }
    } else {
        $summaryDir = Split-Path -Parent $summaryPath
        if ($summaryDir -and -not (Test-Path -Path $summaryDir)) {
            New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
        }
        Write-Summary -Path $summaryPath -FileCount $files.Count -TotalIssues $normalized.Count -NewIssues $newIssues
    }
}

if ($newIssues.Count -gt 0) {
    Write-Host ("New PSScriptAnalyzer issues detected: {0}" -f $newIssues.Count)
    $newIssues | ForEach-Object {
        Write-Host (" - {0}:{1} [{2}] {3}" -f $_.Path, $_.Line, $_.RuleName, $_.Message)
    }
    if ($FailOnIssues) {
        throw "PSScriptAnalyzer detected new issues. Update baseline or fix the findings."
    }
} else {
    Write-Host ("No new PSScriptAnalyzer issues detected. Total issues: {0}" -f $normalized.Count)
}


