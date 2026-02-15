#Requires -Version 7.0
<#
.SYNOPSIS
    Summarize the latest pylavi offenders report for automation.

.DESCRIPTION
    Reads the latest pylavi offenders JSON report written by Run-CICompositeLocal
    and prints a concise summary for agent handoffs or automation.

.PARAMETER RepoRoot
    Optional repository root override.

.PARAMETER Path
    Optional report path override.

.PARAMETER Top
    Maximum number of offenders to print (default 10).

.PARAMETER Label
    Optional label suffix to select a label-specific report (e.g., strict or legacy).

.PARAMETER OutputPath
    Optional path to write a short redacted summary JSON for automation.

.PARAMETER WriteSummary
    Append a brief summary to GITHUB_STEP_SUMMARY when available.

.PARAMETER Quiet
    Print only PYLAVI_* lines (suppresses human-readable output).

.PARAMETER Sha
    Commit SHA to select a deterministic local report (e.g., pylavi-offenders.<sha>.json).

.PARAMETER RunId
    Workflow run id to fetch when FetchLatest is used.

.PARAMETER FetchLatest
    When the report is missing, fetch the latest CI artifact first.

.PARAMETER FetchBranch
    Branch name used when FetchLatest is set (default: develop).

.PARAMETER FetchWorkflow
    Workflow file name used when FetchLatest is set (default: ci-composite.yml).

.PARAMETER FetchRepo
    GitHub repo (owner/name) override used when FetchLatest is set.

.PARAMETER FetchToken
    GitHub token override used when FetchLatest is set.

.PARAMETER FetchArtifactPrefix
    Artifact prefix override used when FetchLatest is set.

.PARAMETER FetchPreferLabel
    Preferred label used when FetchLatest is set.

.PARAMETER ValidateExists
    Only validate that the report exists; exit non-zero if missing.

.PARAMETER FailOnEmpty
    Exit non-zero if the report contains no offender entries.

.PARAMETER FailOnFindings
    Exit non-zero if the report contains any offender entries.

.PARAMETER FailOnThreshold
    Exit non-zero if total FAILs exceed the threshold.

.PARAMETER AsJson
    Output the full JSON report instead of a summary.

.NOTES
    Exit codes:
      0 = success
      2 = report missing (when -ValidateExists is used)
      3 = report empty (when -FailOnEmpty is used)
      4 = offenders present (when -FailOnFindings is used)
      5 = offenders exceed threshold (when -FailOnThreshold is used)
#>

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 200)]
    [int]$Top = 10,

    [Parameter(Mandatory = $false)]
    [string]$Label,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [switch]$WriteSummary,

    [switch]$Quiet,

    [Parameter(Mandatory = $false)]
    [string]$Sha,

    [Parameter(Mandatory = $false)]
    [int]$RunId,

    [switch]$FetchLatest,

    [Parameter(Mandatory = $false)]
    [string]$FetchBranch = 'develop',

    [Parameter(Mandatory = $false)]
    [string]$FetchWorkflow = 'ci-composite.yml',

    [Parameter(Mandatory = $false)]
    [string]$FetchRepo,

    [Parameter(Mandatory = $false)]
    [string]$FetchToken,

    [Parameter(Mandatory = $false)]
    [string]$FetchArtifactPrefix = 'pylavi-validate-offenders',

    [Parameter(Mandatory = $false)]
    [string]$FetchPreferLabel = 'strict',

    [switch]$ValidateExists,

    [switch]$FailOnEmpty,

    [switch]$FailOnFindings,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1000000)]
    [int]$FailOnThreshold = -1,

    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Override)

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return (Resolve-Path -Path $Override).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }
    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Write-MachineLine {
    param(
        [string]$File,
        [string]$LabelValue,
        [string]$ShaValue,
        [bool]$HasFindings,
        [int]$TotalFails,
        [int]$ExitCode
    )

    Write-Host ("PYLAVI_OFFENDERS_FILE={0}" -f $File)
    Write-Host ("PYLAVI_OFFENDERS_LABEL={0}" -f $LabelValue)
    if (-not [string]::IsNullOrWhiteSpace($ShaValue)) {
        Write-Host ("PYLAVI_OFFENDERS_SHA={0}" -f $ShaValue)
    }
    Write-Host ("PYLAVI_OFFENDERS_TOTAL_FAILS={0}" -f $TotalFails)
    Write-Host ("PYLAVI_OFFENDERS_HAS_FINDINGS={0}" -f ($HasFindings.ToString().ToLowerInvariant()))
    Write-Host ("PYLAVI_OFFENDERS_EXIT_CODE={0}" -f $ExitCode)
}

