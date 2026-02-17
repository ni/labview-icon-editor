#Requires -Version 7.0
<#
.SYNOPSIS
    Runs LabVIEWCLI VI Analyzer tasks from a deterministic task registry.

.DESCRIPTION
    Executes each VI Analyzer task listed in Tooling/vi-analyzer/tasks.json
    using LabVIEWCLI RunVIAnalyzer with strict LabVIEWCLI port-contract
    resolution.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64')]
    [string]$SupportedBitness = '64',

    [Parameter(Mandatory = $false)]
    [string]$TasksPath = 'Tooling/vi-analyzer/tasks.json',

    [Parameter(Mandatory = $false)]
    [string]$ReportsRoot = 'builds/vi-analyzer',

    [Parameter(Mandatory = $false)]
    [string]$StatusPath = 'builds/status/vi-analyzer-summary.json'
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRootPath {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    try {
        $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
        }
    } catch {
        Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Resolve-PathFromRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Initialize-Directory {
    param([string]$Path)

    if (-not (Test-Path -Path $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Get-CountFromText {
    param(
        [AllowNull()]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        return $null
    }

    return [int]$match.Groups['n'].Value
}

function Get-LabVIEWCliSummaryCount {
    param([string[]]$Lines)

    $text = if ($Lines -and $Lines.Count -gt 0) { $Lines -join [Environment]::NewLine } else { '' }
    return [ordered]@{
        passed          = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+passed\.\s*$'
        failed          = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+failed\.\s*$'
        skipped         = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+skipped\.\s*$'
        vi_unloadable   = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+VIs?\s+were\s+unloadable\.\s*$'
        test_unloadable = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+were\s+unloadable\.\s*$'
        test_unrunnable = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+were\s+unrun(?:a|n)ble\.\s*$'
        test_error      = Get-CountFromText -Text $text -Pattern '^\s*(?<n>\d+)\s+tests?\s+produced\s+error\.\s*$'
    }
}

function Get-ViAnalyzerReportCount {
    param(
        [AllowNull()]
        [string]$ReportText
    )

    if ([string]::IsNullOrWhiteSpace($ReportText)) {
        return $null
    }

    return [ordered]@{
        passed          = Get-CountFromText -Text $ReportText -Pattern '^\s*Passed Tests\s+(?<n>\d+)\s*$'
        failed          = Get-CountFromText -Text $ReportText -Pattern '^\s*Failed Tests\s+(?<n>\d+)\s*$'
        skipped         = Get-CountFromText -Text $ReportText -Pattern '^\s*Skipped Tests\s+(?<n>\d+)\s*$'
        vi_unloadable   = Get-CountFromText -Text $ReportText -Pattern '^\s*VI not loadable\s+(?<n>\d+)\s*$'
        test_unloadable = Get-CountFromText -Text $ReportText -Pattern '^\s*Test not loadable\s+(?<n>\d+)\s*$'
        test_unrunnable = Get-CountFromText -Text $ReportText -Pattern '^\s*Test not runnable\s+(?<n>\d+)\s*$'
        test_error      = Get-CountFromText -Text $ReportText -Pattern '^\s*Test error out\s+(?<n>\d+)\s*$'
    }
}

function Get-ViAnalyzerReportText {
    param([string]$ReportPath)

    if (-not (Test-Path -Path $ReportPath -PathType Leaf)) {
        return $null
    }

    return Get-Content -Path $ReportPath -Raw -ErrorAction Stop
}

function Get-ViAnalyzerFailureItemList {
    param(
        [AllowNull()]
        [string]$ReportText
    )

    $items = New-Object 'System.Collections.Generic.List[object]'
    if ([string]::IsNullOrWhiteSpace($ReportText)) {
        return $items.ToArray()
    }

    $section = ''
    $currentDisplayName = ''
    $currentFilePath = ''
    $lines = $ReportText -split "`r?`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\s*Failed Tests \(sorted by VI\)\s*$') {
            $section = 'failed_tests'
            $currentDisplayName = ''
            $currentFilePath = ''
            continue
        }

        if ($trimmed -match '^\s*Testing Errors\s*$') {
            $section = 'testing_errors'
            $currentDisplayName = ''
            $currentFilePath = ''
            continue
        }

        if ([string]::IsNullOrWhiteSpace($section)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -eq '(none)') {
            continue
        }

        $viHeaderMatch = [regex]::Match($trimmed, '^(?<display>.+?)\s+\((?<path>.+)\)\s*$')
        if ($viHeaderMatch.Success -and $trimmed.IndexOf("`t") -lt 0) {
            $currentDisplayName = $viHeaderMatch.Groups['display'].Value.Trim()
            $currentFilePath = $viHeaderMatch.Groups['path'].Value.Trim()
            continue
        }

        $parts = $line -split "`t", 2
        if ($parts.Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($parts[0]) -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
            $items.Add([pscustomobject]@{
                    section         = $section
                    vi_display_name = $currentDisplayName
                    file_path       = $currentFilePath
                    check_name      = $parts[0].Trim()
                    message         = $parts[1].Trim()
                    raw_line        = $line.Trim()
                }) | Out-Null
        }
    }

    return $items.ToArray()
}

function Get-OrderedUniqueFilePathList {
    param([object[]]$Items)

    $ordered = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($item in @($Items)) {
        $path = ''
        if ($null -ne $item -and $item.PSObject.Properties.Name -contains 'file_path') {
            $path = [string]$item.file_path
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if ($seen.Add($path)) {
            $ordered.Add($path) | Out-Null
        }
    }

    return $ordered.ToArray()
}

function Join-ViAnalyzerCount {
    param(
        [hashtable]$CliCounts,
        [hashtable]$ReportCounts
    )

    $keys = @('passed', 'failed', 'skipped', 'vi_unloadable', 'test_unloadable', 'test_unrunnable', 'test_error')
    $merged = [ordered]@{}
    foreach ($key in $keys) {
        $value = $null
        if ($CliCounts -and $CliCounts.Contains($key) -and $null -ne $CliCounts[$key]) {
            $value = [int]$CliCounts[$key]
        } elseif ($ReportCounts -and $ReportCounts.Contains($key) -and $null -ne $ReportCounts[$key]) {
            $value = [int]$ReportCounts[$key]
        }
        $merged[$key] = $value
    }

    if ($null -ne $merged.passed -and $null -ne $merged.failed -and $null -ne $merged.skipped) {
        $merged['analyzed_total'] = ([int]$merged.passed + [int]$merged.failed + [int]$merged.skipped)
    } else {
        $merged['analyzed_total'] = $null
    }

    return $merged
}

function Get-DisplayCount {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return '<missing>'
    }
    return [string]$Value
}

function Add-ViAnalyzerSummary {
    param(
        [string]$SummaryPath,
        [object[]]$TaskResults,
        [bool]$OverallSuccess,
        [string]$ReportsRoot,
        [string]$StatusPath
    )

    if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
        return
    }

    $lines = @()
    $lines += '### VI Analyzer (LabVIEWCLI)'
    $lines += ''
    $lines += ("- Overall result: **{0}**" -f $(if ($OverallSuccess) { 'pass' } else { 'fail' }))
    $lines += ('- Reports root: `{0}`' -f $ReportsRoot)
    $lines += ('- Status file: `{0}`' -f $StatusPath)
    $lines += ''
    $lines += '| Task | Analyzed | Passed | Failed | Skipped | VI unloadable | Test unloadable | Test unrunnable | Test errors | Exit | Result |'
    $lines += '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |'
    foreach ($task in $TaskResults) {
        $counts = $task.counts
        $lines += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |" -f `
            $task.id, `
            (Get-DisplayCount -Value $counts.analyzed_total), `
            (Get-DisplayCount -Value $counts.passed), `
            (Get-DisplayCount -Value $counts.failed), `
            (Get-DisplayCount -Value $counts.skipped), `
            (Get-DisplayCount -Value $counts.vi_unloadable), `
            (Get-DisplayCount -Value $counts.test_unloadable), `
            (Get-DisplayCount -Value $counts.test_unrunnable), `
            (Get-DisplayCount -Value $counts.test_error), `
            $task.exit_code, `
            $(if ($task.succeeded) { 'pass' } else { 'fail' }))
    }

    $failedTasks = @($TaskResults | Where-Object { -not $_.succeeded })
    if ($failedTasks.Count -gt 0) {
        $lines += ''
        $lines += '#### Failure Details'
        foreach ($task in $failedTasks) {
            $lines += ''
            $lines += ('- Task `{0}`' -f $task.id)
            $lines += ('- Report: `{0}`' -f $task.report_path)
            $failureItems = @($task.failure_items)
            if ($failureItems.Count -gt 0) {
                foreach ($item in $failureItems) {
                    $section = [string]$item.section
                    $filePath = [string]$item.file_path
                    $checkName = [string]$item.check_name
                    $message = [string]$item.message
                    $lines += ('- [{0}] `{1}` :: {2} - {3}' -f $section, $filePath, $checkName, $message)
                }
            } else {
                $lines += '- No file-level entries were parsed from report; see raw report.'
            }
        }
    }

    Add-Content -Path $SummaryPath -Value ($lines -join [Environment]::NewLine)
}

