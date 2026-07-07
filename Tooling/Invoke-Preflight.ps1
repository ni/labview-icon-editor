#Requires -Version 7.0
<#[
.SYNOPSIS
    Shared preflight for local entrypoints.

.DESCRIPTION
    Enforces worktree-root usage, resolves artifact roots, logs run context,
    and optionally cleans known output folders before/after a run.
#>

function Convert-BoundParametersToArgumentList {
    param(
        [hashtable]$BoundParameters
    )

    $argList = @()
    if (-not $BoundParameters) {
        return $argList
    }

    foreach ($key in $BoundParameters.Keys) {
        $value = $BoundParameters[$key]
        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) {
                $argList += "-$key"
            } else {
                $argList += "-${key}:`$false"
            }
            continue
        }

        if ($value -is [bool]) {
            $argList += "-$key"
            $argList += $value.ToString().ToLowerInvariant()
            continue
        }

        if ($value -is [array]) {
            foreach ($entry in $value) {
                $argList += "-$key"
                $argList += [string]$entry
            }
            continue
        }

        $argList += "-$key"
        $argList += [string]$value
    }

    return $argList
}

function Resolve-RepoRoot {
    param(
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        throw 'RepoRoot is required.'
    }

    return (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
}

function Get-RepoRelativePath {
    param(
        [string]$RepoRoot,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot) -or [string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    try {
        $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
        $relative = [System.IO.Path]::GetRelativePath($repoFull, $Path)
        if (-not [string]::IsNullOrWhiteSpace($relative)) {
            return $relative
        }
    } catch {
        return $Path
    }

    return $Path
}

function New-RunId {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    return "{0}-{1}" -f $timestamp, $suffix
}

function Test-TruthyEnv {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function Resolve-ArtifactRoot {
    param(
        [string]$WorktreeRoot,
        [string]$RunId,
        [string]$ArtifactRootOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($ArtifactRootOverride)) {
        return [System.IO.Path]::GetFullPath($ArtifactRootOverride)
    }

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = New-RunId
    }

    $base = Join-Path -Path $WorktreeRoot -ChildPath 'artifacts'
    return (Join-Path -Path $base -ChildPath $RunId)
}

function Get-CleanRoomTargetList {
    param(
        [string]$RepoRoot
    )

    $targets = @(
        (Join-Path $RepoRoot 'TestResults'),
        (Join-Path $RepoRoot 'builds'),
        (Join-Path $RepoRoot 'Tooling\logs'),
        (Join-Path $RepoRoot 'missing_files.txt'),
        (Join-Path $RepoRoot '.github\actions\missing-in-project\missing_files.txt'),
        (Join-Path $RepoRoot '.github\actions\run-unit-tests\UnitTestReport.xml'),
        (Join-Path $RepoRoot 'Icon_Editor_Files_In_LV_Installation_Diagnostics.csv')
    )

    return $targets
}

function Invoke-PreflightCleanup {
    param(
        [string]$RepoRoot,
        [string]$Phase = 'before'
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return
    }

    Write-Host ("Clean-room ({0}): removing known output folders." -f $Phase)

    foreach ($target in (Get-CleanRoomTargetList -RepoRoot $RepoRoot)) {
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        if (Test-Path -Path $target) {
            try {
                Remove-Item -Path $target -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning ("Failed to remove {0}: {1}" -f $target, $_.Exception.Message)
            }
        }
    }

    $pluginDir = Join-Path $RepoRoot 'resource\plugins'
    if (Test-Path -Path $pluginDir) {
        try {
            Get-ChildItem -Path $pluginDir -Filter 'lv_icon*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning ("Failed to remove lv_icon*.lvlibp under {0}: {1}" -f $pluginDir, $_.Exception.Message)
        }
    }

    try {
        Get-ChildItem -Path $RepoRoot -Filter 'Icon_Editor_Files_In_LV_Installation_Diagnostics*.csv' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning ("Failed to remove diagnostics CSV files: {0}" -f $_.Exception.Message)
    }
}

function Write-PreflightContext {
    param(
        [string]$RepoRoot,
        [string]$WorktreeRoot,
        [string]$ArtifactRoot,
        [string]$RunId,
        [string]$LabVIEWVersion,
        [string]$LabVIEWBitness,
        [string]$RunnerCliPath
    )

    $runnerRoot = $env:LVIE_RUNNER_ROOT
    $contractPath = $env:LVIE_RUNNER_CONTRACT_PATH
    $lockRoot = $env:LVIE_LOCK_ROOT
    $logRoot = $env:LVIE_LOG_ROOT

    $contextLine = "LVIE_CONTEXT repo_root={0} worktree_root={1} run_id={2} artifact_root={3} labview_version={4} labview_bitness={5} runner_root={6} lock_root={7} log_root={8} contract_path={9} runner_cli_path={10}" -f `
        $RepoRoot, $WorktreeRoot, $RunId, $ArtifactRoot, $LabVIEWVersion, $LabVIEWBitness, $runnerRoot, $lockRoot, $logRoot, $contractPath, $RunnerCliPath
    Write-Host $contextLine

    if (-not [string]::IsNullOrWhiteSpace($ArtifactRoot)) {
        try {
            if (-not (Test-Path -Path $ArtifactRoot)) {
                New-Item -Path $ArtifactRoot -ItemType Directory -Force | Out-Null
            }
            $contextPath = Join-Path $ArtifactRoot 'context.json'
            $contextObj = [pscustomobject]@{
                repo_root       = $RepoRoot
                worktree_root   = $WorktreeRoot
                run_id          = $RunId
                artifact_root   = $ArtifactRoot
                runner_root     = $runnerRoot
                lock_root       = $lockRoot
                log_root        = $logRoot
                contract_path   = $contractPath
                runner_cli_path = $RunnerCliPath
                labview_version = $LabVIEWVersion
                labview_bitness = $LabVIEWBitness
                timestamp_utc   = (Get-Date).ToUniversalTime().ToString('o')
            }
            $contextObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $contextPath -Encoding ascii
        } catch {
            Write-Warning ("Failed to write preflight context file: {0}" -f $_.Exception.Message)
        }
    }
}

function Invoke-Preflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [string]$WorktreeRoot,

        [string]$LabVIEWVersion,

        [string]$LabVIEWBitness,

        [switch]$SkipWorktreeRootCheck,

        [switch]$AutoWorktree,

        [string]$ScriptPath,

        [string[]]$ScriptArguments,

        [string]$RunId,

        [string]$ArtifactRoot,

        [switch]$CleanRoom,

        [switch]$RequireGcli,

        [string]$RunnerCliPath,

        [switch]$RequireRunnerCli
    )

    $resolvedRepoRoot = Resolve-RepoRoot -RepoRoot $RepoRoot

    $contractScript = Join-Path $resolvedRepoRoot 'Tooling\support\RunnerContract.ps1'
    if (Test-Path -Path $contractScript) {
        . $contractScript
        $contractPath = Resolve-RunnerContractPath -ContractPath $env:LVIE_RUNNER_CONTRACT_PATH -RunnerRoot $env:LVIE_RUNNER_ROOT -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
        $contract = Get-RunnerContract -ContractPath $contractPath -RunnerRoot $env:LVIE_RUNNER_ROOT -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
        if ($contract) {
            Set-RunnerContractEnvironment -Contract $contract -ContractPath $contractPath
        } elseif ($env:LVIE_REQUIRE_RUNNER_CONTRACT -eq '1') {
            throw "Runner contract not found. Run Tooling\\Setup-Runner.ps1 to create $contractPath."
        }
    }

    $runnerCliResolved = $null
    $ensureCliScript = Join-Path $resolvedRepoRoot 'Tooling\Ensure-RunnerCli.ps1'
    if (Test-Path -Path $ensureCliScript) {
        try {
            $ensureResult = & $ensureCliScript -RepoRoot $resolvedRepoRoot -RunnerCliPath $RunnerCliPath -Require:$RequireRunnerCli
            if ($ensureResult -and $ensureResult.Path) {
                $runnerCliResolved = $ensureResult.Path
            }
        } catch {
            throw $_
        }
    }

    $worktreeGuard = Join-Path $resolvedRepoRoot 'Tooling\support\WorktreeGuard.ps1'
    if (-not (Test-Path -Path $worktreeGuard)) {
        throw "WorktreeGuard.ps1 not found at $worktreeGuard"
    }
    . $worktreeGuard

    $resolvedWorktreeRoot = Resolve-WorktreeRoot -WorktreeRoot $WorktreeRoot
    $repoFull = ConvertTo-NormalizedPath -Path $resolvedRepoRoot
    $rootFull = ConvertTo-NormalizedPath -Path $resolvedWorktreeRoot

    $skipGuard = Test-WorktreeGuardSkip -Skip:$SkipWorktreeRootCheck
    $underRoot = $repoFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)

    if (-not $underRoot -and -not $skipGuard) {
        if ($AutoWorktree -and $ScriptPath) {
            $newWorktreeScript = Join-Path $resolvedRepoRoot 'Tooling\New-CIWorktree.ps1'
            if (-not (Test-Path -Path $newWorktreeScript)) {
                throw "New-CIWorktree.ps1 not found at $newWorktreeScript"
            }

            $relativeScript = Get-RepoRelativePath -RepoRoot $resolvedRepoRoot -Path $ScriptPath
            Write-Host ("RepoRoot '{0}' is not under worktree root '{1}'. Re-invoking from worktree..." -f $resolvedRepoRoot, $resolvedWorktreeRoot)
            $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot

            $envName = $env:LVIE_WORKTREE_NAME
            $envPrefix = $env:LVIE_WORKTREE_NAME_PREFIX
            $noRepoPrefix = Test-TruthyEnv -Value $env:LVIE_WORKTREE_NO_REPO_PREFIX
            $worktreeRef = if ([string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_REF)) { 'HEAD' } else { $env:LVIE_WORKTREE_REF }

            $suffix = if ([string]::IsNullOrWhiteSpace($envName)) {
                $prefix = if ([string]::IsNullOrWhiteSpace($envPrefix)) { 'ci-guard' } else { $envPrefix.Trim() }
                "{0}-{1}" -f $prefix, (Get-Date -Format 'yyyyMMdd-HHmmss')
            } else {
                $envName.Trim()
            }

            $worktreeArgs = @(
                '-Ref', $worktreeRef,
                '-Name', $suffix,
                '-WorktreeRoot', $resolvedWorktreeRoot
            )
            if ($noRepoPrefix) {
                $worktreeArgs += '-NoRepoNamePrefix'
            }

            $worktreePath = & $newWorktreeScript @worktreeArgs
            Write-Host ("Using worktree: {0}" -f $worktreePath)

            Push-Location -Path $worktreePath
            try {
                $scriptFull = if ([System.IO.Path]::IsPathRooted($relativeScript)) {
                    $relativeScript
                } else {
                    Join-Path $worktreePath $relativeScript
                }

                if (-not (Test-Path -Path $scriptFull)) {
                    throw "Script not found at $scriptFull"
                }

                & pwsh -NoProfile -File $scriptFull @ScriptArguments
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                    throw "Command failed with exit code $LASTEXITCODE."
                }
            } finally {
                Pop-Location
            }
            return [pscustomobject]@{
                Reinvoked = $true
                RepoRoot = $resolvedRepoRoot
            }
        }

        throw ("RepoRoot '{0}' is not under worktree root '{1}'. Set LVIE_WORKTREE_ROOT or run from a worktree." -f $repoFull.TrimEnd('\'), $rootFull.TrimEnd('\'))
    }

    if ($CleanRoom) {
        Invoke-PreflightCleanup -RepoRoot $resolvedRepoRoot -Phase 'before'
    }

    $resolvedRunId = if ([string]::IsNullOrWhiteSpace($RunId)) {
        if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUN_ID)) { $env:LVIE_RUN_ID } else { New-RunId }
    } else { $RunId }

    $explicitArtifacts = (-not [string]::IsNullOrWhiteSpace($ArtifactRoot)) -or `
        (-not [string]::IsNullOrWhiteSpace($RunId)) -or `
        (-not [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) -or `
        $CleanRoom

    $enableArtifacts = $explicitArtifacts -or `
        ($env:GITHUB_ACTIONS -ne 'true') -or `
        ($env:LVIE_ENABLE_ARTIFACT_ROOT -eq '1')

    $resolvedArtifactRoot = $null
    if ($enableArtifacts) {
        $resolvedArtifactRoot = if (-not [string]::IsNullOrWhiteSpace($ArtifactRoot)) {
            Resolve-ArtifactRoot -WorktreeRoot $resolvedWorktreeRoot -RunId $resolvedRunId -ArtifactRootOverride $ArtifactRoot
        } elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) {
            $env:LVIE_ARTIFACT_ROOT
        } else {
            Resolve-ArtifactRoot -WorktreeRoot $resolvedWorktreeRoot -RunId $resolvedRunId -ArtifactRootOverride $null
        }
        if ($resolvedArtifactRoot) {
            $resolvedArtifactRoot = [System.IO.Path]::GetFullPath($resolvedArtifactRoot)
        }
        if (-not (Test-Path -Path $resolvedArtifactRoot)) {
            New-Item -Path $resolvedArtifactRoot -ItemType Directory -Force | Out-Null
        }
    }

    $env:LVIE_RUN_ID = $resolvedRunId
    if ($resolvedArtifactRoot) {
        $env:LVIE_ARTIFACT_ROOT = $resolvedArtifactRoot
    }
    $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot

    if ($RequireGcli -and -not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw 'g-cli.exe not found in PATH.'
    }

    $labviewInfo = $null
    $resolvedLabVIEWVersion = $LabVIEWVersion
    $versionHelper = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $versionHelper) {
        try {
            . $versionHelper
            $labviewInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
            if ($labviewInfo) {
                $resolvedLabVIEWVersion = $labviewInfo.Year
            }
        } catch {
            $labviewInfo = $null
        }
    }

    Write-PreflightContext -RepoRoot $resolvedRepoRoot -WorktreeRoot $resolvedWorktreeRoot -ArtifactRoot $resolvedArtifactRoot -RunId $resolvedRunId -LabVIEWVersion $resolvedLabVIEWVersion -LabVIEWBitness $LabVIEWBitness -RunnerCliPath $runnerCliResolved

    return [pscustomobject]@{
        Reinvoked           = $false
        RepoRoot            = $resolvedRepoRoot
        WorktreeRoot        = $resolvedWorktreeRoot
        ArtifactRoot        = $resolvedArtifactRoot
        RunId               = $resolvedRunId
        LabVIEWVersion      = $resolvedLabVIEWVersion
        LabVIEWInfo         = $labviewInfo
        LabVIEWBitness      = $LabVIEWBitness
        CleanRoomAfter      = $CleanRoom
        RunnerCliPath       = $runnerCliResolved
    }
}