function ConvertTo-NormalizedSha {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $candidate = $Value.Trim()
    if ($candidate -match '^[0-9a-fA-F]{7,40}$') {
        return $candidate.ToLowerInvariant()
    }
    return $null
}

function Resolve-ShaFromReport {
    param([object]$Report)
    if (-not $Report) { return $null }
    foreach ($field in @('source_sha', 'sha', 'head_sha', 'commit')) {
        if ($Report.PSObject.Properties.Name -contains $field) {
            $normalized = ConvertTo-NormalizedSha -Value $Report.$field
            if ($normalized) { return $normalized }
        }
    }
    return $null
}

function Resolve-ShaFromPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $name = [System.IO.Path]::GetFileName($Path)
    if ($name -match '^pylavi-offenders\.(?<label>[^.]+)\.(?<sha>[0-9a-fA-F]{7,40})\.json$') {
        return (ConvertTo-NormalizedSha -Value $Matches['sha'])
    }
    if ($name -match '^pylavi-offenders\.(?<sha>[0-9a-fA-F]{7,40})\.json$') {
        return (ConvertTo-NormalizedSha -Value $Matches['sha'])
    }
    return $null
}

function Resolve-ShaHint {
    param(
        [string]$Path,
        [string]$Provided
    )
    $normalized = ConvertTo-NormalizedSha -Value $Provided
    if ($normalized) { return $normalized }
    return Resolve-ShaFromPath -Path $Path
}

function ConvertTo-MarkdownEscaped {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $safe = $Value -replace "(`r`n|`n|`r)", ' '
    $safe = $safe -replace '\|', '\|'
    $safe = $safe -replace '`', '\`'
    return $safe
}

$repoRootResolved = Resolve-RepoRoot -Override $RepoRoot
$reportPath = if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $Path
} else {
    if (-not [string]::IsNullOrWhiteSpace($Sha) -and -not [string]::IsNullOrWhiteSpace($Label)) {
        Join-Path $repoRootResolved ("TestResults\agent-logs\pylavi-offenders.{0}.{1}.json" -f $Label, $Sha)
    } elseif (-not [string]::IsNullOrWhiteSpace($Sha)) {
        Join-Path $repoRootResolved ("TestResults\agent-logs\pylavi-offenders.{0}.json" -f $Sha)
    } elseif (-not [string]::IsNullOrWhiteSpace($Label)) {
        Join-Path $repoRootResolved ("TestResults\agent-logs\pylavi-offenders.latest.{0}.json" -f $Label)
    } else {
        Join-Path $repoRootResolved 'TestResults\agent-logs\pylavi-offenders.latest.json'
    }
}

