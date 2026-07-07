#Requires -Version 7.0
<#
.SYNOPSIS
    Shared helpers for LabVIEW stage execution.
#>

$ErrorActionPreference = 'Stop'

function Get-OutputTail {
    param(
        [string[]]$Lines,
        [int]$MaxLines = 20
    )

    if (-not $Lines -or $Lines.Count -eq 0) {
        return @()
    }

    if ($Lines.Count -le $MaxLines) {
        return @($Lines)
    }

    $start = $Lines.Count - $MaxLines
    return @($Lines[$start..($Lines.Count - 1)])
}

function New-LabVIEWStageStepLog {
    param(
        [string]$Name,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [int]$ExitCode,
        [string]$ErrorMessage,
        [string[]]$OutputLines
    )

    $durationMs = [int]([Math]::Round(($EndTime - $StartTime).TotalMilliseconds))
    return [pscustomobject]@{
        Name       = $Name
        StartUtc   = $StartTime.ToUniversalTime().ToString('o')
        EndUtc     = $EndTime.ToUniversalTime().ToString('o')
        DurationMs = $durationMs
        ExitCode   = $ExitCode
        Error      = $ErrorMessage
        OutputTail = Get-OutputTail -Lines $OutputLines -MaxLines 20
    }
}

function New-LabVIEWStageLogContext {
    param(
        [string]$StageName,
        [string]$RepoRoot,
        [string]$LogRootOverride
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeStage = ($StageName -replace '[^a-zA-Z0-9_.-]', '_')
    $logRoot = if ([string]::IsNullOrWhiteSpace($LogRootOverride)) {
        if (-not [string]::IsNullOrWhiteSpace($env:LVIE_STAGE_LOG_ROOT)) {
            $env:LVIE_STAGE_LOG_ROOT
        } else {
            Join-Path $RepoRoot 'TestResults\agent-logs'
        }
    } else {
        $LogRootOverride
    }

    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    $logFile = Join-Path $logRoot ("labview-stage-{0}-{1}.jsonl" -f $safeStage, $timestamp)
    $summaryFile = Join-Path $logRoot ("labview-stage-{0}-{1}-summary.json" -f $safeStage, $timestamp)

    return [pscustomobject]@{
        LogRoot     = $logRoot
        LogFile     = $logFile
        SummaryFile = $summaryFile
        Timestamp   = $timestamp
    }
}

function Write-LabVIEWStageLogEntry {
    param(
        [string]$LogFile,
        [psobject]$Entry
    )

    $json = $Entry | ConvertTo-Json -Depth 10 -Compress
    Add-Content -Path $LogFile -Value $json
}

function Write-LabVIEWStageSummary {
    param(
        [string]$SummaryFile,
        [psobject[]]$Entries,
        [string]$StageName,
        [string]$LogFile
    )

    $total = if ($Entries) { $Entries.Count } else { 0 }
    $skipped = if ($Entries) { ($Entries | Where-Object { $_.Result.Skipped }).Count } else { 0 }
    $succeeded = if ($Entries) { ($Entries | Where-Object { $_.Result.Succeeded }).Count } else { 0 }
    $failed = $total - $skipped - $succeeded

    $summary = [pscustomobject]@{
        StageName  = $StageName
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Total      = $total
        Succeeded  = $succeeded
        Failed     = $failed
        Skipped    = $skipped
        LogFile    = $LogFile
    }

    $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryFile

    Write-Host ("LabVIEWStage summary: {0} total={1} ok={2} failed={3} skipped={4}" -f $StageName, $total, $succeeded, $failed, $skipped)
    Write-Host ("LabVIEWStage log: {0}" -f $LogFile)
    Write-Host ("LabVIEWStage summary: {0}" -f $SummaryFile)
}

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Resolve-LabVIEWVersion {
    param(
        [string]$VersionInput,
        [string]$RepoRoot
    )

    $resolvedVersion = $VersionInput
    $helper = Join-Path -Path $RepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $helper) {
        . $helper
        $info = Get-LabVIEWVersionInfo -VersionInput $VersionInput -RepoRoot $RepoRoot
        if ($info -and $info.Year) {
            $resolvedVersion = $info.Year
        }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
        $resolvedVersion = '2021'
    }
    return $resolvedVersion
}

