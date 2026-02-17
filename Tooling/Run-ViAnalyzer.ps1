#Requires -Version 7.0
<#
.SYNOPSIS
    Runs LabVIEWCLI VI Analyzer tasks through the Linux container parity worker.

.DESCRIPTION
    Executes Tooling/container-parity/run-vi-analyzer-linux.sh in a LabVIEW Linux
    container, then parses generated ASCII reports from tasks listed in
    Tooling/vi-analyzer/tasks.json and enforces deterministic pass/fail rules.
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
    [string]$StatusPath = 'builds/status/vi-analyzer-summary.json',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ContainerImage = ''
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
    }
    catch {
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

function Convert-ToUnixPath {
    param([string]$Value)

    return ($Value -replace '\\', '/')
}

function Resolve-ContainerRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$AbsolutePath,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $targetFull = [System.IO.Path]::GetFullPath($AbsolutePath)

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $rootWithSeparator = if ($repoRootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $repoRootFull
    }
    else {
        $repoRootFull + [System.IO.Path]::DirectorySeparatorChar
    }

    if (-not $targetFull.Equals($repoRootFull, $comparison) -and -not $targetFull.StartsWith($rootWithSeparator, $comparison)) {
        throw ("{0} must resolve inside repo root for container execution. RepoRoot='{1}' Path='{2}'" -f $Label, $repoRootFull, $targetFull)
    }

    $relative = [System.IO.Path]::GetRelativePath($repoRootFull, $targetFull)
    if ($relative.StartsWith('..', [System.StringComparison]::Ordinal)) {
        throw ("{0} resolved outside repo root after normalization: {1}" -f $Label, $targetFull)
    }

    return Convert-ToUnixPath -Value $relative
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

function Get-ViAnalyzerReportCount {
    param([string]$ReportPath)

    if (-not (Test-Path -Path $ReportPath -PathType Leaf)) {
        return $null
    }

    $text = Get-Content -Path $ReportPath -Raw -ErrorAction Stop
    $counts = [ordered]@{
        passed          = Get-CountFromText -Text $text -Pattern '^\s*Passed Tests\s+(?<n>\d+)\s*$'
        failed          = Get-CountFromText -Text $text -Pattern '^\s*Failed Tests\s+(?<n>\d+)\s*$'
        skipped         = Get-CountFromText -Text $text -Pattern '^\s*Skipped Tests\s+(?<n>\d+)\s*$'
        vi_unloadable   = Get-CountFromText -Text $text -Pattern '^\s*VI not loadable\s+(?<n>\d+)\s*$'
        test_unloadable = Get-CountFromText -Text $text -Pattern '^\s*Test not loadable\s+(?<n>\d+)\s*$'
        test_unrunnable = Get-CountFromText -Text $text -Pattern '^\s*Test not runnable\s+(?<n>\d+)\s*$'
        test_error      = Get-CountFromText -Text $text -Pattern '^\s*Test error out\s+(?<n>\d+)\s*$'
    }

    if ($null -ne $counts.passed -and $null -ne $counts.failed -and $null -ne $counts.skipped) {
        $counts['analyzed_total'] = ([int]$counts.passed + [int]$counts.failed + [int]$counts.skipped)
    }
    else {
        $counts['analyzed_total'] = $null
    }

    return $counts
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
        [string]$StatusPath,
        [int]$WorkerExitCode,
        [string]$ContainerImageValue
    )

    if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
        return
    }

    $lines = @()
    $lines += '### VI Analyzer (LabVIEWCLI, Linux container)'
    $lines += ''
    $lines += ("- Overall result: **{0}**" -f $(if ($OverallSuccess) { 'pass' } else { 'fail' }))
    $lines += ('- Worker container image: `{0}`' -f $ContainerImageValue)
    $lines += ('- Worker exit code: `{0}`' -f $WorkerExitCode)
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

    Add-Content -Path $SummaryPath -Value ($lines -join [Environment]::NewLine)
}

function Invoke-LinuxAnalyzerWorker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,
        [Parameter(Mandatory = $true)]
        [string]$TasksPathInContainer,
        [Parameter(Mandatory = $true)]
        [string]$ReportsRootInContainer,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWYear,
        [Parameter(Mandatory = $true)]
        [string]$Image
    )

    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCommand) {
        throw 'docker was not found on PATH; Linux VI Analyzer worker requires Docker.'
    }

    $workerScriptHost = Join-Path $RepoRootPath 'Tooling/container-parity/run-vi-analyzer-linux.sh'
    if (-not (Test-Path -Path $workerScriptHost -PathType Leaf)) {
        throw "Linux VI Analyzer worker script was not found: $workerScriptHost"
    }

    $workerScriptContainer = '/workspace/Tooling/container-parity/run-vi-analyzer-linux.sh'
    $commandText = "chmod +x $workerScriptContainer && $workerScriptContainer"

    $dockerArgs = @(
        'run', '--rm',
        '-v', ("{0}:/workspace" -f $RepoRootPath),
        '-w', '/workspace',
        '-e', 'LVIE_REPO_ROOT=/workspace',
        '-e', ("LVIE_VI_ANALYZER_TASKS_PATH={0}" -f $TasksPathInContainer),
        '-e', ("LVIE_VI_ANALYZER_REPORTS_ROOT={0}" -f $ReportsRootInContainer),
        '-e', ("LVIE_VI_ANALYZER_LABVIEW_YEAR={0}" -f $LabVIEWYear),
        $Image,
        'bash', '-lc', $commandText
    )

    Write-Host "Running Linux VI Analyzer worker container..."
    Write-Host ("Container image: {0}" -f $Image)
    Write-Host ("Tasks path (container): {0}" -f $TasksPathInContainer)
    Write-Host ("Reports root (container): {0}" -f $ReportsRootInContainer)

    & $dockerCommand.Source @dockerArgs
    return (if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE })
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
if (-not (Test-Path -Path $versionHelperPath -PathType Leaf)) {
    throw "Required helper script not found: $versionHelperPath"
}
. $versionHelperPath
$labviewInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
$resolvedLabVIEWVersionRaw = [string]$labviewInfo.Raw
$resolvedLabVIEWYear = [string]$labviewInfo.Year
if ([string]::IsNullOrWhiteSpace($resolvedLabVIEWYear)) {
    throw 'LabVIEW year could not be resolved from .lvversion.'
}

