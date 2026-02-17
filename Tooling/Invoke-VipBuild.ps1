#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$VIPBPath,

    [string]$LabVIEWVersion,

    [ValidateRange(0, 99)]
    [int]$LabVIEWMinorRevision = 0,

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [string]$DisplayInformationJSON,
    [string]$DisplayInformationJsonPath,

    [ValidateRange(60, 7200)]
    [int]$VipmTimeoutSeconds,

    [string]$StatusPath,

    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck
)

$ErrorActionPreference = 'Stop'

function Resolve-IntSetting {
    param(
        [string]$Name,
        [int]$Fallback
    )

    $raw = $null
    if (Test-Path "Env:$Name") {
        $raw = (Get-Item "Env:$Name").Value
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Fallback
    }

    $value = 0
    if ([int]::TryParse($raw, [ref]$value)) {
        return $value
    }

    Write-Warning "Ignoring invalid $Name value '$raw'; using $Fallback."
    return $Fallback
}

function Assert-DeprecatedVipmRetrySettingsUnset {
    $deprecatedSettings = @('LVIE_VIPM_MAX_ATTEMPTS', 'LVIE_VIPM_RETRY_DELAY_SECONDS')
    foreach ($setting in $deprecatedSettings) {
        if (-not (Test-Path -Path "Env:$setting")) {
            continue
        }
        $value = (Get-Item -Path "Env:$setting").Value
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        throw ("Deprecated VIPM retry setting '{0}' is set to '{1}'. Retry configuration was removed; clear this variable and rerun." -f $setting, $value)
    }
}

function Resolve-StatusPath {
    param(
        [string]$ExplicitPath,
        [string]$RepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return $ExplicitPath
    }

    $artifactRoot = $env:LVIE_ARTIFACT_ROOT
    $base = if ([string]::IsNullOrWhiteSpace($artifactRoot)) { $RepoRoot } else { $artifactRoot }
    return (Join-Path -Path $base -ChildPath 'builds/status/vip-build.json')
}

function Resolve-LogDirectory {
    param([string]$RepoRoot)

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_LOG_ROOT)) {
        return (Join-Path -Path $env:LVIE_LOG_ROOT -ChildPath 'vip')
    }

    $artifactRoot = $env:LVIE_ARTIFACT_ROOT
    if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
        return (Join-Path -Path $RepoRoot -ChildPath 'builds/logs')
    }

    return (Join-Path -Path $artifactRoot -ChildPath 'builds/logs')
}

function Get-LatestVip {
    param(
        [string]$RepoRoot
    )

    $artifactRoot = $env:LVIE_ARTIFACT_ROOT
    $vipRoot = if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
        Join-Path -Path $RepoRoot -ChildPath 'builds/VI Package'
    } else {
        Join-Path -Path $artifactRoot -ChildPath 'builds/VI Package'
    }

    if (-not (Test-Path -Path $vipRoot)) {
        return $null
    }

    $vip = Get-ChildItem -Path $vipRoot -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1

    return $vip
}

function Write-Status {
    param(
        [string]$Path,
        [hashtable]$Payload
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    $Payload | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding ascii
}

function Copy-VipmLog {
    param([string]$LogDirectory)

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramData)) {
        $candidates += Join-Path $env:ProgramData 'JKI\VIPM\logs'
        $candidates += Join-Path $env:ProgramData 'JKI\VIPM\Logs'
        $candidates += Join-Path $env:ProgramData 'National Instruments\VIPM\logs'
        $candidates += Join-Path $env:ProgramData 'National Instruments\VIPM\Logs'
        $candidates += Join-Path $env:ProgramData 'VIPM\logs'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += Join-Path $env:LOCALAPPDATA 'JKI\VIPM\logs'
        $candidates += Join-Path $env:LOCALAPPDATA 'JKI\VIPM\Logs'
    }

    $destination = Join-Path -Path $LogDirectory -ChildPath 'vipm'
    $copied = $false

    foreach ($candidate in $candidates) {
        if (-not (Test-Path -Path $candidate)) {
            continue
        }
        try {
            New-Item -Path $destination -ItemType Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $candidate '*') -Destination $destination -Recurse -Force -ErrorAction SilentlyContinue
            $copied = $true
        } catch {
            Write-Warning ("Failed to copy VIPM logs from {0}: {1}" -f $candidate, $_.Exception.Message)
        }
    }

    return $copied
}

