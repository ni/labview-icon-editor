<#
.SYNOPSIS
    Gracefully closes a running LabVIEW instance.

.DESCRIPTION
    Uses LabVIEWCLI CloseLabVIEW on the strict port-contract path to shut down
    the specified LabVIEW version and bitness, ensuring deterministic close
    semantics for LabVIEWCLI-managed sessions.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    Bitness of the LabVIEW instance ("32" or "64").

.EXAMPLE
    .\Close_LabVIEW.ps1 -SupportedBitness "64"
#>
param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',
    [string]$SupportedBitness,
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 120,
    [string]$MetricsPath
)

$ErrorActionPreference = 'Stop'
$scriptStart = Get-Date
$metricsPathResolved = if ($MetricsPath) { $MetricsPath } elseif ($env:LABVIEW_CLOSE_METRICS_PATH) { $env:LABVIEW_CLOSE_METRICS_PATH } else { $null }
$repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..')).Path
$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

function Ensure-CsvHeader {
    param(
        [string]$Path,
        [string]$Header
    )

    if (-not $Path) {
        return
    }

    $dir = Split-Path -Parent -Path $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -Path $Path)) {
        $Header | Set-Content -Path $Path
    }
}

function Write-CloseMetric {
    param(
        [string]$Outcome,
        [bool]$HadProcess
    )

    if (-not $metricsPathResolved) {
        return
    }

    Ensure-CsvHeader -Path $metricsPathResolved -Header 'timestamp,version,bitness,had_process_before,outcome,duration_seconds'
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $duration = [Math]::Round(((Get-Date) - $scriptStart).TotalSeconds, 2)
    "{0},{1},{2},{3},{4},{5}" -f $timestamp, $labviewYear, $SupportedBitness, $HadProcess, $Outcome, $duration | Add-Content -Path $metricsPathResolved
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    if ($Bitness -eq '32') {
        return "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
    }
    return "C:\Program Files\National Instruments\LabVIEW $Version"
}

function Get-TargetLabVIEWProcesses {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $installRoot = Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness
    $processes = @()
    try {
        $processes = Get-CimInstance Win32_Process -Filter "Name='LabVIEW.exe'" -ErrorAction Stop
    } catch {
        $processes = @()
    }

    if (-not $processes) {
        return @()
    }

    return $processes | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)
    }
}

function Resolve-LabVIEWCliPortForClose {
    param(
        [string]$RepoRoot,
        [string]$Version,
        [ValidateSet('32', '64')]
        [string]$Bitness,
        [string]$LabVIEWExecutablePath
    )

    $portContractHelper = Join-Path $RepoRoot 'Tooling\support\LabVIEWCliPortContract.ps1'
    if (-not (Test-Path -Path $portContractHelper -PathType Leaf)) {
        throw "LabVIEWCliPortContract helper not found at $portContractHelper"
    }
    . $portContractHelper

    return Resolve-LabVIEWCliPortFromContract `
        -RepoRoot $RepoRoot `
        -LabVIEWVersion $Version `
        -Bitness $Bitness `
        -LabVIEWExecutablePath $LabVIEWExecutablePath
}

function Invoke-SafeCloseLabVIEWViaLabVIEWCLI {
    param(
        [string]$RepoRoot,
        [string]$Version,
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    $labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue
    if (-not $labviewCliCommand) {
        throw "LabVIEWCLI is not available on PATH."
    }

    $installRoot = Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness
    $labviewExecutablePath = Join-Path $installRoot 'LabVIEW.exe'
    if (-not (Test-Path -Path $labviewExecutablePath -PathType Leaf)) {
        throw "LabVIEW executable not found at $labviewExecutablePath"
    }

    $portResolution = Resolve-LabVIEWCliPortForClose `
        -RepoRoot $RepoRoot `
        -Version $Version `
        -Bitness $Bitness `
        -LabVIEWExecutablePath $labviewExecutablePath

    Write-Host ("Using LabVIEWCLI close port {0} (source: {1})" -f $portResolution.PortNumber, $portResolution.Source)
    $cliArgs = @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'CloseLabVIEW',
        '-LabVIEWPath', $labviewExecutablePath,
        '-PortNumber', $portResolution.PortNumber.ToString()
    )

    Write-Host ("Executing: {0} {1}" -f $labviewCliCommand.Source, ($cliArgs -join ' '))
    $output = & $labviewCliCommand.Source @cliArgs 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }

    # echo all output for log visibility
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -eq 0) { return }
    throw "LabVIEWCLI CloseLabVIEW failed with exit code $exitCode."
}