$tasksPathRelativeUnix = Resolve-ContainerRelativePath -RepoRoot $resolvedRepoRoot -AbsolutePath $tasksPathResolved -Label 'TasksPath'
$reportsRootRelativeUnix = Resolve-ContainerRelativePath -RepoRoot $resolvedRepoRoot -AbsolutePath $reportsRootResolved -Label 'ReportsRoot'
$tasksPathInContainer = "/workspace/{0}" -f $tasksPathRelativeUnix
$reportsRootInContainer = "/workspace/{0}" -f $reportsRootRelativeUnix

$resolvedContainerImage = if (-not [string]::IsNullOrWhiteSpace($ContainerImage)) {
    $ContainerImage
}
elseif (-not [string]::IsNullOrWhiteSpace($env:LABVIEW_LINUX_IMAGE)) {
    $env:LABVIEW_LINUX_IMAGE
}
else {
    "nationalinstruments/labview:{0}q1-linux" -f $resolvedLabVIEWYear
}

$dockerExitCode = Invoke-LinuxAnalyzerWorker `
    -RepoRootPath $resolvedRepoRoot `
    -TasksPathInContainer $tasksPathInContainer `
    -ReportsRootInContainer $reportsRootInContainer `
    -LabVIEWYear $resolvedLabVIEWYear `
    -Image $resolvedContainerImage

$taskResults = New-Object 'System.Collections.Generic.List[object]'
$overallSuccess = ($dockerExitCode -eq 0)
$workerFailed = ($dockerExitCode -ne 0)

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
    $counts = Get-ViAnalyzerReportCount -ReportPath $reportPath

    $failureReasons = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-Path -Path $reportPath -PathType Leaf)) {
        $failureReasons.Add('Report file missing.') | Out-Null
    }

    if ($null -eq $counts) {
        $failureReasons.Add('Report counts were not parsed.') | Out-Null
    }
    else {
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
    }

    if ($workerFailed -and $failureReasons.Count -eq 0) {
        $failureReasons.Add(("Linux analyzer worker exited with code {0}." -f $dockerExitCode)) | Out-Null
    }

    $taskSucceeded = $failureReasons.Count -eq 0
    if (-not $taskSucceeded) {
        $overallSuccess = $false
    }

    $taskResults.Add([pscustomobject]@{
            id              = $taskId
            config_path     = $configPathResolved
            report_path     = $reportPath
            exit_code       = if ($taskSucceeded) { 0 } else { 1 }
            succeeded       = $taskSucceeded
            counts          = [pscustomobject]$counts
            failure_reasons = @($failureReasons)
        }) | Out-Null
}

$status = [ordered]@{
    generated_utc    = (Get-Date).ToUniversalTime().ToString('o')
    repo_root        = $resolvedRepoRoot
    tasks_path       = $tasksPathResolved
    reports_root     = $reportsRootResolved
    overall_success  = $overallSuccess
    task_count       = $taskResults.Count
    worker           = [ordered]@{
        mode         = 'linux-container'
        image        = $resolvedContainerImage
        exit_code    = $dockerExitCode
    }
    labview          = [ordered]@{
        raw             = $resolvedLabVIEWVersionRaw
        year            = $resolvedLabVIEWYear
        minor_revision  = [int]$labviewInfo.MinorRevision
        bitness         = $SupportedBitness
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
        -StatusPath $statusPathResolved `
        -WorkerExitCode $dockerExitCode `
        -ContainerImageValue $resolvedContainerImage
}

Write-Host ("VI Analyzer status written to {0}" -f $statusPathResolved)
if (-not $overallSuccess) {
    $failedTasks = @($taskResults | Where-Object { -not $_.succeeded })
    $labels = if ($failedTasks.Count -gt 0) { ($failedTasks | ForEach-Object { $_.id }) -join ', ' } else { 'worker' }
    throw ("VI Analyzer failed for task(s): {0}. See {1}" -f $labels, $statusPathResolved)
}

Write-Host ("VI Analyzer completed successfully ({0} task(s))." -f $taskResults.Count)
