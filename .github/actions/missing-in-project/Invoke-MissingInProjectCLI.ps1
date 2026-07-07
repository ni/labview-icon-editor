#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
    [Parameter(Mandatory)][string]$ProjectFile,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 0
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..')).Path
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $repoRoot `
        -WorktreeRoot $WorktreeRoot `
        -LabVIEWVersion $LVVersion `
        -LabVIEWBitness $Arch `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$false `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs
    if ($preflight.Reinvoked) {
        return
    }
    $repoRoot = $preflight.RepoRoot
}
$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LVVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LVVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    $labviewYear = '2021'
}

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
    Write-Host "LVVersion  : $labviewYear"
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
    & $HelperPath -LVVersion $labviewYear -Arch $Arch -ProjectFile $ProjectFile -ConnectTimeoutMs $ConnectTimeoutMs
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
        & g-cli --lv-ver $labviewYear --arch $Arch QuitLabVIEW | Out-Null
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

$artifactRoot = $env:LVIE_ARTIFACT_ROOT
if (-not [string]::IsNullOrWhiteSpace($artifactRoot) -and (Test-Path $MissingFilePath)) {
    try {
        $targetDir = Join-Path $artifactRoot 'missing-in-project'
        if (-not (Test-Path -Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path $MissingFilePath -Destination (Join-Path $targetDir 'missing_files.txt') -Force
    } catch {
        Write-Warning ("Failed to copy missing_files.txt to artifact root: {0}" -f $_.Exception.Message)
    }
}

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
