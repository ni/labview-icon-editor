#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('2021')]
    [string]$LVVersion,

    [Parameter(Mandatory)]
    [ValidateSet('32', '64')]
    [string]$Arch,

    [string]$RepoRoot,

    [string]$CsvFileName = 'Icon_Editor_Files_In_LV_Installation_Diagnostics.csv',

    [string]$ProjectFile = '',

    [string]$SummaryTitle = 'Icon Editor Files in LabVIEW Installation'
)

$ErrorActionPreference = 'Stop'

$headers = @('File Path', 'Bytes', 'Last modified')
$diagnosticsBaseName = 'Icon_Editor_Files_In_LV_Installation_Diagnostics'
$defaultCsvName = "$diagnosticsBaseName.csv"

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE) -and (Test-Path -Path $env:GITHUB_WORKSPACE)) {
        return (Resolve-Path -Path $env:GITHUB_WORKSPACE).Path
    }

    $fallback = Join-Path $PSScriptRoot '..\..\..'
    if (-not (Test-Path -Path $fallback)) {
        throw "Unable to resolve repository root. Provide -RepoRoot."
    }

    return (Resolve-Path -Path $fallback).Path
}

function Resolve-CsvPath {
    param(
        [string]$Root,
        [string]$FileName
    )

    if ([System.IO.Path]::IsPathRooted($FileName)) {
        return $FileName
    }

    return (Join-Path $Root $FileName)
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $candidates = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths = @("HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version")
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths = @("HKLM:\SOFTWARE\National Instruments\LabVIEW $Version")
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Invoke-IconEditorDiagnostics {
    param(
        [string]$ViPath,
        [bool]$NoLaunch = $false,
        [int]$ConnectTimeoutMs = 0
    )

    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw "g-cli.exe not found in PATH."
    }

    $gCliArgs = @(
        '--lv-ver', $LVVersion,
        '--arch', $Arch
    )

    if ($NoLaunch) {
        $gCliArgs += '--no-launch'
    }

    if ($ConnectTimeoutMs -gt 0) {
        $gCliArgs += @('--connect-timeout', $ConnectTimeoutMs)
    }

    $gCliArgs += @('-v', $ViPath)

    Write-Host ("Executing: g-cli {0}" -f ($gCliArgs -join ' '))
    $output = & g-cli @gCliArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "g-cli failed with exit code $exitCode."
    }
}

function Write-StepSummary {
    param(
        [string]$SummaryPath,
        [string]$Title,
        [object[]]$Rows
    )

    if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
        return
    }

    if (-not (Test-Path -Path $SummaryPath)) {
        $null = New-Item -ItemType File -Path $SummaryPath -Force
    }

    Add-Content -Path $SummaryPath -Value ("### {0}" -f $Title)
    Add-Content -Path $SummaryPath -Value ""
    Add-Content -Path $SummaryPath -Value "<details>"
    Add-Content -Path $SummaryPath -Value "<summary>CSV contents</summary>"
    Add-Content -Path $SummaryPath -Value ""
    Add-Content -Path $SummaryPath -Value "| File Path | Bytes | Last modified |"
    Add-Content -Path $SummaryPath -Value "| --- | --- | --- |"

    foreach ($row in $Rows) {
        $filePath = $row.'File Path'
        if ($null -eq $filePath) {
            $filePath = ''
        }
        $safePath = $filePath -replace '\|', '\\|'
        $bytes = $row.Bytes
        $modified = $row.'Last modified'

        Add-Content -Path $SummaryPath -Value ("| {0} | {1} | {2} |" -f $safePath, $bytes, $modified)
    }

    Add-Content -Path $SummaryPath -Value ""
    Add-Content -Path $SummaryPath -Value "</details>"
}

function Write-GitHubOutputs {
    param(
        [string]$CsvPath,
        [int]$RowCount
    )

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        return
    }

    Add-Content -Path $env:GITHUB_OUTPUT -Value ("csv-path={0}" -f $CsvPath)
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("row-count={0}" -f $RowCount)
}

