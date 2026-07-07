#Requires -Version 7.0
<#
.SYNOPSIS
    Runs the LVIE job setup and teardown steps locally for faster iteration.

.DESCRIPTION
    Executes the same scripts used by the composite actions:
      - Tooling/Check-Runner.ps1
      - Tooling/Assert-RunnerLabel.ps1 (optional)
      - Tooling/RunnerLock.ps1 (optional)
      - Tooling/New-CIWorktreeForJob.ps1 (optional)
      - .github/actions/revert-development-mode/RevertDevelopmentMode.ps1 (optional)
      - .github/actions/close-labview/Close_LabVIEW.ps1 (optional)
    Always attempts cleanup (worktree + runner lock) on exit.

.PARAMETER Bitness
    LabVIEW bitness (32 or 64) for worktree naming and optional teardown steps.

.PARAMETER Variant
    Optional variant label for worktree naming.

.PARAMETER WorktreeRoot
    Optional override for the worktree root (defaults to LVIE_WORKTREE_ROOT or C:\dev).

.PARAMETER RepoRoot
    Optional override for the repo root (defaults to the repo containing this script).

.PARAMETER SkipRunnerSanity
    Skip Tooling/Check-Runner.ps1.

.PARAMETER SkipRunnerLabelCheck
    Skip Tooling/Assert-RunnerLabel.ps1.

.PARAMETER SkipLock
    Skip acquiring/releasing the LabVIEW runner lock.

.PARAMETER SkipWorktree
    Skip creating/removing the short-path worktree.

.PARAMETER RevertDevMode
    Run RevertDevelopmentMode.ps1 during teardown.

.PARAMETER CloseLabVIEW
    Run Close_LabVIEW.ps1 during teardown.

.PARAMETER WaitForIdle
    Wait for g-cli and LabVIEW processes to exit before starting.
#>

[CmdletBinding()]
param(
    [ValidateSet('32', '64')]
    [string]$Bitness = '64',

    [string]$Variant,

    [string]$WorktreeRoot,

    [string]$RepoRoot,

    [switch]$SkipRunnerSanity,

    [switch]$SkipRunnerLabelCheck,

    [switch]$SkipLock,

    [switch]$SkipWorktree,

    [switch]$RevertDevMode,

    [switch]$CloseLabVIEW,

    [switch]$WaitForIdle
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return (Resolve-Path -Path $Path -ErrorAction Stop).Path
    }
    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..') -ErrorAction Stop).Path
}

function Test-ForceNoLabVIEWDevMode {
    $value = $env:LVIE_FORCE_NO_LABVIEW_DEVMODE
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }
    $normalized = $value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function Set-EnvValue {
    param(
        [hashtable]$Store,
        [string]$Name,
        [string]$Value
    )
    if (-not $Store.ContainsKey($Name)) {
        if (Test-Path "Env:$Name") {
            $Store[$Name] = (Get-Item "Env:$Name").Value
        } else {
            $Store[$Name] = $null
        }
    }

    if ($null -eq $Value) {
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
    } else {
        Set-Item "Env:$Name" -Value $Value
    }
}

function Restore-EnvState {
    param([hashtable]$Store)
    foreach ($entry in $Store.GetEnumerator()) {
        if ($null -eq $entry.Value) {
            Remove-Item "Env:$($entry.Key)" -ErrorAction SilentlyContinue
        } else {
            Set-Item "Env:$($entry.Key)" -Value $entry.Value
        }
    }
}

function Wait-ForIdle {
    param([int]$PollSeconds = 10)
    while ($true) {
        $procs = Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue
        if (-not $procs) {
            return
        }
        Write-Host ("Waiting for existing processes: {0}" -f ($procs.ProcessName -join ', '))
        Start-Sleep -Seconds $PollSeconds
    }
}

$repoRootResolved = Resolve-RepoRoot -Path $RepoRoot
$envBackup = @{}
$worktreePath = $null
$lockAcquired = $false
$jobName = "local-job-setup-$Bitness"
if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $ensureScript = Join-Path $repoRootResolved 'Tooling/Ensure-WorktreeRoot.ps1'
    if (Test-Path -Path $ensureScript) {
        $WorktreeRoot = & $ensureScript
    }
}

