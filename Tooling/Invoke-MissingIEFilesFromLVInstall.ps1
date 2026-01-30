#Requires -Version 7.0
<#
.SYNOPSIS
    Runs VerifyIEPaths.vi via g-cli and reads the status file.

.DESCRIPTION
    Executes Tooling\VerifyIEPaths.vi with no VI arguments using g-cli for the
    specified LabVIEW version and bitness. Reads the status file produced at
    the repo root to report pass/fail details.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    LabVIEW bitness to target ("32" or "64"). Defaults to "64".

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.

.PARAMETER StatusFileName
    Optional status file name (relative to repo root) or absolute path.

.PARAMETER StatusFileTimeoutMs
    Timeout in milliseconds to wait for the status file to appear.

.PARAMETER ProcessTimeoutMs
    Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).

.PARAMETER StatusFileArchiveDirectory
    Optional directory to archive the status file after reading. If omitted,
    the status file is deleted.

.PARAMETER StatusSuccessPattern
    Regex pattern that indicates success within the status file contents.

.PARAMETER StatusFailurePattern
    Regex pattern that indicates failure within the status file contents.

.PARAMETER IgnoreStatusFailure
    If set, do not throw when the status file indicates failure.

.PARAMETER IgnoreMissingStatusFile
    If set, do not throw when a status file cannot be located.

.PARAMETER IgnoreGcliExitCode
    If set, do not throw when g-cli returns a non-zero exit code.

.PARAMETER FailOnUnknownStatus
    If set, throw when the status cannot be classified as success/failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness = '64',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [Parameter(Mandatory = $false)]
    [string]$StatusFileName = 'missing_IE_paths.txt',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$StatusFileTimeoutMs = 60000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [Parameter(Mandatory = $false)]
    [string]$StatusFileArchiveDirectory,

    [Parameter(Mandatory = $false)]
    [string]$StatusSuccessPattern,

    [Parameter(Mandatory = $false)]
    [string]$StatusFailurePattern,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreStatusFailure,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreMissingStatusFile,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreGcliExitCode,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnUnknownStatus,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
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

function Wait-VerifyIEPathsStatusFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string]$StatusFileName,
        [datetime]$StartTimeUtc,
        [int]$TimeoutMs = 60000,
        [int]$PollIntervalMs = 200
    )

    $candidate = Resolve-VerifyIEPathsStatusFile -RepoRoot $RepoRoot -StatusFileName $StatusFileName -StartTimeUtc $StartTimeUtc
    if (-not $TimeoutMs -or $TimeoutMs -le 0) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -Path $candidate)) {
            return $candidate
        }
        return $null
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.ElapsedMilliseconds -lt $TimeoutMs) {
        $candidate = Resolve-VerifyIEPathsStatusFile -RepoRoot $RepoRoot -StatusFileName $StatusFileName -StartTimeUtc $StartTimeUtc
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -Path $candidate)) {
            if ($StartTimeUtc) {
                $item = Get-Item -Path $candidate -ErrorAction SilentlyContinue
                if ($item -and $item.LastWriteTimeUtc -ge $StartTimeUtc) {
                    return $candidate
                }
            } else {
                return $candidate
            }
        }
        Start-Sleep -Milliseconds $PollIntervalMs
    }

    return $null
}

function Invoke-VerifyIEPathsStatusCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatusPath,
        [string]$ArchiveDirectory
    )

    if (-not (Test-Path -Path $StatusPath)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ArchiveDirectory)) {
        Remove-Item -Path $StatusPath -Force -ErrorAction SilentlyContinue
        return
    }

    try {
        if (-not (Test-Path -Path $ArchiveDirectory)) {
            New-Item -Path $ArchiveDirectory -ItemType Directory -Force | Out-Null
        }

        $timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($StatusPath)
        $extension = [System.IO.Path]::GetExtension($StatusPath)
        $archiveName = "$baseName.$timestamp$extension"
        $archivePath = Join-Path -Path $ArchiveDirectory -ChildPath $archiveName
        Move-Item -Path $StatusPath -Destination $archivePath -Force
        Write-Host ("Archived VerifyIEPaths status file to: {0}" -f $archivePath)
    } catch {
        Write-Warning ("Failed to archive VerifyIEPaths status file: {0}" -f $_.Exception.Message)
    }
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$gCliRunner = Join-Path -Path $PSScriptRoot -ChildPath 'support\GcliRunner.ps1'
if (-not (Test-Path -Path $gCliRunner)) {
    throw "g-cli helper not found at $gCliRunner"
}
. $gCliRunner
$statusHelper = Join-Path -Path $PSScriptRoot -ChildPath 'support\VerifyIEPathsStatus.ps1'
if (-not (Test-Path -Path $statusHelper)) {
    throw "VerifyIEPaths status helper not found at $statusHelper"
}
. $statusHelper