$resolvedRepoRoot = (Resolve-Path -Path $RepoRoot).Path
$buildVipScript = Join-Path -Path $resolvedRepoRoot -ChildPath '.github/actions/build-vip/build_vip.ps1'
if (-not (Test-Path -Path $buildVipScript)) {
    throw "build_vip.ps1 not found at $buildVipScript"
}

$versionHelper = Join-Path $resolvedRepoRoot 'Tooling/support/LabVIEWVersion.ps1'
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $repoInfo = Get-LabVIEWVersionInfo -RepoRoot $resolvedRepoRoot
    $inputProvided = $PSBoundParameters.ContainsKey('LabVIEWVersion') -and -not [string]::IsNullOrWhiteSpace([string]$LabVIEWVersion)
    if ($inputProvided) {
        $inputInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
        $LabVIEWVersion = [string]$inputInfo.Raw
    } else {
        $LabVIEWVersion = [string]$repoInfo.Raw
        Write-Warning "LabVIEWVersion not provided; defaulting to .lvversion ($($repoInfo.Raw))."
    }

    if ($PSBoundParameters.ContainsKey('LabVIEWMinorRevision')) {
        if ([int]$LabVIEWMinorRevision -ne [int]$repoInfo.MinorRevision) {
            throw "LabVIEWMinorRevision '$LabVIEWMinorRevision' does not match .lvversion minor '$($repoInfo.MinorRevision)'."
        }
    } else {
        $LabVIEWMinorRevision = [int]$repoInfo.MinorRevision
    }
}

$timeoutSecondsValue = if ($PSBoundParameters.ContainsKey('VipmTimeoutSeconds')) {
    $VipmTimeoutSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_VIPM_TIMEOUT_SECONDS' -Fallback 300
}
Assert-DeprecatedVipmRetrySettingsUnset

$statusPath = Resolve-StatusPath -ExplicitPath $StatusPath -RepoRoot $resolvedRepoRoot
$logDirectory = Resolve-LogDirectory -RepoRoot $resolvedRepoRoot
$null = New-Item -Path $logDirectory -ItemType Directory -Force
$vipmLog = Join-Path -Path $logDirectory -ChildPath 'vipm-build.log'
$legacyGcliLog = Join-Path -Path $logDirectory -ChildPath 'gcli-build.log'
$resolvedDisplayInformationJsonPath = $null

if (-not [string]::IsNullOrWhiteSpace($DisplayInformationJsonPath)) {
    $displaySourcePath = $DisplayInformationJsonPath
    if (-not [System.IO.Path]::IsPathRooted($displaySourcePath)) {
        $displaySourcePath = Join-Path -Path $resolvedRepoRoot -ChildPath $displaySourcePath
    }

    if (-not (Test-Path -Path $displaySourcePath -PathType Leaf)) {
        throw "DisplayInformationJsonPath '$displaySourcePath' does not exist."
    }

    $resolvedDisplayInformationJsonPath = (Resolve-Path -Path $displaySourcePath).Path
} elseif ([string]::IsNullOrWhiteSpace($DisplayInformationJSON)) {
    throw "DisplayInformationJSON was not provided. Pass -DisplayInformationJSON or -DisplayInformationJsonPath."
}

$startedAt = Get-Date
$attempt = 1
$success = $true
$lastExitCode = $null
$lastError = $null
$attemptStart = Get-Date
Write-Host 'VIP build attempt 1 of 1'

