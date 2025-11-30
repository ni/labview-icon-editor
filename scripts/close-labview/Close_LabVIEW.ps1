<#
.SYNOPSIS
    Gracefully closes a running LabVIEW instance.

.DESCRIPTION
    Utilizes g-cli's QuitLabVIEW command to shut down the specified LabVIEW
    version and bitness, ensuring the application exits cleanly.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to close (e.g., "2021").

.PARAMETER SupportedBitness
    Bitness of the LabVIEW instance ("32" or "64").

.EXAMPLE
    .\Close_LabVIEW.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64"
#>
param(
    [Parameter(Mandatory)]
    [Alias('MinimumSupportedLVVersion')]
    [string]$Package_LabVIEW_Version,
    [Parameter(Mandatory)]
    [ValidateSet("32","64")]
    [string]$SupportedBitness,
    [int]$TimeoutSeconds = 60,
    [switch]$KillLabVIEW,
    [int]$KillTimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'

function Invoke-SafeQuitLabVIEW {
    param(
        [string]$Version,
        [string]$Bitness,
        [int]$TimeoutSec,
        [switch]$Kill,
        [int]$KillTimeoutSec
    )

    $gcliCmd = Get-Command g-cli -ErrorAction SilentlyContinue
    if (-not $gcliCmd) {
        throw "g-cli.exe not found in PATH."
    }

    $gcliPath = $gcliCmd.Source
    $gcliArgs = @(
        "--lv-ver", $Version,
        "--arch",   $Bitness,
        "QuitLabVIEW"
    )
    if ($Kill) {
        $gcliArgs += @("--kill", "--kill-timeout", ([int][TimeSpan]::FromSeconds([Math]::Max(0,$KillTimeoutSec)).TotalMilliseconds))
    }

    Write-Information ("g-cli path: {0}" -f $gcliPath) -InformationAction Continue
    Write-Information ("Executing: g-cli {0}" -f ($gcliArgs -join ' ')) -InformationAction Continue

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $gcliPath
    foreach ($arg in $gcliArgs) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    if (-not $proc) { throw "Failed to start g-cli QuitLabVIEW." }
    $timedOut = $false
    if ($TimeoutSec -gt 0) {
        $timedOut = -not $proc.WaitForExit([Math]::Max(1,$TimeoutSec) * 1000)
    } else {
        $proc.WaitForExit()
    }
    if ($timedOut) {
        try { $proc.Kill($true) } catch {}
    }
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $exitCode = if ($timedOut) { 124 } else { $proc.ExitCode }

    # echo all output for log visibility
    ($stdout -split "`r?`n" | Where-Object { $_ -ne '' }) | ForEach-Object { Write-Information $_ -InformationAction Continue }
    if ($stderr) { Write-Verbose $stderr }

    $joined = ($stdout + " " + $stderr)
    if ($exitCode -eq 0) { return $exitCode, $stdout, $stderr, $timedOut }

    if ($joined -match 'not (currently )?running' -or $joined -match 'does not appear to be running') {
        Write-Information "LabVIEW $Version ($Bitness-bit) was not running; nothing to close." -InformationAction Continue
        return 0, $stdout, $stderr, $timedOut
    }

    if ($timedOut) {
        Write-Warning ("g-cli QuitLabVIEW timed out after {0}s (exit {1})." -f $TimeoutSec, $exitCode)
        return $exitCode, $stdout, $stderr, $timedOut
    }

    Write-Warning "g-cli QuitLabVIEW failed with exit code $exitCode."
    return $exitCode, $stdout, $stderr, $timedOut
}

$script:RetrySleepMs = 1000
function Stop-LabVIEWProcesses {
    param([string]$Version,[string]$Bitness)
    $killed = 0
    $procs = @(Get-LabVIEWProcesses -Version $Version -Bitness $Bitness)
    foreach ($p in $procs) {
        try { $p.Kill($true); $killed++ } catch { }
    }
    # As a last resort, ask taskkill to terminate the image
    if ($killed -eq 0 -and $procs.Count -gt 0) {
        try { taskkill /F /T /PID $procs[0].Id | Out-Null; $killed++ } catch { }
    }
    return $killed
}

try {
    $exit, $stdout, $stderr, $timedOut = Invoke-SafeQuitLabVIEW -Version $Package_LabVIEW_Version -Bitness $SupportedBitness -TimeoutSec $TimeoutSeconds -Kill:$KillLabVIEW -KillTimeoutSec $KillTimeoutSeconds
}
catch {
    Write-Error $_.Exception.Message
    $exit = 1
    $stdout = $stdout ?? ''
    $stderr = $stderr ?? $_.Exception.Message
}

# Fallback check/kill if timeout or non-zero exit
function Get-LabVIEWProcesses {
    param([string]$Version,[string]$Bitness)
    $pattern = if ($Bitness -eq '32') { "*Program Files (x86)*\\LabVIEW $Version\\LabVIEW.exe" } else { "*Program Files*\\LabVIEW $Version\\LabVIEW.exe" }
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -like $pattern
    }
}

$killed = 0
# Retry loop: attempt graceful close, then force kill, ensure processes are gone.
for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Milliseconds $script:RetrySleepMs
    $procs = @(Get-LabVIEWProcesses -Version $Package_LabVIEW_Version -Bitness $SupportedBitness)
    if ($procs.Count -eq 0) { break }
    $killed += Stop-LabVIEWProcesses -Version $Package_LabVIEW_Version -Bitness $SupportedBitness
}
$procsAfter = @(Get-LabVIEWProcesses -Version $Package_LabVIEW_Version -Bitness $SupportedBitness)
if ($procsAfter.Count -eq 0) {
    # Treat as success if nothing remains
    $stdout = ($stdout, "Fallback kill applied: $killed", "Processes after close: 0") -join "`n"
    $exit = 0
}

$summary = [pscustomobject]@{
    bitness   = $SupportedBitness
    lvVersion = $Package_LabVIEW_Version
    exit      = $exit
    stdout    = $stdout
    stderr    = $stderr
    timedOut  = $timedOut
    killed    = $killed
}
$summary | ConvertTo-Json -Depth 4 | Write-Output

if ($exit -eq 0) {
    Write-Information "LabVIEW $Package_LabVIEW_Version ($SupportedBitness-bit) closed or not running." -InformationAction Continue
    exit 0
}

exit $exit