function Get-BitnessList {
    param(
        [string]$BitnessInput
    )

    if ([string]::IsNullOrWhiteSpace($BitnessInput)) {
        return @('64')
    }

    $normalized = $BitnessInput.Trim().ToLowerInvariant()
    if (@('both', 'all', 'auto') -contains $normalized) {
        return @('64', '32')
    }

    $parts = $normalized -split '[,; ]+' | Where-Object { $_ }
    $bitnesses = foreach ($part in $parts) {
        switch ($part) {
            '32' { '32' }
            '64' { '64' }
        }
    }

    $bitnesses = $bitnesses | Where-Object { $_ } | Select-Object -Unique
    if (-not $bitnesses) {
        return @('64')
    }

    return @($bitnesses)
}

function Resolve-BitnessList {
    param(
        [string[]]$Bitnesses,
        [string]$FallbackInput
    )

    if ($Bitnesses -and $Bitnesses.Count -gt 0) {
        return @($Bitnesses | Select-Object -Unique)
    }

    return Get-BitnessList -BitnessInput $FallbackInput
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

function Invoke-LabVIEWScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $rawOutput = & $pwsh -NoProfile -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    foreach ($entry in $rawOutput) {
        if ($null -ne $entry) {
            $lines += [string]$entry
        }
    }
    $lines | Out-Host
    return [pscustomobject]@{
        ExitCode    = $exitCode
        OutputLines = $lines
    }
}

function Invoke-LabVIEWClose {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness
    )

    $closeScript = Join-Path -Path $RepoRoot -ChildPath '.github\actions\close-labview\Close_LabVIEW.ps1'
    if (-not (Test-Path -Path $closeScript)) {
        throw "Close_LabVIEW.ps1 not found at $closeScript"
    }

    return Invoke-LabVIEWScript -ScriptPath $closeScript -Arguments @(
        '-LabVIEWVersion', $LabVIEWVersion,
        '-SupportedBitness', $Bitness
    )
}

function Invoke-DevModeNoLabVIEW {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness,
        [ValidateSet('enable', 'disable')]
        [string]$Mode
    )

    $scriptPath = if ($Mode -eq 'enable') {
        Join-Path $RepoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
    } else {
        Join-Path $RepoRoot 'Tooling\Revert-DevelopmentMode-NoLabVIEW.ps1'
    }

    if (-not (Test-Path -Path $scriptPath)) {
        throw "Dev mode script not found at $scriptPath"
    }

    return Invoke-LabVIEWScript -ScriptPath $scriptPath -Arguments @(
        '-LabVIEWVersion', $LabVIEWVersion,
        '-SupportedBitness', $Bitness,
        '-RepoRoot', $RepoRoot
    )
}

function New-LabVIEWStageContext {
    param(
        [string]$StageName,
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness,
        [int]$ConnectTimeoutMs
    )

    return [pscustomobject]@{
        StageName        = $StageName
        RepoRoot         = $RepoRoot
        LabVIEWVersion   = $LabVIEWVersion
        Bitness          = $Bitness
        ConnectTimeoutMs = $ConnectTimeoutMs
    }
}