$resolvedRepoRoot = Resolve-RepoRootPath -PathOverride $RepoRoot
$tasksPathResolved = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $TasksPath
$reportsRootResolved = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $ReportsRoot
$statusPathResolved = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $StatusPath

Initialize-Directory -Path $reportsRootResolved
Initialize-Directory -Path (Split-Path -Path $statusPathResolved -Parent)

if (-not (Test-Path -Path $tasksPathResolved -PathType Leaf)) {
    throw "VI Analyzer tasks file not found: $tasksPathResolved"
}

$tasksDoc = Get-Content -Path $tasksPathResolved -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$tasks = @($tasksDoc.tasks)
if (-not $tasks -or $tasks.Count -eq 0) {
    throw "VI Analyzer tasks file contains no tasks: $tasksPathResolved"
}

$versionHelperPath = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewExeHelperPath = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWExecutablePath.ps1'
$portContractHelperPath = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWCliPortContract.ps1'
foreach ($helperPath in @($versionHelperPath, $labviewExeHelperPath, $portContractHelperPath)) {
    if (-not (Test-Path -Path $helperPath -PathType Leaf)) {
        throw "Required helper script not found: $helperPath"
    }
}

. $versionHelperPath
. $labviewExeHelperPath
. $portContractHelperPath

$labviewInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
$resolvedLabVIEWVersionRaw = [string]$labviewInfo.Raw
$resolvedLabVIEWYear = [string]$labviewInfo.Year
if ([string]::IsNullOrWhiteSpace($resolvedLabVIEWYear)) {
    throw "LabVIEW version year could not be resolved from .lvversion."
}

