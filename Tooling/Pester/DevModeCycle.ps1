param(
    [string]$Repo = 'svelderrainruiz/labview-icon-editor',
    [string]$Ref = 'experimental/447-Sergio-Change-Number-1',
    [string[]]$ModeSequence = @('disable', 'enable'),
    [string[]]$AllowFailureModes = @(),
    [ValidatePattern('^\d{2,4}(\.\d+)?$')]
    [string]$LabVIEWVersion = '',
    [int]$PollSeconds = 2,
    [int]$TimeoutMinutes = 3,
    [int]$RunTimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'

$settings = [pscustomobject]@{
    Repo              = $Repo
    Ref               = $Ref
    LabVIEWVersion    = $LabVIEWVersion
    PollSeconds       = $PollSeconds
    TimeoutMinutes    = $TimeoutMinutes
    RunTimeoutMinutes = $RunTimeoutMinutes
}

function Assert-GhReady {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) not found in PATH.'
    }

    $null = & gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'gh auth status failed. Please authenticate with GitHub.'
    }
}

function Start-DevModeRun {
    param(
        [string]$Mode,
        [string]$SequenceId,
        [pscustomobject]$Settings
    )

    $ghArgs = @(
        'workflow', 'run', 'Toggle Development Mode',
        '--repo', $Settings.Repo,
        '--ref', $Settings.Ref,
        '-f', "mode=$Mode",
        '-f', "labview_version=$($Settings.LabVIEWVersion)",
        '-f', "sequence_id=$SequenceId"
    )

    Write-Host ("Starting workflow: mode={0}" -f $Mode)
    & gh @ghArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to dispatch workflow for mode=$Mode."
    }
}

function Get-RunSummary {
    param(
        [long]$RunId,
        [pscustomobject]$Settings
    )

    $run = & gh run view --repo $Settings.Repo $RunId --json status,conclusion 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $run) {
        return $null
    }

    return $run
}