try {
    if ($WaitForIdle.IsPresent) {
        Wait-ForIdle
    } else {
        $existing = Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue
        if ($existing) {
            $names = $existing.ProcessName | Select-Object -Unique
            Write-Warning ("Detected running processes: {0}. Use -WaitForIdle to wait." -f ($names -join ', '))
            return
        }
    }

    $gitSha = (& git -C $repoRootResolved rev-parse HEAD).Trim()
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    Set-EnvValue -Store $envBackup -Name 'GITHUB_WORKSPACE' -Value $repoRootResolved
    Set-EnvValue -Store $envBackup -Name 'GITHUB_ACTIONS' -Value 'true'
    Set-EnvValue -Store $envBackup -Name 'GITHUB_JOB' -Value $jobName
    Set-EnvValue -Store $envBackup -Name 'GITHUB_RUN_ID' -Value "local-$timestamp"
    Set-EnvValue -Store $envBackup -Name 'GITHUB_RUN_ATTEMPT' -Value '1'
    Set-EnvValue -Store $envBackup -Name 'GITHUB_WORKFLOW' -Value 'local-job-setup'
    Set-EnvValue -Store $envBackup -Name 'GITHUB_REPOSITORY' -Value 'local/labview-icon-editor'
    Set-EnvValue -Store $envBackup -Name 'GITHUB_REF_NAME' -Value 'local'
    Set-EnvValue -Store $envBackup -Name 'GITHUB_SHA' -Value $gitSha
    Set-EnvValue -Store $envBackup -Name 'GITHUB_ENV' -Value (Join-Path $env:TEMP "lvie-job-setup-$timestamp.env")

    if ($SkipRunnerLabelCheck.IsPresent) {
        Set-EnvValue -Store $envBackup -Name 'LVIE_SKIP_RUNNER_LABEL_CHECK' -Value 'true'
    }

    if (-not $SkipRunnerSanity.IsPresent) {
        & "$repoRootResolved\Tooling\Check-Runner.ps1" -SafeDirectoryScope System
    }

    if (-not $SkipRunnerLabelCheck.IsPresent) {
        & "$repoRootResolved\Tooling\Assert-RunnerLabel.ps1"
    }

    if (-not $SkipLock.IsPresent) {
        & "$repoRootResolved\Tooling\RunnerLock.ps1" -Mode Acquire
        $lockAcquired = $true
    }

    if (-not $SkipWorktree.IsPresent) {
        $worktreeOutput = & "$repoRootResolved\Tooling\New-CIWorktreeForJob.ps1" `
            -Bitness $Bitness `
            -Variant $Variant `
            -WorktreeRoot $WorktreeRoot `
            -RepoRoot $repoRootResolved `
            -JobName $jobName
        $candidatePaths = @($worktreeOutput) | Where-Object { $_ -is [string] } | ForEach-Object { $_.Trim() } | Where-Object { $_ -and (Test-Path -Path $_) }
        if (-not $candidatePaths -or $candidatePaths.Count -eq 0) {
            throw "Failed to resolve worktree path from New-CIWorktreeForJob output."
        }
        $worktreePath = @($candidatePaths)[-1]
        Set-EnvValue -Store $envBackup -Name 'REPO_ROOT' -Value $worktreePath
        Set-EnvValue -Store $envBackup -Name 'PROJECT_PATH' -Value (Join-Path $worktreePath 'lv_icon_editor.lvproj')
    }

    if ($RevertDevMode.IsPresent) {
        $lvInfo = & "$repoRootResolved\Tooling\Assert-LabVIEWVersion.ps1" -RepoRoot $repoRootResolved -Context 'local-teardown'
        $lvVersion = $lvInfo.Year
        if (-not $worktreePath) {
            throw "REPO_ROOT is required to revert dev mode. Create a worktree or pass -SkipWorktree:$false."
        }
        try {
            $revertParams = @{
                MinimumSupportedLVVersion = $lvVersion
                SupportedBitness          = $Bitness
                RepoRoot                  = $worktreePath
            }
            if (-not (Test-ForceNoLabVIEWDevMode)) {
                $revertParams.UseLabVIEW = $true
            }
            & "$repoRootResolved\.github\actions\revert-development-mode\RevertDevelopmentMode.ps1" @revertParams
        } catch {
            Write-Warning ("Revert dev mode failed: {0}" -f $_.Exception.Message)
        }
    }

    if ($CloseLabVIEW.IsPresent) {
        $lvInfo = & "$repoRootResolved\Tooling\Assert-LabVIEWVersion.ps1" -RepoRoot $repoRootResolved -Context 'local-teardown'
        $lvVersion = $lvInfo.Year
        try {
            & "$repoRootResolved\.github\actions\close-labview\Close_LabVIEW.ps1" `
                -MinimumSupportedLVVersion $lvVersion `
                -SupportedBitness $Bitness
        } catch {
            Write-Warning ("Close LabVIEW failed: {0}" -f $_.Exception.Message)
        }
    }
}
finally {
    if ($worktreePath) {
        try {
            git -C $repoRootResolved worktree remove --force "$worktreePath" 2>$null | Out-Null
            git -C $repoRootResolved worktree prune 2>$null | Out-Null
            Write-Host ("Removed worktree: {0}" -f $worktreePath)
        } catch {
            Write-Warning ("Failed to remove worktree {0}: {1}" -f $worktreePath, $_.Exception.Message)
        }
    }

    if ($lockAcquired) {
        try {
            & "$repoRootResolved\Tooling\RunnerLock.ps1" -Mode Release
        } catch {
            Write-Warning ("Failed to release runner lock: {0}" -f $_.Exception.Message)
        }
    }

    Restore-EnvState -Store $envBackup
}