$labviewExecutablePath = Resolve-LabVIEWExecutablePath -VersionYear $resolvedLabVIEWYear -Bitness $SupportedBitness
$portResolution = Resolve-LabVIEWCliPortFromContract `
    -RepoRoot $resolvedRepoRoot `
    -LabVIEWVersion $resolvedLabVIEWVersionRaw `
    -Bitness $SupportedBitness `
    -LabVIEWExecutablePath $labviewExecutablePath

$labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue
if (-not $labviewCliCommand) {
    throw "LabVIEWCLI is not available on PATH."
}

Write-Host ("Resolved LabVIEW: raw={0}, year={1}, bitness={2}" -f $resolvedLabVIEWVersionRaw, $resolvedLabVIEWYear, $SupportedBitness)
Write-Host ("LabVIEW executable: {0}" -f $labviewExecutablePath)
Write-Host ("Using LabVIEWCLI port {0} (source: {1})" -f $portResolution.PortNumber, $portResolution.Source)
Write-Host ("Running VI Analyzer tasks from: {0}" -f $tasksPathResolved)

$taskResults = New-Object 'System.Collections.Generic.List[object]'
$overallSuccess = $true

foreach ($task in $tasks) {
    $taskId = [string]$task.id
    $taskConfigPath = [string]$task.config_path
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw "VI Analyzer task is missing required field 'id' in $tasksPathResolved"
    }
    if ([string]::IsNullOrWhiteSpace($taskConfigPath)) {
        throw "VI Analyzer task '$taskId' is missing required field 'config_path' in $tasksPathResolved"
    }

    $configPathResolved = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $taskConfigPath
    if (-not (Test-Path -Path $configPathResolved -PathType Leaf)) {
        throw "VI Analyzer config not found for task '$taskId': $configPathResolved"
    }

    $safeTaskId = ($taskId -replace '[^A-Za-z0-9_.-]', '-')
    $reportPath = Join-Path $reportsRootResolved ("vi-analyzer-{0}.txt" -f $safeTaskId)
    if (Test-Path -Path $reportPath -PathType Leaf) {
        Remove-Item -Path $reportPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host ("=== VI Analyzer task: {0} ===" -f $taskId)
    $start = Get-Date
    $cliArgs = @(
        '-OperationName', 'RunVIAnalyzer',
        '-LabVIEWPath', $labviewExecutablePath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-ConfigPath', $configPathResolved,
        '-ReportPath', $reportPath,
        '-ReportSaveType', 'ASCII',
        '-LogToConsole', 'TRUE',
        '-Headless'
    )

    $rawOutput = & $labviewCliCommand.Source @cliArgs 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $outputLines = @()
    foreach ($entry in @($rawOutput)) {
        if ($null -ne $entry) {
            $line = [string]$entry
            $outputLines += $line
            Write-Host $line
        }
    }
    $durationMs = [int][Math]::Round(((Get-Date) - $start).TotalMilliseconds)

    $cliCounts = Get-LabVIEWCliSummaryCount -Lines $outputLines
    $reportText = Get-ViAnalyzerReportText -ReportPath $reportPath
    $reportCounts = Get-ViAnalyzerReportCount -ReportText $reportText
    $counts = Join-ViAnalyzerCount -CliCounts $cliCounts -ReportCounts $reportCounts
    $failureItems = Get-ViAnalyzerFailureItemList -ReportText $reportText
    $failureFilePaths = Get-OrderedUniqueFilePathList -Items $failureItems

    $failureReasons = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-Path -Path $reportPath -PathType Leaf)) {
        $failureReasons.Add('Report file missing.') | Out-Null
    }
    if ($exitCode -ne 0) {
        $failureReasons.Add(("Non-zero exit code: {0}" -f $exitCode)) | Out-Null
    }
    foreach ($requiredKey in @('passed', 'failed', 'skipped', 'vi_unloadable', 'test_unloadable', 'test_unrunnable', 'test_error', 'analyzed_total')) {
        if ($null -eq $counts[$requiredKey]) {
            $failureReasons.Add(("Missing parsed count: {0}" -f $requiredKey)) | Out-Null
        }
    }
    if ($null -ne $counts.analyzed_total -and [int]$counts.analyzed_total -le 0) {
        $failureReasons.Add('No tests were analyzed (analyzed_total = 0).') | Out-Null
    }
    if ($null -ne $counts.failed -and [int]$counts.failed -gt 0) {
        $failureReasons.Add(("Failed tests count is {0}" -f $counts.failed)) | Out-Null
    }
    if ($null -ne $counts.vi_unloadable -and [int]$counts.vi_unloadable -gt 0) {
        $failureReasons.Add(("VI unloadable count is {0}" -f $counts.vi_unloadable)) | Out-Null
    }
    if ($null -ne $counts.test_unloadable -and [int]$counts.test_unloadable -gt 0) {
        $failureReasons.Add(("Test unloadable count is {0}" -f $counts.test_unloadable)) | Out-Null
    }
    if ($null -ne $counts.test_unrunnable -and [int]$counts.test_unrunnable -gt 0) {
        $failureReasons.Add(("Test unrunnable count is {0}" -f $counts.test_unrunnable)) | Out-Null
    }
    if ($null -ne $counts.test_error -and [int]$counts.test_error -gt 0) {
        $failureReasons.Add(("Test error count is {0}" -f $counts.test_error)) | Out-Null
    }

    $taskSucceeded = $failureReasons.Count -eq 0
    if (-not $taskSucceeded) {
        $overallSuccess = $false
        if ($failureItems.Count -gt 0) {
            Write-Host ("Failure details for task '{0}':" -f $taskId)
            foreach ($filePath in $failureFilePaths) {
                Write-Host ("- File: {0}" -f $filePath)
                foreach ($item in @($failureItems | Where-Object { $_.file_path -eq $filePath })) {
                    Write-Host ("  - [{0}] {1}: {2}" -f $item.section, $item.check_name, $item.message)
                }
            }
        } else {
            Write-Host "No file-level entries were parsed from report; see raw report."
        }
    }

    $taskResults.Add([pscustomobject]@{
            id              = $taskId
            config_path     = $configPathResolved
            report_path     = $reportPath
            exit_code       = $exitCode
            duration_ms     = $durationMs
            succeeded       = $taskSucceeded
            counts          = [pscustomobject]$counts
            failure_reasons = @($failureReasons)
            failure_items   = @($failureItems)
            failure_file_paths = @($failureFilePaths)
        }) | Out-Null
}

