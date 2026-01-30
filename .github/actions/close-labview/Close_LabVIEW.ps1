<#
.SYNOPSIS
    Gracefully closes a running LabVIEW instance.

.DESCRIPTION
    Utilizes g-cli's QuitLabVIEW command to shut down the specified LabVIEW
    version and bitness, ensuring the application exits cleanly.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW instance ("32" or "64").

.EXAMPLE
    .\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"
#>
param(
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',
    [string]$SupportedBitness,
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 120,
    [string]$MetricsPath
)

$ErrorActionPreference = 'Stop'
$scriptStart = Get-Date
$metricsPathResolved = if ($MetricsPath) { $MetricsPath } elseif ($env:LABVIEW_CLOSE_METRICS_PATH) { $env:LABVIEW_CLOSE_METRICS_PATH } else { $null }

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
    "{0},{1},{2},{3},{4},{5}" -f $timestamp, $MinimumSupportedLVVersion, $SupportedBitness, $HadProcess, $Outcome, $duration | Add-Content -Path $metricsPathResolved
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

function Invoke-SafeQuitLabVIEW {
    param(
        [string]$Version,
        [string]$Bitness
    )

    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw "g-cli.exe not found in PATH."
    }

    $args = @(
        "--lv-ver", $Version,
        "--arch",   $Bitness,
        "QuitLabVIEW"
    )

    Write-Host ("Executing: g-cli {0}" -f ($args -join ' '))
    $output   = & g-cli @args 2>&1
    $exitCode = $LASTEXITCODE

    # echo all output for log visibility
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -eq 0) { return }

    $joined = ($output -join ' ')
    if ($joined -match 'not (currently )?running' -or $joined -match 'does not appear to be running') {
        Write-Host "LabVIEW $Version ($Bitness-bit) was not running; nothing to close."
        return
    }

    throw "g-cli QuitLabVIEW failed with exit code $exitCode."
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
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath -notmatch [regex]::Escape((Get-LabVIEWInstallRoot -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness)) }

$targetBefore = Get-TargetLabVIEWProcesses -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness
if (-not $targetBefore -or $targetBefore.Count -eq 0) {
    if ($otherInstances) {
        Write-Host "No matching LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) instance found. Other LabVIEW instances are running; skipping QuitLabVIEW."
    }
    else {
        Write-Host "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) closed or not running."
    }
    Write-CloseMetric -Outcome 'skipped' -HadProcess $false
    exit 0
}

$closeOutcome = 'quit'
try {
    Invoke-SafeQuitLabVIEW -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness
}
catch {
    Write-Warning ("QuitLabVIEW failed: {0}" -f $_.Exception.Message)
    $closeOutcome = 'error'
}

if (-not (Wait-ForLabVIEWExit -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness -TimeoutSeconds $TimeoutSeconds)) {
    $targets = Get-TargetLabVIEWProcesses -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness
    if ($targets -and $targets.Count -gt 0) {
        Write-Warning "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) did not exit in time; force closing by PID."
        foreach ($proc in $targets) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to stop LabVIEW PID {0}: {1}" -f $proc.ProcessId, $_.Exception.Message)
            }
        }

        if (-not (Wait-ForLabVIEWExit -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness -TimeoutSeconds 15)) {
            Write-Error "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) did not exit after forced close."
            Write-CloseMetric -Outcome 'error' -HadProcess $true
            exit 1
        }
        $closeOutcome = 'forced'
    }
}

Write-Host "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) closed or not running."
Write-CloseMetric -Outcome $closeOutcome -HadProcess $true