function Wait-ForRunCompletion {
    param(
        [long]$RunId,
        [string]$Mode,
        [string[]]$AllowFailureModes,
        [pscustomobject]$Settings
    )

    $deadline = (Get-Date).ToUniversalTime().AddMinutes($Settings.RunTimeoutMinutes)
    $lastStatus = $null
    $allowFailure = $false

    if ($AllowFailureModes) {
        $allowFailure = $AllowFailureModes -contains $Mode
    }
    if ($Mode -eq 'active') {
        $allowFailure = $true
    }

    do {
        $run = Get-RunSummary -RunId $RunId -Settings $Settings
        if (-not $run) {
            Start-Sleep -Seconds $Settings.PollSeconds
            continue
        }

        if ($run.status -ne $lastStatus) {
            Write-Host ("Run {0} status: {1}" -f $RunId, $run.status)
            $lastStatus = $run.status
        }

        if ($run.status -eq 'completed') {
            if ($run.conclusion -ne 'success') {
                Write-Host "Run failed; fetching logs..."
                & gh run view --repo $Repo $RunId --log
                if ($allowFailure) {
                    Write-Warning "Allowing failure for mode=$Mode (run id $RunId)."
                    return
                }
                throw "Workflow run failed for mode=$Mode (run id $RunId)."
            }
            return
        }

        Start-Sleep -Seconds $Settings.PollSeconds
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    throw "Timed out waiting for workflow run completion (mode=$Mode, run id $RunId)."
}

function Get-RunBySequenceId {
    param(
        [string]$SequenceId,
        [pscustomobject]$Settings
    )

    $runs = & gh run list `
        --repo $Settings.Repo `
        --workflow 'Toggle Development Mode' `
        --branch $Settings.Ref `
        --event workflow_dispatch `
        --limit 20 `
        --json databaseId,createdAt,status,conclusion,displayTitle 2>$null | ConvertFrom-Json

    if (-not $runs) {
        return $null
    }

    $matched = $runs | Where-Object { $_.displayTitle -like "*$SequenceId*" } | Sort-Object databaseId -Descending
    return $matched | Select-Object -First 1
}

function Wait-ForActiveRunToFinish {
    param(
        [pscustomobject]$Settings
    )

    $activeRun = & gh run list `
        --repo $Settings.Repo `
        --workflow 'Toggle Development Mode' `
        --branch $Settings.Ref `
        --status in_progress `
        --limit 1 `
        --json databaseId 2>$null | ConvertFrom-Json

    if (-not $activeRun -or -not $activeRun.databaseId) {
        $activeRun = & gh run list `
            --repo $Settings.Repo `
            --workflow 'Toggle Development Mode' `
            --branch $Settings.Ref `
            --status queued `
            --limit 1 `
            --json databaseId 2>$null | ConvertFrom-Json
    }

    if ($activeRun -and $activeRun.databaseId) {
        Write-Host "Active run detected ($($activeRun.databaseId)). Waiting for completion..."
        Wait-ForRunCompletion -RunId $activeRun.databaseId -Mode 'active' -AllowFailureModes @() -Settings $Settings
    }
}

function Wait-ForRun {
    param(
        [string]$SequenceId,
        [string]$Mode,
        [string[]]$AllowFailureModes,
        [pscustomobject]$Settings
    )

    $deadline = (Get-Date).ToUniversalTime().AddMinutes($Settings.TimeoutMinutes)
    do {
        $run = Get-RunBySequenceId -SequenceId $SequenceId -Settings $Settings
        if ($run) {
            Write-Host ("Workflow run found: {0} (sequence_id={1})" -f $run.databaseId, $SequenceId)
            if ($run.status -eq 'completed') {
                if ($run.conclusion -ne 'success') {
                    Write-Host "Run failed; fetching logs..."
                    & gh run view --repo $Settings.Repo $run.databaseId --log
                    if ($AllowFailureModes -contains $Mode) {
                        Write-Warning "Allowing failure for mode=$Mode (run id $($run.databaseId))."
                        return
                    }
                    throw "Workflow run failed for mode=$Mode (run id $($run.databaseId))."
                }
                return
            }

            Wait-ForRunCompletion -RunId $run.databaseId -Mode $Mode -AllowFailureModes $AllowFailureModes -Settings $Settings
            return
        }

        Write-Host ("Waiting for workflow run (mode={0}, sequence_id={1})..." -f $Mode, $SequenceId)
        Start-Sleep -Seconds $Settings.PollSeconds
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    throw "Timed out waiting for workflow run (mode=$Mode, sequence_id=$SequenceId)."
}

Assert-GhReady

$normalizedModes = @()
foreach ($entry in $ModeSequence) {
    if ($null -eq $entry) { continue }
    $normalizedModes += ($entry -split ',')
}
$normalizedModes = $normalizedModes | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }
if (-not $normalizedModes) {
    throw 'ModeSequence cannot be empty.'
}
$invalidModes = $normalizedModes | Where-Object { $_ -notin @('enable', 'disable') }
if ($invalidModes) {
    throw ("ModeSequence contains invalid values: {0}" -f ($invalidModes -join ', '))
}

$normalizedAllowFailures = @()
foreach ($entry in $AllowFailureModes) {
    if ($null -eq $entry) { continue }
    $normalizedAllowFailures += ($entry -split ',')
}
$normalizedAllowFailures = $normalizedAllowFailures | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }
$invalidAllow = $normalizedAllowFailures | Where-Object { $_ -notin @('enable', 'disable') }
if ($invalidAllow) {
    throw ("AllowFailureModes contains invalid values: {0}" -f ($invalidAllow -join ', '))
}

Write-Host ("Mode sequence: {0}" -f ($normalizedModes -join ' -> '))
if ($normalizedAllowFailures) {
    Write-Host ("Allowing failures for modes: {0}" -f ($normalizedAllowFailures -join ', '))
}

$sequenceGroup = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$sequenceSuffix = [guid]::NewGuid().ToString('N').Substring(0, 6)
$sequenceGroup = "devmode-$sequenceGroup-$sequenceSuffix"
Write-Host ("Sequence group: {0}" -f $sequenceGroup)

$sequenceIndex = 0
foreach ($mode in $normalizedModes) {
    Wait-ForActiveRunToFinish -Settings $settings
    $sequenceIndex += 1
    $sequenceId = "{0}-{1:D2}-{2}" -f $sequenceGroup, $sequenceIndex, $mode

    Write-Host ("Dispatching mode={0} with sequence_id={1}" -f $mode, $sequenceId)
    Start-DevModeRun -Mode $mode -SequenceId $sequenceId -Settings $settings
    Wait-ForRun -SequenceId $sequenceId -Mode $mode -AllowFailureModes $normalizedAllowFailures -Settings $settings
}

