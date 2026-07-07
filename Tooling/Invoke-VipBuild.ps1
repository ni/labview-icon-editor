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

    [Alias('MinimumSupportedLVVersion')]
    [ValidateRange(2000, 2100)]
    [int]$LabVIEWVersion,

    [ValidateRange(0, 99)]
    [int]$LabVIEWMinorRevision = 0,

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory = $true)]
    [string]$DisplayInformationJSON,

    [ValidateRange(60, 7200)]
    [int]$VipmTimeoutSeconds,

    [ValidateRange(1, 5)]
    [int]$MaxAttempts,

    [ValidateRange(5, 600)]
    [int]$RetryDelaySeconds,

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

$timeoutSecondsValue = if ($PSBoundParameters.ContainsKey('VipmTimeoutSeconds')) {
    $VipmTimeoutSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_VIPM_TIMEOUT_SECONDS' -Fallback 300
}

$maxAttemptsValue = if ($PSBoundParameters.ContainsKey('MaxAttempts')) {
    $MaxAttempts
} else {
    Resolve-IntSetting -Name 'LVIE_VIPM_MAX_ATTEMPTS' -Fallback 2
}

$retryDelayValue = if ($PSBoundParameters.ContainsKey('RetryDelaySeconds')) {
    $RetryDelaySeconds
} else {
    Resolve-IntSetting -Name 'LVIE_VIPM_RETRY_DELAY_SECONDS' -Fallback 30
}

$statusPath = Resolve-StatusPath -ExplicitPath $StatusPath -RepoRoot $resolvedRepoRoot
$logDirectory = Resolve-LogDirectory -RepoRoot $resolvedRepoRoot
$null = New-Item -Path $logDirectory -ItemType Directory -Force
$gcliLog = Join-Path -Path $logDirectory -ChildPath 'gcli-build.log'

$startedAt = Get-Date
$attempt = 0
$success = $false
$lastExitCode = $null
$lastError = $null

while ($attempt -lt $maxAttemptsValue) {
    $attempt++
    $attemptStart = Get-Date
    Write-Host ("VIP build attempt {0} of {1}" -f $attempt, $maxAttemptsValue)

    $displayInfoPath = Join-Path -Path $logDirectory -ChildPath 'vipb-display-info.json'
    try {
        Set-Content -Path $displayInfoPath -Value $DisplayInformationJSON -Encoding utf8
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
    } catch {
        $lastError = $_
        $lastExitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 1 }
    }

    if ($lastExitCode -eq 0) {
        $success = $true
        break
    }

    $attemptDuration = [Math]::Round(((Get-Date) - $attemptStart).TotalSeconds, 2)
    Write-Warning ("VIP build attempt {0} failed with exit code {1} after {2}s." -f $attempt, $lastExitCode, $attemptDuration)

    if ($attempt -lt $maxAttemptsValue) {
        $delay = $retryDelayValue * $attempt
        Write-Host ("Retrying after {0}s..." -f $delay)
        Start-Sleep -Seconds $delay
    }
}

$finishedAt = Get-Date
$durationSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 2)

$vip = Get-LatestVip -RepoRoot $resolvedRepoRoot
$vipPath = if ($vip) { $vip.FullName } else { $null }

$reason = $null
if (-not $success -and (Test-Path -Path $gcliLog)) {
    $timeoutMatch = Select-String -Path $gcliLog -Pattern 'Timeout waiting on VIPM' -SimpleMatch -Quiet
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
    gcli_log         = if (Test-Path -Path $gcliLog) { $gcliLog } else { $null }
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