$displayInfoPath = Join-Path -Path $logDirectory -ChildPath 'vipb-display-info.json'
try {
    if (-not [string]::IsNullOrWhiteSpace($resolvedDisplayInformationJsonPath)) {
        Copy-Item -Path $resolvedDisplayInformationJsonPath -Destination $displayInfoPath -Force
    } else {
        Set-Content -Path $displayInfoPath -Value $DisplayInformationJSON -Encoding utf8
    }
} catch {
    throw "Failed to write display information JSON to $displayInfoPath. $($_.Exception.Message)"
}

$pwshArgs = @(
    '-NoProfile',
    '-File', $buildVipScript,
    '-SupportedBitness', $SupportedBitness,
    '-RepoRoot', $resolvedRepoRoot,
    '-VIPBPath', $VIPBPath,
    '-LabVIEWVersion', $LabVIEWVersion.ToString(),
    '-LabVIEWMinorRevision', $LabVIEWMinorRevision.ToString(),
    '-Major', $Major.ToString(),
    '-Minor', $Minor.ToString(),
    '-Patch', $Patch.ToString(),
    '-Build', $Build.ToString(),
    '-Commit', $Commit,
    '-ReleaseNotesFile', $ReleaseNotesFile,
    '-DisplayInformationJsonPath', $displayInfoPath,
    '-VipmTimeoutSeconds', $timeoutSecondsValue.ToString()
)

if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $pwshArgs += @('-WorktreeRoot', $WorktreeRoot)
}
if ($SkipWorktreeRootCheck.IsPresent) {
    $pwshArgs += '-SkipWorktreeRootCheck'
}

try {
    & pwsh @pwshArgs
    $lastExitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 0 }
    if ($lastExitCode -ne 0) {
        $success = $false
    }
} catch {
    $lastError = $_
    $lastExitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 1 }
    $success = $false
}

if (-not $success) {
    $attemptDuration = [Math]::Round(((Get-Date) - $attemptStart).TotalSeconds, 2)
    Write-Warning ("VIP build attempt 1 failed with exit code {0} after {1}s." -f $lastExitCode, $attemptDuration)
}

$finishedAt = Get-Date
$durationSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 2)

$vip = Get-LatestVip -RepoRoot $resolvedRepoRoot
$vipPath = if ($vip) { $vip.FullName } else { $null }

$reason = $null
if (-not $success) {
    $timeoutLogPath = if (Test-Path -Path $vipmLog) {
        $vipmLog
    } elseif (Test-Path -Path $legacyGcliLog) {
        $legacyGcliLog
    } else {
        $null
    }
    $timeoutMatch = $false
    if (-not [string]::IsNullOrWhiteSpace($timeoutLogPath)) {
        $timeoutMatch = Select-String -Path $timeoutLogPath -Pattern 'Timeout waiting on VIPM' -SimpleMatch -Quiet
    }
    if ($timeoutMatch) {
        $reason = 'vipm_timeout'
    }
}

$vipmLogsCopied = $false
if (-not $success) {
    $vipmLogsCopied = Copy-VipmLog -LogDirectory $logDirectory
}

$status = @{
    status           = if ($success) { 'success' } else { 'failure' }
    reason           = $reason
    attempts         = $attempt
    timeout_seconds  = $timeoutSecondsValue
    started_at       = $startedAt.ToString('o')
    finished_at      = $finishedAt.ToString('o')
    duration_seconds = $durationSeconds
    vip_path         = $vipPath
    vipm_log         = if (Test-Path -Path $vipmLog) { $vipmLog } else { $null }
    gcli_log         = if (Test-Path -Path $legacyGcliLog) { $legacyGcliLog } else { $null }
    vipm_logs        = if ($vipmLogsCopied) { (Join-Path $logDirectory 'vipm') } else { $null }
    repo_root        = $resolvedRepoRoot
}

Write-Status -Path $statusPath -Payload $status
Write-Host ("VIP build status written to {0}" -f $statusPath)

if (-not $success) {
    if ($lastError) {
        Write-Error ("VIP build failed: {0}" -f $lastError.Exception.Message)
    } else {
        Write-Error ("VIP build failed with exit code {0}." -f $lastExitCode)
    }
}

