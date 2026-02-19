#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LVVersion = '',
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
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

# ---------- GLOBAL STATE ----------
$Script:HelperExitCode   = 0
$Script:MissingFileLines = @()
$Script:ParsingFailed    = $false
$Script:HelperOutputLines = @()

$HelperPath      = Join-Path $PSScriptRoot 'RunMissingCheckWithGCLI.ps1'
$MissingFilePath = Join-Path $PSScriptRoot 'missing_files.txt'

if (-not (Test-Path $HelperPath)) {
    Write-Error "Helper script not found: $HelperPath"
    exit 100
}

function Resolve-BoolFromEnv {
    param(
        [string]$Name,
        [bool]$Fallback = $false
    )

    if (-not (Test-Path "Env:$Name")) {
        return $Fallback
    }

    $raw = (Get-Item "Env:$Name").Value
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Fallback
    }

    $normalized = $raw.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function ConvertFrom-AnsiText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace "`e\[[\d;]*m", '')
}

function Test-AllowNoLabVIEWIconApiGap {
    param(
        [string[]]$MissingLines,
        [string]$Arch,
        [string]$LabVIEWYear
    )

    if (-not (Resolve-BoolFromEnv -Name 'LVIE_FORCE_NO_LABVIEW_DEVMODE' -Fallback $false)) {
        return $false
    }
    if ($Arch -ne '32') {
        return $false
    }

    $allowByPolicy = Resolve-BoolFromEnv -Name 'LVIE_ALLOW_MISSING_IN_PROJECT_ICON_API_GAP' -Fallback (Resolve-BoolFromEnv -Name 'LVIE_RUNNER_ACL_WARN_ONLY' -Fallback $false)
    if (-not $allowByPolicy) {
        return $false
    }

    if (-not $MissingLines -or $MissingLines.Count -eq 0) {
        return $false
    }

    $labviewRoot = "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\"
    $relevantMissingLines = @(
        $MissingLines |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_.Trim().Trim('"') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Where-Object { $_ -match '^[A-Za-z]:\\' } |
            Where-Object { $_.StartsWith($labviewRoot, [System.StringComparison]::OrdinalIgnoreCase) }
    )

    if ($relevantMissingLines.Count -eq 0) {
        return $false
    }

    $expectedPrefixes = @(
        "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\vi.lib\LabVIEW Icon API",
        "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\resource\plugins\NIIconEditor"
    )
    $expectedExactPluginFiles = @(
        "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\resource\plugins\lv_icon.vi",
        "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\resource\plugins\lv_icon.lvlibp",
        "C:\Program Files (x86)\National Instruments\LabVIEW $LabVIEWYear\resource\plugins\lv_icon.ship"
    )

    foreach ($line in $relevantMissingLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            return $false
        }
        $matchesExpectedPrefix = $false
        foreach ($expectedPrefix in $expectedPrefixes) {
            if (
                $line.Equals($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
                $line.StartsWith($expectedPrefix + '\', [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                $matchesExpectedPrefix = $true
                break
            }
        }
        if (-not $matchesExpectedPrefix) {
            foreach ($expectedExactFile in $expectedExactPluginFiles) {
                if ($line.Equals($expectedExactFile, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $matchesExpectedPrefix = $true
                    break
                }
            }
        }
        if (-not $matchesExpectedPrefix) {
            return $false
        }
    }

    return $true
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

    # call helper and retain output for diagnostics/parsing
    $helperOutput = @(& $HelperPath -LVVersion $labviewYear -Arch $Arch -ProjectFile $ProjectFile -ConnectTimeoutMs $ConnectTimeoutMs 2>&1)
    $Script:HelperExitCode = $LASTEXITCODE
    $Script:HelperOutputLines = @($helperOutput | ForEach-Object { ConvertFrom-AnsiText -Text ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($Script:HelperExitCode -ne 0) {
        Write-Warning "Helper returned non-zero exit code: $Script:HelperExitCode"
    }

    # -------- read missing_files.txt --------
    if (Test-Path $MissingFilePath) {
        $Script:MissingFileLines = Get-Content $MissingFilePath |
                                   ForEach-Object { $_.Trim() } |
                                   Where-Object { $_ -ne '' }
    } elseif ($Script:HelperOutputLines.Count -gt 0) {
        $Script:MissingFileLines = $Script:HelperOutputLines | Where-Object { $_ -match '^[A-Za-z]:\\' }
    }

    if ($Script:HelperExitCode -ne 0) {
        if (Test-AllowNoLabVIEWIconApiGap -MissingLines $Script:MissingFileLines -Arch $Arch -LabVIEWYear $labviewYear) {
            Write-Warning ("Allowing Missing-In-Project NI Icon resource gap for LV{0} {1}-bit under forced no-LabVIEW mode (LabVIEW Icon API / NIIconEditor)." -f $labviewYear, $Arch)
            $Script:HelperExitCode = 0
            $Script:MissingFileLines = @()
        } elseif ($Script:MissingFileLines.Count -eq 0) {
            # helper failed and produced no parseable missing-file details
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