function Safe-QuitLabVIEW {
    try {
        & g-cli --lv-ver $LVVersion --arch $Arch QuitLabVIEW | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW: {0}" -f $_.Exception.Message)
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($CsvFileName)) {
        $CsvFileName = $defaultCsvName
    }
    if ([string]::IsNullOrWhiteSpace($SummaryTitle)) {
        $SummaryTitle = 'Icon Editor Files in LabVIEW Installation'
    }

    $repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
    $viPath = Join-Path $repoRoot 'Tooling\GetPathsToIconEditorFilesInLVInstallationCLI.vi'
    if (-not (Test-Path -Path $viPath)) {
        throw "VI not found: $viPath"
    }

    $csvPath = Resolve-CsvPath -Root $repoRoot -FileName $CsvFileName
    $bitnessCsvName = "{0}_{1}.csv" -f $diagnosticsBaseName, $Arch
    $bitnessCsvNameNoExt = "{0}_{1}" -f $diagnosticsBaseName, $Arch
    $defaultCsvPath = Join-Path $repoRoot $defaultCsvName
    $bitnessCsvPath = Join-Path $repoRoot $bitnessCsvName
    $bitnessCsvPathNoExt = Join-Path $repoRoot $bitnessCsvNameNoExt
    $candidatePaths = @($csvPath, $defaultCsvPath, $bitnessCsvPath, $bitnessCsvPathNoExt) |
        Where-Object { $_ } | Select-Object -Unique
    foreach ($path in $candidatePaths) {
        if (Test-Path -Path $path) {
            Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        }
    }

    Safe-QuitLabVIEW

    $useNoLaunch = $false
    $connectTimeoutMs = 0

    Push-Location $repoRoot
    try {
        Invoke-IconEditorDiagnostics -ViPath $viPath -NoLaunch:$useNoLaunch -ConnectTimeoutMs $connectTimeoutMs
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -Path $csvPath)) {
        $sourcePath = @($bitnessCsvPath, $bitnessCsvPathNoExt, $defaultCsvPath) |
            Where-Object { Test-Path -Path $_ } | Select-Object -First 1
        if ($sourcePath) {
            $csvDir = Split-Path -Path $csvPath -Parent
            if (-not [string]::IsNullOrWhiteSpace($csvDir) -and -not (Test-Path -Path $csvDir)) {
                $null = New-Item -ItemType Directory -Path $csvDir -Force
            }
            Copy-Item -Path $sourcePath -Destination $csvPath -Force
            Write-Host ("Copied diagnostics CSV from {0} to {1}" -f $sourcePath, $csvPath)
        }
    }

    if (-not (Test-Path -Path $csvPath)) {
        throw "CSV file not found: $csvPath"
    }

    $csvPath = (Resolve-Path -Path $csvPath).Path
    $firstLine = Get-Content -Path $csvPath -TotalCount 1
    $headerLine = ($headers -join ',')
    $headerQuoted = '"' + ($headers -join '","') + '"'
    $hasHeader = ($firstLine -eq $headerLine) -or ($firstLine -eq $headerQuoted)

    if ($hasHeader) {
        $rows = Import-Csv -Path $csvPath
    }
    else {
        $rows = Import-Csv -Path $csvPath -Header $headers
    }
    $rows = $rows | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.'File Path') -and
        -not [string]::IsNullOrWhiteSpace($_.Bytes) -and
        -not [string]::IsNullOrWhiteSpace($_.'Last modified')
    }

    if (-not $rows -or $rows.Count -eq 0) {
        throw "CSV file was empty or could not be parsed: $csvPath"
    }

    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

    Write-StepSummary -SummaryPath $env:GITHUB_STEP_SUMMARY -Title $SummaryTitle -Rows $rows
    Write-GitHubOutputs -CsvPath $csvPath -RowCount $rows.Count

    Write-Host ("Diagnostics CSV ready: {0}" -f $csvPath)
}
finally {
    Safe-QuitLabVIEW
}