if (-not (Test-Path -Path $reportPath)) {
    if ($FetchLatest -and -not $PSBoundParameters.ContainsKey('Path')) {
        $fetchScript = Join-Path $repoRootResolved 'Tooling\Fetch-PylaviOffenders.ps1'
        if (-not (Test-Path -Path $fetchScript)) {
            throw "Fetch-PylaviOffenders.ps1 not found at $fetchScript"
        }

        $fetchParams = @{
            Branch         = $FetchBranch
            Workflow       = $FetchWorkflow
            ArtifactPrefix = $FetchArtifactPrefix
            PreferLabel    = $FetchPreferLabel
            RepoRoot       = $repoRootResolved
        }
        if (-not [string]::IsNullOrWhiteSpace($Sha)) {
            $fetchParams.Sha = $Sha
        }
        if ($RunId -gt 0) {
            $fetchParams.RunId = $RunId
        }
        if (-not [string]::IsNullOrWhiteSpace($FetchRepo)) {
            $fetchParams.Repo = $FetchRepo
        }
        if (-not [string]::IsNullOrWhiteSpace($FetchToken)) {
            $fetchParams.Token = $FetchToken
        }
        if (-not [string]::IsNullOrWhiteSpace($Label)) {
            $fetchParams.Label = $Label
        }

        & $fetchScript @fetchParams

        if (-not (Test-Path -Path $reportPath)) {
            if (-not [string]::IsNullOrWhiteSpace($Label)) {
                $fallbackAfterFetch = Join-Path $repoRootResolved 'TestResults\agent-logs\pylavi-offenders.latest.json'
                if (Test-Path -Path $fallbackAfterFetch) {
                    $reportPath = $fallbackAfterFetch
                }
            }
        }
    }

    $fallbackPath = $null
    if (-not [string]::IsNullOrWhiteSpace($Label) -and -not $PSBoundParameters.ContainsKey('Path')) {
        $fallbackPath = Join-Path $repoRootResolved 'TestResults\agent-logs\pylavi-offenders.latest.json'
    }

    if ($fallbackPath -and (Test-Path -Path $fallbackPath) -and -not $ValidateExists) {
        Write-Warning ("Label-specific report not found at {0}; falling back to {1}." -f $reportPath, $fallbackPath)
        $reportPath = $fallbackPath
    } else {
        $message = "Pylavi offenders report not found at $reportPath. Run Tooling\\Run-ViValidate.ps1 first."
        if ($ValidateExists) {
            $shaHint = Resolve-ShaHint -Path $reportPath -Provided $Sha
            Write-Error $message
            if (-not $AsJson) {
                Write-MachineLine -File $reportPath -LabelValue $Label -ShaValue $shaHint -HasFindings:$false -TotalFails 0 -ExitCode 2
            }
            exit 2
        }
        throw $message
    }
}

if ($ValidateExists) {
    if (-not $AsJson) {
        $shaHint = Resolve-ShaHint -Path $reportPath -Provided $Sha
        Write-MachineLine -File $reportPath -LabelValue $Label -ShaValue $shaHint -HasFindings:$false -TotalFails 0 -ExitCode 0
    }
    exit 0
}

$report = Get-Content -Raw -Path $reportPath | ConvertFrom-Json
$totalFails = if ($null -ne $report.total_fails) { [int]$report.total_fails } else { 0 }
$labelValue = if (-not [string]::IsNullOrWhiteSpace($report.label)) { $report.label } else { $Label }
$shaValue = Resolve-ShaHint -Path $reportPath -Provided $Sha
if (-not $shaValue) {
    $shaValue = Resolve-ShaFromReport -Report $report
}
$hasOffenders = $false
if ($report.top_offenders -and $report.top_offenders.Count -gt 0) {
    $hasOffenders = $true
} elseif ($totalFails -gt 0) {
    $hasOffenders = $true
}

$exitCode = 0
$exitMessage = $null
if ($FailOnEmpty -and -not $hasOffenders) {
    $exitCode = 3
    $exitMessage = 'Pylavi offenders report contains no entries.'
} elseif ($FailOnThreshold -ge 0 -and $totalFails -gt $FailOnThreshold) {
    $exitCode = 5
    $exitMessage = ("Pylavi offenders report exceeds threshold ({0} > {1})." -f $totalFails, $FailOnThreshold)
} elseif ($FailOnFindings -and $hasOffenders) {
    $exitCode = 4
    $exitMessage = 'Pylavi offenders report contains offender entries.'
}

if ($AsJson) {
    if (-not [string]::IsNullOrWhiteSpace($shaValue) -and -not ($report.PSObject.Properties.Name -contains 'source_sha')) {
        $report | Add-Member -NotePropertyName source_sha -NotePropertyValue $shaValue
    }
    $report | ConvertTo-Json -Depth 6
    if ($exitCode -ne 0) {
        Write-Error $exitMessage
        exit $exitCode
    }
    return
}