function Wait-ForLabVIEWExit {
    param(
        [string]$Version,
        [string]$Bitness,
        [int]$TimeoutSeconds = 30
    )

    $installRoot = Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $running = @()
        try {
            $running = Get-CimInstance Win32_Process -Filter "Name='LabVIEW.exe'" -ErrorAction Stop
        } catch {
            $running = @()
        }

        if ($running.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($installRoot)) {
            $running = $running | Where-Object {
                $_.ExecutablePath -and $_.ExecutablePath.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)
            }
        }

        if (-not $running -or $running.Count -eq 0) {
            $running = Get-Process -Name LabVIEW -ErrorAction SilentlyContinue
            if ($running -and -not [string]::IsNullOrWhiteSpace($installRoot)) {
                $filtered = @()
                foreach ($process in $running) {
                    $path = $null
                    try { $path = $process.Path } catch { }
                    if ($path -and $path.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $filtered += $process
                    }
                }
                if ($filtered.Count -gt 0) {
                    $running = $filtered
                }
            }
        }

        if (-not $running) {
            return $true
        }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    return $false
}

$otherInstances = Get-CimInstance Win32_Process -Filter "Name='LabVIEW.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath -notmatch [regex]::Escape((Get-LabVIEWInstallRoot -Version $labviewYear -Bitness $SupportedBitness)) }

$targetBefore = Get-TargetLabVIEWProcesses -Version $labviewYear -Bitness $SupportedBitness
if (-not $targetBefore -or $targetBefore.Count -eq 0) {
    if ($otherInstances) {
        Write-Host "No matching LabVIEW $labviewYear ($SupportedBitness-bit) instance found. Other LabVIEW instances are running; skipping CloseLabVIEW."
    }
    else {
        Write-Host "LabVIEW $labviewYear ($SupportedBitness-bit) closed or not running."
    }
    Write-CloseMetric -Outcome 'skipped' -HadProcess $false
    exit 0
}

$closeOutcome = 'quit'
try {
    Invoke-SafeCloseLabVIEWViaLabVIEWCLI -RepoRoot $repoRoot -Version $labviewYear -Bitness $SupportedBitness
}
catch {
    Write-Warning ("CloseLabVIEW failed: {0}" -f $_.Exception.Message)
    $closeOutcome = 'error'
}

if (-not (Wait-ForLabVIEWExit -Version $labviewYear -Bitness $SupportedBitness -TimeoutSeconds $TimeoutSeconds)) {
    $targets = Get-TargetLabVIEWProcesses -Version $labviewYear -Bitness $SupportedBitness
    if ($targets -and $targets.Count -gt 0) {
        Write-Warning "LabVIEW $labviewYear ($SupportedBitness-bit) did not exit in time; force closing by PID."
        foreach ($proc in $targets) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to stop LabVIEW PID {0}: {1}" -f $proc.ProcessId, $_.Exception.Message)
            }
        }

        if (-not (Wait-ForLabVIEWExit -Version $labviewYear -Bitness $SupportedBitness -TimeoutSeconds 15)) {
            Write-Error "LabVIEW $labviewYear ($SupportedBitness-bit) did not exit after forced close."
            Write-CloseMetric -Outcome 'error' -HadProcess $true
            exit 1
        }
        $closeOutcome = 'forced'
    }
}

Write-Host "LabVIEW $labviewYear ($SupportedBitness-bit) closed or not running."
Write-CloseMetric -Outcome $closeOutcome -HadProcess $true