$viPath = Join-Path -Path $repoRoot -ChildPath 'Tooling\VerifyIEPaths.vi'

if (-not (Test-Path -Path $viPath)) {
    throw "VerifyIEPaths.vi not found at $viPath"
}

if (-not (Get-LabVIEWInstallRoot -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness)) {
    throw "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) install not found."
}

if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
    throw "g-cli.exe not found in PATH."
}

$gCliPath = (Get-Command g-cli -ErrorAction SilentlyContinue).Source

$gCliArgs = @(
    '--lv-ver', $MinimumSupportedLVVersion,
    '--arch', $SupportedBitness
)

if ($ConnectTimeoutMs -gt 0) {
    $gCliArgs += @('--connect-timeout', $ConnectTimeoutMs)
}

$gCliArgs += @('-v', $viPath)

Write-Host ("Executing: g-cli {0}" -f ($gCliArgs -join ' '))

$runStartUtc = (Get-Date).ToUniversalTime()
$statusPathExpected = Resolve-VerifyIEPathsStatusFile -RepoRoot $repoRoot -StatusFileName $StatusFileName
if (-not [string]::IsNullOrWhiteSpace($statusPathExpected) -and (Test-Path -Path $statusPathExpected)) {
    Remove-Item -Path $statusPathExpected -Force -ErrorAction SilentlyContinue
}
Push-Location -Path $repoRoot
try {
    $result = Invoke-GCliCommand -ExecutablePath $gCliPath -Arguments $gCliArgs -TimeoutMs $ProcessTimeoutMs
    if ($result.TimedOut) {
        throw "VerifyIEPaths.vi timed out after $ProcessTimeoutMs ms."
    }
    if ($result.ExitCode -ne 0) {
        if ($IgnoreGcliExitCode) {
            Write-Warning ("VerifyIEPaths.vi returned exit code {0}; continuing because IgnoreGcliExitCode is set." -f $result.ExitCode)
        } else {
            throw "VerifyIEPaths.vi failed with exit code $($result.ExitCode)."
        }
    }

    $statusPath = $null
    try {
        $statusPath = Wait-VerifyIEPathsStatusFile -RepoRoot $repoRoot -StatusFileName $StatusFileName -StartTimeUtc $runStartUtc -TimeoutMs $StatusFileTimeoutMs
        if (-not [string]::IsNullOrWhiteSpace($statusPath) -and (Test-Path -Path $statusPath)) {
            $statusInfo = Get-VerifyIEPathsStatus -StatusFilePath $statusPath -SuccessPattern $StatusSuccessPattern -FailurePattern $StatusFailurePattern
            Write-Host ("VerifyIEPaths status file: {0}" -f $statusInfo.Path)
            Write-Host ("VerifyIEPaths status: {0}" -f $statusInfo.RawStatus)

            if ($statusInfo.IsFailure -and -not $IgnoreStatusFailure) {
                $missing = if ($statusInfo.MissingPaths -and $statusInfo.MissingPaths.Count -gt 0) {
                    $statusInfo.MissingPaths -join ', '
                } else {
                    $statusInfo.RawStatus
                }
                throw "VerifyIEPaths reported missing paths: $missing"
            }

            if ($statusInfo.IsUnknown -and $FailOnUnknownStatus) {
                throw "VerifyIEPaths status was not recognized: $($statusInfo.RawStatus)"
            }

            if ($statusInfo.IsUnknown) {
                Write-Warning "VerifyIEPaths status was not recognized; update patterns if needed."
            }
        } else {
            $message = "VerifyIEPaths status file not found after waiting $StatusFileTimeoutMs ms."
            if (-not $IgnoreMissingStatusFile) {
                throw $message
            }
            Write-Warning $message
        }
    } finally {
        if (-not [string]::IsNullOrWhiteSpace($statusPath) -and (Test-Path -Path $statusPath)) {
            Invoke-VerifyIEPathsStatusCleanup -StatusPath $statusPath -ArchiveDirectory $StatusFileArchiveDirectory
        }
    }
}
finally {
    Pop-Location
    try {
        & g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW: {0}" -f $_.Exception.Message)
    }
}