if (-not $Quiet) {
    Write-Host ("Label: {0}" -f $labelValue)
    Write-Host ("Generated (UTC): {0}" -f $report.generated_utc)
    Write-Host ("Total FAILs: {0}" -f $totalFails)
    if (-not [string]::IsNullOrWhiteSpace($shaValue)) {
        Write-Host ("Source SHA: {0}" -f $shaValue)
    }
    Write-Host ("Configured roots: <redacted> (count: {0})" -f $report.configured_root_count)
}

if (-not $Quiet -and $report.top_offenders -and $report.top_offenders.Count -gt 0) {
    Write-Host ""
    Write-Host ("Top offenders (max {0}):" -f $Top)
    $report.top_offenders | Select-Object -First $Top | ForEach-Object {
        Write-Host ("- {0} (count: {1})" -f $_.item, $_.count)
    }
}

if (-not $Quiet -and $report.top_absolute_offenders -and $report.top_absolute_offenders.Count -gt 0) {
    Write-Host ""
    Write-Host ("Top absolute-path offenders (max {0}):" -f $Top)
    $report.top_absolute_offenders | Select-Object -First $Top | ForEach-Object {
        Write-Host ("- {0} (count: {1})" -f $_.item, $_.count)
    }
}

if ($WriteSummary -and $env:GITHUB_STEP_SUMMARY) {
    $summary = @()
    $summary += "## Pylavi Offenders"
    $summary += ("- Label: {0}" -f $labelValue)
    $summary += ("- Generated (UTC): {0}" -f $report.generated_utc)
    $summary += ("- Total FAILs: {0}" -f $totalFails)
    if (-not [string]::IsNullOrWhiteSpace($shaValue)) {
        $summary += ("- Source SHA: {0}" -f $shaValue)
    }
    $summary += ("- Configured roots: <redacted> (count: {0})" -f $report.configured_root_count)
    $summary += ""
    if ($report.top_offenders -and $report.top_offenders.Count -gt 0) {
        $summary += "### Top offenders"
        $summary += ""
        $summary += "| Item | Count |"
        $summary += "|---|---:|"
        foreach ($entry in ($report.top_offenders | Select-Object -First $Top)) {
            $summary += ("| {0} | {1} |" -f (ConvertTo-MarkdownEscaped $entry.item), $entry.count)
        }
        $summary += ""
    }
    if ($report.top_absolute_offenders -and $report.top_absolute_offenders.Count -gt 0) {
        $summary += "### Top absolute-path offenders"
        $summary += ""
        $summary += "| Item | Count |"
        $summary += "|---|---:|"
        foreach ($entry in ($report.top_absolute_offenders | Select-Object -First $Top)) {
            $summary += ("| {0} | {1} |" -f (ConvertTo-MarkdownEscaped $entry.item), $entry.count)
        }
        $summary += ""
    }
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $summaryReportMap = [ordered]@{
        label                  = $labelValue
        generated_utc          = $report.generated_utc
        total_fails            = $totalFails
        configured_root_count  = $report.configured_root_count
        has_findings           = $hasOffenders
        file                   = $reportPath
    }
    if (-not [string]::IsNullOrWhiteSpace($shaValue)) {
        $summaryReportMap.source_sha = $shaValue
    }
    $summaryReportMap.top_offenders = @($report.top_offenders | Select-Object -First $Top)
    $summaryReportMap.top_absolute_offenders = @($report.top_absolute_offenders | Select-Object -First $Top)
    $summaryReport = [pscustomobject]$summaryReportMap
    $summaryDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($summaryDir) -and -not (Test-Path -Path $summaryDir)) {
        New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
    }
    $summaryReport | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputPath -Encoding utf8
}

Write-MachineLine -File $reportPath -LabelValue $labelValue -ShaValue $shaValue -HasFindings:$hasOffenders -TotalFails $totalFails -ExitCode $exitCode

if ($exitCode -ne 0) {
    Write-Error $exitMessage
    exit $exitCode
}

