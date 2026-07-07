#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Acquire', 'Release')]
    [string]$Mode = 'Acquire',

    [ValidateRange(30, 86400)]
    [int]$TimeoutSeconds = 7200,

    [ValidateRange(300, 86400)]
    [int]$LeaseSeconds = 21600,

    [ValidateRange(300, 604800)]
    [int]$StaleAfterSeconds = 43200,

    [ValidateRange(30, 3600)]
    [int]$GitHubMinAgeSeconds = 120,

    [ValidateRange(15, 3600)]
    [int]$GitHubCheckIntervalSeconds = 60,

    [switch]$DisableGitHubStaleCheck,

    [string]$LockRoot
)

$ErrorActionPreference = 'Stop'

function Get-EnvValue {
    param([string]$Name)

    if (Test-Path "Env:$Name") {
        return (Get-Item "Env:$Name").Value
    }

    return $null
}

function Resolve-IntSetting {
    param(
        [string]$Name,
        [int]$Fallback,
        [int]$Minimum = [int]::MinValue,
        [int]$Maximum = [int]::MaxValue
    )

    $raw = Get-EnvValue -Name $Name
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Fallback
    }

    $value = 0
    if ([int]::TryParse($raw, [ref]$value)) {
        if ($value -lt $Minimum -or $value -gt $Maximum) {
            Write-Warning "Ignoring out-of-range $Name value '$raw'; using $Fallback."
            return $Fallback
        }
        return $value
    }

    Write-Warning "Ignoring invalid $Name value '$raw'; using $Fallback."
    return $Fallback
}

function Resolve-BoolSetting {
    param(
        [string]$Name,
        [bool]$Fallback
    )

    $raw = Get-EnvValue -Name $Name
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Fallback
    }

    switch ($raw.ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default {
            Write-Warning "Ignoring invalid $Name value '$raw'; using $Fallback."
            return $Fallback
        }
    }
}

function Resolve-LockRoot {
    param([string]$LockRootOverride)

    if (-not [string]::IsNullOrWhiteSpace($LockRootOverride)) {
        return $LockRootOverride
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_LOCK_ROOT)) {
        return $env:LVIE_LOCK_ROOT
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_ROOT)) {
        return $env:LVIE_WORKTREE_ROOT
    }

    return 'C:\dev'
}

function Get-LockMetadataRecord {
    param([string]$MetadataPath)

    if (-not (Test-Path -Path $MetadataPath)) {
        return $null
    }

    try {
        $raw = Get-Content -Path $MetadataPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return $raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to read lock metadata at '$MetadataPath': $($_.Exception.Message)"
        return $null
    }
}

function Resolve-AcquiredAtUtc {
    param(
        [object]$Metadata,
        [string]$LockPath
    )

    if ($Metadata -and $Metadata.acquired_at) {
        try {
            return [DateTime]::Parse($Metadata.acquired_at).ToUniversalTime()
        } catch {
            Write-Warning "Invalid acquired_at '$($Metadata.acquired_at)' in lock metadata."
        }
    }

    if (Test-Path -Path $LockPath) {
        return (Get-Item -Path $LockPath).CreationTimeUtc
    }

    return (Get-Date).ToUniversalTime()
}

function Resolve-LeaseExpiresAtUtc {
    param(
        [object]$Metadata,
        [DateTime]$AcquiredAtUtc,
        [int]$LeaseSecondsValue
    )

    if ($Metadata -and $Metadata.lease_expires_at) {
        try {
            return [DateTime]::Parse($Metadata.lease_expires_at).ToUniversalTime()
        } catch {
            Write-Warning "Invalid lease_expires_at '$($Metadata.lease_expires_at)' in lock metadata."
        }
    }

    return $AcquiredAtUtc.AddSeconds($LeaseSecondsValue)
}

function Get-GitHubRunStatus {
    param(
        [string]$Repository,
        [string]$RunId
    )

    $token = Get-EnvValue -Name 'GITHUB_TOKEN'
    if ([string]::IsNullOrWhiteSpace($token)) {
        return $null
    }

    $apiRoot = Get-EnvValue -Name 'GITHUB_API_URL'
    if ([string]::IsNullOrWhiteSpace($apiRoot)) {
        $apiRoot = 'https://api.github.com'
    }

    $headers = @{
        Authorization       = "Bearer $token"
        Accept              = 'application/vnd.github+json'
        'User-Agent'        = 'LabVIEW-RunnerLock'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    $uri = "$apiRoot/repos/$Repository/actions/runs/$RunId"

    try {
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -TimeoutSec 20
        return [pscustomobject]@{
            ok         = $true
            status     = $response.status
            conclusion = $response.conclusion
            html_url   = $response.html_url
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
        }
        return [pscustomobject]@{
            ok          = $false
            status      = $null
            conclusion  = $null
            status_code = $statusCode
            error       = $_.Exception.Message
        }
    }
}

function Format-LockOwner {
    param([object]$Metadata)

    if (-not $Metadata) {
        return 'unknown'
    }

    $parts = @()
    if ($Metadata.repository) { $parts += $Metadata.repository }
    if ($Metadata.run_id) { $parts += "run:$($Metadata.run_id)" }
    if ($Metadata.job) { $parts += "job:$($Metadata.job)" }
    if ($Metadata.workflow) { $parts += "wf:$($Metadata.workflow)" }
    if ($Metadata.machine) { $parts += "host:$($Metadata.machine)" }

    if ($parts.Count -eq 0) {
        return 'unknown'
    }

    return ($parts -join ' ')
}

$timeoutSecondsValue = if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
    $TimeoutSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_RUNNER_LOCK_TIMEOUT_SECONDS' -Fallback $TimeoutSeconds -Minimum 30 -Maximum 86400
}

