#Requires -Version 7.0
<#
.SYNOPSIS
    Lints runner-cli requirement statements for A-005 atomicity rules.

.DESCRIPTION
    Enforces targeted ISO-aligned atomicity checks for the requirement IDs
    listed by acceptance scenario A-005 in docs/runner-cli-requirements-v5-acceptance.md.
    The script fails when a target requirement line is missing or appears to
    contain multiple independently testable modal obligations.

.PARAMETER RepoRoot
    Optional repository root override. Defaults to git top-level when available.

.PARAMETER RequirementsPath
    Path to the requirements document relative to repo root.

.PARAMETER AcceptancePath
    Path to the acceptance matrix document relative to repo root.

.PARAMETER WriteSummary
    When set, writes a short result block to GITHUB_STEP_SUMMARY if available.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$RequirementsPath = 'docs/runner-cli-requirements.md',

    [Parameter(Mandatory = $false)]
    [string]$AcceptancePath = 'docs/runner-cli-requirements-v5-acceptance.md',

    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Resolve-DocPath {
    param(
        [string]$Root,
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -Path $Path -ErrorAction Stop).Path
    }

    return (Resolve-Path -Path (Join-Path $Root $Path) -ErrorAction Stop).Path
}

function Add-Finding {
    param(
        [string]$FilePath,
        [int]$LineNumber,
        [string]$Message
    )

    $script:findings += [pscustomobject]@{
        File    = $FilePath
        Line    = $LineNumber
        Message = $Message
    }

    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Host ("::error file={0},line={1}::{2}" -f $FilePath, $LineNumber, $Message)
    } else {
        Write-Host ("ERROR: {0}:{1} {2}" -f $FilePath, $LineNumber, $Message)
    }
}

function Parse-RcMap {
    param([string]$FilePath)

    $map = @{}
    $lines = Get-Content -Path $FilePath
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^(RC-[A-Z0-9]+-[0-9]{3}):\s*(.+)$') {
            $id = $matches[1]
            $text = $matches[2].Trim()
            $map[$id] = [pscustomobject]@{
                Line = $i + 1
                Text = $text
            }
        }
    }

    return $map
}

function Get-A005TargetIds {
    param([string]$AcceptanceFilePath)

    $a005Line = Get-Content -Path $AcceptanceFilePath | Where-Object {
        $_ -match '^\|\s*A-005\s*\|'
    } | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($a005Line)) {
        throw "Acceptance scenario A-005 was not found in $AcceptanceFilePath."
    }

    $cells = $a005Line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 3) {
        throw "A-005 row is malformed in $AcceptanceFilePath."
    }

    $targetCell = $cells[2]
    $ids = [regex]::Matches($targetCell, 'RC-[A-Z0-9]+-[0-9]{3}') |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique

    if (-not $ids -or $ids.Count -eq 0) {
        throw "A-005 row does not include any RC IDs in $AcceptanceFilePath."
    }

    return $ids
}

function Test-A005Pattern {
    param(
        [string]$RequirementText
    )

    $result = [pscustomobject]@{
        Ok      = $true
        Reasons = @()
    }

    $modalMatches = [regex]::Matches(
        $RequirementText,
        '\b(?:shall not|shall|should|may)\b',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $shallMatches = [regex]::Matches(
        $RequirementText,
        '\bshall\b',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if ($modalMatches.Count -gt 1) {
        $result.Ok = $false
        $result.Reasons += "contains multiple modal keywords ($($modalMatches.Count)); expected one independently testable obligation."
    }

    if ($shallMatches.Count -ne 1) {
        $result.Ok = $false
        $result.Reasons += "contains $($shallMatches.Count) occurrences of 'shall'; expected exactly one."
    }

    if ([regex]::IsMatch($RequirementText, ';[^.]*\b(?:shall|should|may)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $result.Ok = $false
        $result.Reasons += "contains a semicolon followed by another modal clause."
    }

    if ([regex]::IsMatch($RequirementText, ',\s*(?:and|or)\s+[^.;]*\b(?:shall|should|may)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $result.Ok = $false
        $result.Reasons += "contains a conjunction introducing a second modal clause."
    }

    return $result
}

$script:findings = @()
$resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$requirementsFile = Resolve-DocPath -Root $resolvedRepoRoot -Path $RequirementsPath
$acceptanceFile = Resolve-DocPath -Root $resolvedRepoRoot -Path $AcceptancePath

$rcMap = Parse-RcMap -FilePath $requirementsFile
$targetIds = Get-A005TargetIds -AcceptanceFilePath $acceptanceFile

foreach ($targetId in $targetIds) {
    if (-not $rcMap.ContainsKey($targetId)) {
        Add-Finding -FilePath $requirementsFile -LineNumber 1 -Message ("A-005 target ID {0} was not found in requirements document." -f $targetId)
        continue
    }

    $entry = $rcMap[$targetId]
    $patternResult = Test-A005Pattern -RequirementText $entry.Text
    if (-not $patternResult.Ok) {
        foreach ($reason in $patternResult.Reasons) {
            Add-Finding -FilePath $requirementsFile -LineNumber $entry.Line -Message ("{0} {1}" -f $targetId, $reason)
        }
    }
}

$summaryPath = $env:GITHUB_STEP_SUMMARY
if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($summaryPath)) {
    $lines = @()
    $lines += "### A-005 Requirements Lint"
    $lines += ""
    $lines += "- Requirements file: ``$requirementsFile``"
    $lines += "- Acceptance file: ``$acceptanceFile``"
    $lines += "- Target RC IDs: $($targetIds -join ', ')"
    if ($script:findings.Count -eq 0) {
        $lines += "- Result: pass"
    } else {
        $lines += "- Result: fail ($($script:findings.Count) finding(s))"
    }
    Add-Content -Path $summaryPath -Value ($lines -join [Environment]::NewLine)
}

if ($script:findings.Count -gt 0) {
    throw ("A-005 requirements lint failed with {0} finding(s)." -f $script:findings.Count)
}

Write-Host ("A-005 requirements lint passed for {0} target RC IDs." -f $targetIds.Count)