function Invoke-LabVIEWStage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StageName,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWVersion,

        [string[]]$Bitnesses,

        [int]$ConnectTimeoutMs = 120000,

        [switch]$DevModeNoLabVIEW,

        [switch]$CloseBetweenStages,

        [switch]$SkipOnBaselineFailure,

        [string]$LogRoot,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $closeBetweenStagesEnabled = $CloseBetweenStages.IsPresent -or -not $PSBoundParameters.ContainsKey('CloseBetweenStages')
    $skipOnBaselineFailureEnabled = $SkipOnBaselineFailure.IsPresent -or -not $PSBoundParameters.ContainsKey('SkipOnBaselineFailure')

    $resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
    $resolvedVersion = Resolve-LabVIEWVersion -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
    $bitnessList = Resolve-BitnessList -Bitnesses $Bitnesses -FallbackInput $env:LABVIEW_BITNESS

    $logContext = New-LabVIEWStageLogContext -StageName $StageName -RepoRoot $resolvedRepoRoot -LogRootOverride $LogRoot
    $results = @()
    $logEntries = @()
    foreach ($bitness in $bitnessList) {
        $bitnessStart = Get-Date
        $closeBeforeInfo = $null
        $baselineInfo = $null
        $enableInfo = $null
        $actionInfo = $null
        $revertInfo = $null
        $closeAfterInfo = $null
        $resultEntry = $null

        if (-not (Get-LabVIEWInstallRoot -Version $resolvedVersion -Bitness $bitness)) {
            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $false
                Skipped    = $true
                SkipReason = "LabVIEW $resolvedVersion ($bitness-bit) install not found."
                ExitCode   = $null
                Error      = $null
            }
            $results += $resultEntry
            $bitnessEnd = Get-Date
            $logEntry = [pscustomobject]@{
                StageName       = $StageName
                LabVIEWVersion  = $resolvedVersion
                Bitness         = $bitness
                RepoRoot        = $resolvedRepoRoot
                StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
                EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
                DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
                DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
                CloseBetweenStages = [bool]$closeBetweenStagesEnabled
                Result          = $resultEntry
                Steps           = [pscustomobject]@{
                    CloseBefore   = $closeBeforeInfo
                    BaselineRevert = $baselineInfo
                    EnableDevMode = $enableInfo
                    Action        = $actionInfo
                    RevertDevMode  = $revertInfo
                    CloseAfter    = $closeAfterInfo
                }
            }
            $logEntries += $logEntry
            try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write stage log entry. {0}" -f $_.Exception.Message) }
            continue
        }

        if ($closeBetweenStagesEnabled) {
            $closeStart = Get-Date
            $closeResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
            $closeEnd = Get-Date
            $closeBeforeInfo = New-LabVIEWStageStepLog -Name 'close-before' -StartTime $closeStart -EndTime $closeEnd -ExitCode $closeResult.ExitCode -ErrorMessage $null -OutputLines $closeResult.OutputLines
        }

        if ($DevModeNoLabVIEW) {
            $baselineStart = Get-Date
            $baseline = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'disable'
            $baselineEnd = Get-Date
            $baselineInfo = New-LabVIEWStageStepLog -Name 'baseline-revert' -StartTime $baselineStart -EndTime $baselineEnd -ExitCode $baseline.ExitCode -ErrorMessage $null -OutputLines $baseline.OutputLines
            if ($baseline.ExitCode -ne 0) {
                if ($skipOnBaselineFailureEnabled) {
                    $resultEntry = [pscustomobject]@{
                        StageName  = $StageName
                        Bitness    = $bitness
                        Succeeded  = $false
                        Skipped    = $true
                        SkipReason = "Baseline dev mode revert failed with exit code $($baseline.ExitCode)."
                        ExitCode   = $baseline.ExitCode
                        Error      = $null
                    }
                    if ($closeBetweenStagesEnabled) {
                        $closeAfterStart = Get-Date
                        $closeAfterResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
                        $closeAfterEnd = Get-Date
                        $closeAfterInfo = New-LabVIEWStageStepLog -Name 'close-after' -StartTime $closeAfterStart -EndTime $closeAfterEnd -ExitCode $closeAfterResult.ExitCode -ErrorMessage $null -OutputLines $closeAfterResult.OutputLines
                    }
                    $results += $resultEntry
                    $bitnessEnd = Get-Date
                    $logEntry = [pscustomobject]@{
                        StageName       = $StageName
                        LabVIEWVersion  = $resolvedVersion
                        Bitness         = $bitness
                        RepoRoot        = $resolvedRepoRoot
                        StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
                        EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
                        DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
                        DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
                        CloseBetweenStages = [bool]$closeBetweenStagesEnabled
                        Result          = $resultEntry
                        Steps           = [pscustomobject]@{
                            CloseBefore    = $closeBeforeInfo
                            BaselineRevert = $baselineInfo
                            EnableDevMode  = $enableInfo
                            Action         = $actionInfo
                            RevertDevMode  = $revertInfo
                            CloseAfter     = $closeAfterInfo
                        }
                    }
                    $logEntries += $logEntry
                    try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write baseline log entry. {0}" -f $_.Exception.Message) }
                    continue
                }
                throw "Baseline dev mode revert failed with exit code $($baseline.ExitCode)."
            }
        }

        $exitCode = $null
        $errorMessage = $null
        $devModeEnabled = $false
        try {
            if ($DevModeNoLabVIEW) {
                $enableStart = Get-Date
                $enable = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'enable'
                $enableEnd = Get-Date
                $enableInfo = New-LabVIEWStageStepLog -Name 'enable-devmode' -StartTime $enableStart -EndTime $enableEnd -ExitCode $enable.ExitCode -ErrorMessage $null -OutputLines $enable.OutputLines
                if ($enable.ExitCode -ne 0) {
                    $exitCode = $enable.ExitCode
                    throw "Dev mode enable failed with exit code $($enable.ExitCode)."
                }
                $devModeEnabled = $true
            }

            $context = New-LabVIEWStageContext -StageName $StageName -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -ConnectTimeoutMs $ConnectTimeoutMs
            $actionStart = Get-Date
            $actionResult = $null
            $actionError = $null
            try {
                $actionResult = & $Action $context
            } catch {
                $actionError = $_.Exception.Message
            }
            $actionEnd = Get-Date

            if ($actionResult -is [int]) {
                $exitCode = $actionResult
            } elseif ($actionResult -and $null -ne $actionResult.ExitCode) {
                $exitCode = $actionResult.ExitCode
            } elseif ($null -ne $LASTEXITCODE) {
                $exitCode = $LASTEXITCODE
            } else {
                $exitCode = 0
            }

            $actionOutput = if ($actionResult -and $actionResult.OutputLines) { $actionResult.OutputLines } else { $null }
            $actionInfo = New-LabVIEWStageStepLog -Name 'action' -StartTime $actionStart -EndTime $actionEnd -ExitCode $exitCode -ErrorMessage $actionError -OutputLines $actionOutput

            if ($actionError) {
                throw $actionError
            }

            if ($exitCode -ne 0) {
                throw "Stage '$StageName' failed with exit code $exitCode."
            }

            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $true
                Skipped    = $false
                SkipReason = $null
                ExitCode   = $exitCode
                Error      = $null
            }
        } catch {
            $errorMessage = $_.Exception.Message
            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $false
                Skipped    = $false
                SkipReason = $null
                ExitCode   = $exitCode
                Error      = $errorMessage
            }
        } finally {
            if ($devModeEnabled) {
                $revertStart = Get-Date
                $revertResult = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'disable'
                $revertEnd = Get-Date
                $revertInfo = New-LabVIEWStageStepLog -Name 'revert-devmode' -StartTime $revertStart -EndTime $revertEnd -ExitCode $revertResult.ExitCode -ErrorMessage $null -OutputLines $revertResult.OutputLines
            }
            if ($closeBetweenStagesEnabled) {
                $closeAfterStart = Get-Date
                $closeAfterResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
                $closeAfterEnd = Get-Date
                $closeAfterInfo = New-LabVIEWStageStepLog -Name 'close-after' -StartTime $closeAfterStart -EndTime $closeAfterEnd -ExitCode $closeAfterResult.ExitCode -ErrorMessage $null -OutputLines $closeAfterResult.OutputLines
            }
        }

        $results += $resultEntry
        $bitnessEnd = Get-Date
        $logEntry = [pscustomobject]@{
            StageName       = $StageName
            LabVIEWVersion  = $resolvedVersion
            Bitness         = $bitness
            RepoRoot        = $resolvedRepoRoot
            StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
            EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
            DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
            DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
            CloseBetweenStages = [bool]$closeBetweenStagesEnabled
            Result          = $resultEntry
            Steps           = [pscustomobject]@{
                CloseBefore    = $closeBeforeInfo
                BaselineRevert = $baselineInfo
                EnableDevMode  = $enableInfo
                Action         = $actionInfo
                RevertDevMode  = $revertInfo
                CloseAfter     = $closeAfterInfo
            }
        }
        $logEntries += $logEntry
        try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write stage log entry. {0}" -f $_.Exception.Message) }
    }

    try { Write-LabVIEWStageSummary -SummaryFile $logContext.SummaryFile -Entries $logEntries -StageName $StageName -LogFile $logContext.LogFile } catch { Write-Verbose ("LabVIEWStage: failed to write summary. {0}" -f $_.Exception.Message) }
    return $results
}