$leaseSecondsValue = if ($PSBoundParameters.ContainsKey('LeaseSeconds')) {
    $LeaseSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_RUNNER_LOCK_LEASE_SECONDS' -Fallback $LeaseSeconds -Minimum 300 -Maximum 86400
}

$staleAfterSecondsValue = if ($PSBoundParameters.ContainsKey('StaleAfterSeconds')) {
    $StaleAfterSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_RUNNER_LOCK_STALE_SECONDS' -Fallback $StaleAfterSeconds -Minimum 300 -Maximum 604800
}

$gitHubMinAgeSecondsValue = if ($PSBoundParameters.ContainsKey('GitHubMinAgeSeconds')) {
    $GitHubMinAgeSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_RUNNER_LOCK_GITHUB_MIN_AGE_SECONDS' -Fallback $GitHubMinAgeSeconds -Minimum 30 -Maximum 3600
}

$gitHubCheckIntervalSecondsValue = if ($PSBoundParameters.ContainsKey('GitHubCheckIntervalSeconds')) {
    $GitHubCheckIntervalSeconds
} else {
    Resolve-IntSetting -Name 'LVIE_RUNNER_LOCK_GITHUB_CHECK_INTERVAL_SECONDS' -Fallback $GitHubCheckIntervalSeconds -Minimum 15 -Maximum 3600
}

$gitHubCheckEnabled = -not $DisableGitHubStaleCheck.IsPresent
$gitHubCheckEnabled = Resolve-BoolSetting -Name 'LVIE_RUNNER_LOCK_GITHUB_CHECK' -Fallback $gitHubCheckEnabled
if ([string]::IsNullOrWhiteSpace((Get-EnvValue -Name 'GITHUB_TOKEN'))) {
    $gitHubCheckEnabled = $false
}

$root = Resolve-LockRoot -LockRootOverride $LockRoot
$locksDir = if (-not [string]::IsNullOrWhiteSpace($env:LVIE_LOCK_ROOT) -or -not [string]::IsNullOrWhiteSpace($LockRoot)) {
    $root
} else {
    Join-Path $root 'locks'
}
$lockPath = Join-Path $locksDir 'labview-runner.lock'
$metadataPath = Join-Path $lockPath 'lock.json'