$status = [ordered]@{
    generated_utc    = (Get-Date).ToUniversalTime().ToString('o')
    repo_root        = $resolvedRepoRoot
    tasks_path       = $tasksPathResolved
    reports_root     = $reportsRootResolved
    overall_success  = $overallSuccess
    task_count       = $taskResults.Count
    labview          = [ordered]@{
        raw             = $resolvedLabVIEWVersionRaw
        year            = $resolvedLabVIEWYear
        minor_revision  = [int]$labviewInfo.MinorRevision
        bitness         = $SupportedBitness
        executable_path = $labviewExecutablePath
    }
    port             = [ordered]@{
        number        = [int]$portResolution.PortNumber
        source        = [string]$portResolution.Source
        contract_path = [string]$portResolution.ContractPath
        ini_path      = [string]$portResolution.IniPath
    }
    task_results     = $taskResults
}

$status | ConvertTo-Json -Depth 10 | Out-File -FilePath $statusPathResolved -Encoding utf8

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    Add-ViAnalyzerSummary `
        -SummaryPath $env:GITHUB_STEP_SUMMARY `
        -TaskResults $taskResults `
        -OverallSuccess $overallSuccess `
        -ReportsRoot $reportsRootResolved `
        -StatusPath $statusPathResolved
}

Write-Host ("VI Analyzer status written to {0}" -f $statusPathResolved)
if (-not $overallSuccess) {
    $failedTasks = @($taskResults | Where-Object { -not $_.succeeded })
    $labels = if ($failedTasks.Count -gt 0) { ($failedTasks | ForEach-Object { $_.id }) -join ', ' } else { 'unknown' }
    throw ("VI Analyzer failed for task(s): {0}. See {1}" -f $labels, $statusPathResolved)
}

Write-Host ("VI Analyzer completed successfully ({0} task(s))." -f $taskResults.Count)
