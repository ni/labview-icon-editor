#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
    [Parameter(Mandatory)][string]$ProjectFile
)

$ErrorActionPreference = 'Stop'

# ---------- GLOBAL STATE ----------
$Script:HelperExitCode   = 0
$Script:MissingFileLines = @()
$Script:ParsingFailed    = $false

$HelperPath      = Join-Path $PSScriptRoot 'RunMissingCheckWithGCLI.ps1'
$MissingFilePath = Join-Path $PSScriptRoot 'missing_files.txt'

if (-not (Test-Path $HelperPath)) {
    Write-Error "Helper script not found: $HelperPath"
    exit 100
}

# =========================  SETUP  =========================
function Setup {
    Write-Host "=== Setup ==="
    Write-Host "LVVersion  : $LVVersion"
    Write-Host "Arch       : $Arch-bit"
    Write-Host "ProjectFile: $ProjectFile"

    # remove an old results file to avoid stale data
    if (Test-Path $MissingFilePath) {
        Remove-Item $MissingFilePath -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted previous $MissingFilePath"
    }
}

# =====================  MAIN SEQUENCE  =====================
function MainSequence {

    Write-Host "`n=== MainSequence ==="
    Write-Host "Invoking missing‑file check via helper script …`n"

    # call helper & capture any stdout (not strictly needed now)
    & $HelperPath -LVVersion $LVVersion -Arch $Arch -ProjectFile $ProjectFile
    $Script:HelperExitCode = $LASTEXITCODE

    if ($Script:HelperExitCode -ne 0) {
        Write-Error "Helper returned non-zero exit code: $Script:HelperExitCode"
    }

    # -------- read missing_files.txt --------
    if (Test-Path $MissingFilePath) {
        $Script:MissingFileLines = Get-Content $MissingFilePath |
                                   ForEach-Object { $_.Trim() } |
                                   Where-Object { $_ -ne '' }
    }
    else {
        if ($Script:HelperExitCode -ne 0) {
            # helper failed and didn't produce a file – we cannot parse anything
            $Script:ParsingFailed = $true
            return
        }
    }

    # ----------  TABULAR REPORT  ----------
    Write-Host ""
    $col1   = "FilePath"
    $maxLen = if ($Script:MissingFileLines.Count) {
                  ($Script:MissingFileLines | Measure-Object -Maximum Length).Maximum
              } else {
                  $col1.Length
              }

    Write-Host ($col1.PadRight($maxLen)) -ForegroundColor Cyan

    if ($Script:MissingFileLines.Count -eq 0) {
        $msg = "No missing files detected"
        Write-Host ($msg.PadRight($maxLen)) -ForegroundColor Green
    }
    else {
        foreach ($line in $Script:MissingFileLines) {
            Write-Host ($line.PadRight($maxLen)) -ForegroundColor Red
        }
    }
}

# ========================  CLEANUP  ========================
function Cleanup {
    Write-Host "`n=== Cleanup ==="
    # Delete the text file if everything passed
    if ($Script:HelperExitCode -eq 0 -and $Script:MissingFileLines.Count -eq 0) {
        if (Test-Path $MissingFilePath) {
            Remove-Item $MissingFilePath -Force -ErrorAction SilentlyContinue
            Write-Host "All good – removed $MissingFilePath"
        }
    }
}

# Close LabVIEW but do not fail the job if it is already closed/missing
function SafeQuitLabVIEW {
    try {
        & g-cli --lv-ver $LVVersion --arch $Arch QuitLabVIEW | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW: {0}" -f $_.Exception.Message)
    }
}

# ====================  EXECUTION FLOW  =====================
try {
    Setup
    MainSequence
}
catch {
    $Script:ParsingFailed = $true
    Write-Warning ("Execution failed before cleanup: {0}" -f $_.Exception.Message)
}
finally {
    SafeQuitLabVIEW
    try {
        Cleanup
    }
    catch {
        Write-Warning ("Cleanup failed: {0}" -f $_.Exception.Message)
    }
}

# ====================  GH-ACTION OUTPUTS ===================
$passed = ($Script:HelperExitCode -eq 0) -and ($Script:MissingFileLines.Count -eq 0) -and (-not $Script:ParsingFailed)
$passedStr   = $passed.ToString().ToLower()
$missingCsv  = ($Script:MissingFileLines -join ',')

if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "passed=$passedStr"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "missing-files=$missingCsv"
}

# =====================  FINAL EXIT CODE  ===================
if ($Script:ParsingFailed) {
    exit 1        # helper/g-cli problem
}
elseif (-not $passed) {
    exit 2        # missing files found
}
else {
    exit 0        # success
}