if ($Mode -eq 'Acquire') {
    New-Item -Path $locksDir -ItemType Directory -Force | Out-Null
    $deadline = (Get-Date).AddSeconds($timeoutSecondsValue)
    $nextGitHubCheck = [DateTime]::MinValue
    $lastWaitLog = [DateTime]::MinValue

    while ($true) {
        try {
            New-Item -Path $lockPath -ItemType Directory -ErrorAction Stop | Out-Null

            $acquiredAtUtc = (Get-Date).ToUniversalTime()
            $leaseExpiresAtUtc = $acquiredAtUtc.AddSeconds($leaseSecondsValue)
            $metadata = [pscustomobject]@{
                lock_version     = 2
                acquired_at      = $acquiredAtUtc.ToString('o')
                lease_expires_at = $leaseExpiresAtUtc.ToString('o')
                machine          = $env:COMPUTERNAME
                pid              = $PID
                run_id           = $env:GITHUB_RUN_ID
                run_attempt      = $env:GITHUB_RUN_ATTEMPT
                job              = $env:GITHUB_JOB
                workflow         = $env:GITHUB_WORKFLOW
                repository       = $env:GITHUB_REPOSITORY
                sha              = $env:GITHUB_SHA
                actor            = $env:GITHUB_ACTOR
                ref_name         = $env:GITHUB_REF_NAME
                run_url          = if ($env:GITHUB_SERVER_URL -and $env:GITHUB_REPOSITORY -and $env:GITHUB_RUN_ID) {
                    "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID)"
                } else {
                    $null
                }
            }

            $metadata | ConvertTo-Json | Set-Content -Path $metadataPath
            Write-Host "Acquired LabVIEW runner lock: $lockPath"
            break
        } catch {
            $metadata = Get-LockMetadataRecord -MetadataPath $metadataPath
            $owner = Format-LockOwner -Metadata $metadata
            $acquiredAtUtc = Resolve-AcquiredAtUtc -Metadata $metadata -LockPath $lockPath
            $leaseExpiresAtUtc = Resolve-LeaseExpiresAtUtc -Metadata $metadata -AcquiredAtUtc $acquiredAtUtc -LeaseSecondsValue $leaseSecondsValue
            $ageSecondsRaw = [int]([DateTime]::UtcNow - $acquiredAtUtc).TotalSeconds
            $ageSeconds = $ageSecondsRaw
            $ageSecondsForChecks = $ageSecondsRaw
            if ($ageSecondsRaw -lt 0) {
                $ageSecondsRawOriginal = $ageSecondsRaw
                $fallbackAcquiredAtUtc = $null
                if (Test-Path -Path $lockPath) {
                    $fallbackAcquiredAtUtc = (Get-Item -Path $lockPath).CreationTimeUtc
                }
                if ($fallbackAcquiredAtUtc -and $fallbackAcquiredAtUtc -le [DateTime]::UtcNow) {
                    $acquiredAtUtc = $fallbackAcquiredAtUtc
                    $leaseExpiresAtUtc = $acquiredAtUtc.AddSeconds($leaseSecondsValue)
                    $ageSecondsRaw = [int]([DateTime]::UtcNow - $acquiredAtUtc).TotalSeconds
                    $ageSeconds = [Math]::Max(0, $ageSecondsRaw)
                    $ageSecondsForChecks = [Math]::Max($gitHubMinAgeSecondsValue, $ageSeconds)
                    Write-Warning ("Runner lock clock skew detected (age {0}s). Using lock creation time {1:o} for age/lease calculations." -f $ageSecondsRawOriginal, $acquiredAtUtc)
                } else {
                    $ageSeconds = 0
                    $ageSecondsForChecks = $gitHubMinAgeSecondsValue
                    Write-Warning ("Runner lock clock skew detected (age {0}s). Treating lock as at least {1}s old for GitHub checks." -f $ageSecondsRawOriginal, $gitHubMinAgeSecondsValue)
                }
            }
            $ownerSameRun = $false
            if ($metadata -and $metadata.run_id -and $env:GITHUB_RUN_ID) {
                $ownerSameRun = ($metadata.run_id -eq $env:GITHUB_RUN_ID)
            }

            $staleReason = $null
            $statusActive = $false
            if ($ownerSameRun) {
                $statusActive = $true
            }

            if (-not $ownerSameRun -and $gitHubCheckEnabled -and $metadata -and $metadata.run_id -and $metadata.repository) {
                $now = (Get-Date).ToUniversalTime()
                if ($ageSecondsForChecks -ge $gitHubMinAgeSecondsValue -and $now -ge $nextGitHubCheck) {
                    $runStatus = Get-GitHubRunStatus -Repository $metadata.repository -RunId $metadata.run_id
                    $nextGitHubCheck = $now.AddSeconds($gitHubCheckIntervalSecondsValue)
                    if ($runStatus) {
                        if ($runStatus.ok) {
                            if ($runStatus.status -eq 'completed') {
                                $staleReason = "GitHub run completed ($($runStatus.conclusion))"
                            } else {
                                $statusActive = $true
                            }
                        } elseif ($runStatus.status_code -eq 404) {
                            $staleReason = 'GitHub run not found'
                        } else {
                            $statusCode = if ($runStatus.status_code) { $runStatus.status_code } else { 'unknown' }
                            $statusError = if ($runStatus.error) { $runStatus.error } else { 'unknown error' }
                            Write-Warning ("Runner lock GitHub check failed (status={0} error={1})." -f $statusCode, $statusError)
                        }
                    }
                }
            }

            if (-not $staleReason -and -not $statusActive) {
                if ((Get-Date).ToUniversalTime() -ge $leaseExpiresAtUtc) {
                    $staleReason = "Lease expired at $leaseExpiresAtUtc"
                } elseif ($ageSeconds -ge $staleAfterSecondsValue) {
                    $staleReason = "Lock age ${ageSeconds}s exceeded stale threshold"
                }
            }

            if ($staleReason) {
                Write-Warning "Stale LabVIEW runner lock detected ($staleReason). Removing lock held by $owner."
                if (Test-Path -Path $lockPath) {
                    Remove-Item -Path $lockPath -Recurse -Force
                }
                continue
            }

            $now = (Get-Date).ToUniversalTime()
            if ($now -ge $deadline) {
                $details = @(
                    "owner=$owner",
                    "acquired=$acquiredAtUtc",
                    "lease_expires=$leaseExpiresAtUtc",
                    "age=${ageSeconds}s"
                ) -join '; '
                throw "Timed out waiting for LabVIEW runner lock at '$lockPath'. $details"
            }

            if ($lastWaitLog -eq [DateTime]::MinValue -or $now -ge $lastWaitLog.AddMinutes(5)) {
                Write-Host ("LabVIEW runner lock held by {0}. Waiting 15s." -f $owner)
                $lastWaitLog = $now
            }

            Start-Sleep -Seconds 15
        }
    }
} else {
    if (Test-Path -Path $lockPath) {
        Remove-Item -Path $lockPath -Recurse -Force
        Write-Host "Released LabVIEW runner lock: $lockPath"
    } else {
        Write-Host "LabVIEW runner lock not present: $lockPath"
    }
}

