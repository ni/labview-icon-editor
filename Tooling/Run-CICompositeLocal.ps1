#Requires -Version 7.0
<#
.SYNOPSIS
    Runs a local, CI-composite parity sequence for LabVIEW Icon Editor.

.DESCRIPTION
    Executes the key LabVIEW steps from ci-composite.yml locally:
    - Verify IE Paths gate (version 32/64)
    - Apply VIPC dependencies (version 32/64)
    - Missing-in-project checks (version 32/64)
    - Unit tests (version 32/64)
    - Build PPLs (version 32/64) + rename
    - Build VIP (version 64)

    GitHub-only steps (workflow metadata, artifact upload) are not included.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER LabVIEWBitness
    Bitness to run: both, 32, 64, or installed (auto-detect).

.PARAMETER AllowVersionMismatch
    Allow LabVIEW version mismatches against .lvversion (not recommended).

.PARAMETER DryRun
    Validate version contract and installed LabVIEW bitness without running jobs.

.PARAMETER SkipVerifyIEPaths
    Skip the Verify IE Paths gate.

.PARAMETER EnsureCleanState
    Revert dev mode before enabling it for Verify IE Paths.

.PARAMETER SkipVipc
    Skip applying VIPC dependencies.

.PARAMETER SkipMissingInProject
    Skip missing-in-project checks.

.PARAMETER SkipUnitTests
    Skip unit tests.

.PARAMETER SkipBuildPpl
    Skip PPL builds.

.PARAMETER SkipBuildVip
    Skip VIP build.

.PARAMETER SkipViValidate
    Skip pylavi vi_validate checks.

.PARAMETER ViValidateConfigPath
    Path to pylavi vi_validate config file (relative to repo root).

.PARAMETER ViValidateProfile
    vi_validate profile: strict, legacy, or both (default: strict).

.PARAMETER ViValidateReportOnly
    Emit vi_validate warnings but do not fail the run.

.PARAMETER ViValidateSkipVersionGate
    Skip passing --eq to vi_validate (useful for legacy cleanup runs).

.PARAMETER ViValidateOnly
    Run only the pylavi vi_validate gate and exit.

.PARAMETER UseLabVIEWDevMode
    Use LabVIEW + g-cli for dev-mode toggles (default: false).

.PARAMETER BumpType
    Version bump type when computing local version info (major/minor/patch/none).

.PARAMETER ConnectTimeoutMs
    g-cli connect timeout passed to relevant scripts.

.PARAMETER ProcessTimeoutMs
    g-cli process timeout passed to relevant scripts.

.PARAMETER StatusFileTimeoutMs
    Timeout for VerifyIEPaths status file creation.

.PARAMETER VipcPath
    Path to the VIPC file (relative to repo root).

.PARAMETER VipbPath
    Path to the VIPB file (relative to repo root).

.PARAMETER ReleaseNotesPath
    Path to release notes file (relative to repo root).

.PARAMETER RepoRoot
    Optional repository root override.

.PARAMETER WorktreeRoot
    Optional override for the worktree root used by guardrails.

.PARAMETER SkipWorktreeRootCheck
    Skip enforcing that RepoRoot is under the worktree root.

.PARAMETER AutoWorktree
    Auto-create a short-path worktree and re-run from there when needed.

.PARAMETER RunId
    Optional run identifier used for artifact isolation.

.PARAMETER ArtifactRoot
    Optional override for the artifact output root.

.PARAMETER CleanRoom
    If set, purge known output folders before and after the run.

.PARAMETER RunnerCliPath
    Optional path to runner-cli for runner contract validation.

.PARAMETER RequireRunnerCli
    Require runner-cli for contract validation (default true).

.PARAMETER Major
    Override major version.

.PARAMETER Minor
    Override minor version.

.PARAMETER Patch
    Override patch version.

.PARAMETER Build
    Override build number.

.PARAMETER Commit
    Override commit hash.

.PARAMETER Orchestrated
    Internal flag used by Invoke-WorktreeOrchestrator to prevent recursion.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('both', '32', '64', 'installed')]
    [string]$LabVIEWBitness = 'both',

    [switch]$AllowVersionMismatch,

    [switch]$DryRun,

    [switch]$SkipVerifyIEPaths,
    [switch]$EnsureCleanState,
    [switch]$SkipVipc,
    [switch]$SkipMissingInProject,
    [switch]$SkipUnitTests,
    [switch]$SkipBuildPpl,
    [switch]$SkipBuildVip,

    [switch]$SkipViValidate,

    [Parameter(Mandatory = $false)]
    [string]$ViValidateConfigPath = 'Tooling/pylavi/vi-validate.yml',

    [Parameter(Mandatory = $false)]
    [ValidateSet('strict', 'legacy', 'both')]
    [string]$ViValidateProfile = 'strict',

    [switch]$ViValidateReportOnly,

    [switch]$ViValidateSkipVersionGate,

    [switch]$ViValidateOnly,

    [switch]$UseLabVIEWDevMode,

    [Parameter(Mandatory = $false)]
    [ValidateSet('major', 'minor', 'patch', 'none')]
    [string]$BumpType = 'patch',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 180000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$StatusFileTimeoutMs = 60000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3600)]
    [int]$VipmTimeoutSeconds = 900,

    [Parameter(Mandatory = $false)]
    [ValidateSet('always', 'if-running')]
    [string]$CloseLabVIEWMode = 'if-running',

    [Parameter(Mandatory = $false)]
    [string]$VipcPath = '.github/actions/apply-vipc/runner_dependencies.vipc',

    [Parameter(Mandatory = $false)]
    [string]$VipbPath = 'Tooling/deployment/NI Icon editor.vipb',

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotesPath = 'Tooling/deployment/release_notes.md',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [switch]$SkipWorktreeRootCheck,

    [switch]$AutoWorktree,

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRoot,

    [switch]$CleanRoom,

    [Parameter(Mandatory = $false)]
    [string]$RunnerCliPath,

    [switch]$RequireRunnerCli,

    [Parameter(Mandatory = $false)]
    [int]$Major,

    [Parameter(Mandatory = $false)]
    [int]$Minor,

    [Parameter(Mandatory = $false)]
    [int]$Patch,

    [Parameter(Mandatory = $false)]
    [int]$Build,

    [Parameter(Mandatory = $false)]
    [string]$Commit,

    [switch]$Orchestrated
)

$ErrorActionPreference = 'Stop'

if (-not $Orchestrated) {
    $orchestrator = Join-Path $PSScriptRoot 'Invoke-WorktreeOrchestrator.ps1'
    if (Test-Path -Path $orchestrator) {
        Write-Warning "Direct execution of Run-CICompositeLocal.ps1 is deprecated. Use Invoke-WorktreeOrchestrator.ps1."

        $forward = @()
        foreach ($entry in $PSBoundParameters.GetEnumerator()) {
            if ($entry.Key -eq 'Orchestrated') {
                continue
            }

            $paramName = "-$($entry.Key)"
            $value = $entry.Value

            if ($value -is [System.Management.Automation.SwitchParameter]) {
                if ($value.IsPresent) {
                    $forward += $paramName
                }
                continue
            }

            if ($value -is [bool]) {
                $forward += $paramName
                $forward += $value.ToString().ToLowerInvariant()
                continue
            }

            if ($value -is [array]) {
                $forward += $paramName
                $forward += $value
                continue
            }

            $forward += $paramName
            $forward += $value
        }

        $forward += '-Orchestrated'
        & $orchestrator -Run -RunScript $PSCommandPath -RunArgs $forward
        exit $LASTEXITCODE
    } else {
        Write-Warning "Invoke-WorktreeOrchestrator.ps1 not found; continuing direct execution."
    }
}

if ($ViValidateOnly -and $SkipViValidate) {
    throw "ViValidateOnly cannot be combined with -SkipViValidate."
}

$customViConfigSpecified = $PSBoundParameters.ContainsKey('ViValidateConfigPath')
$skipViVersionSpecified = $PSBoundParameters.ContainsKey('ViValidateSkipVersionGate')

function Test-ForceNoLabVIEWDevMode {
    $value = $env:LVIE_FORCE_NO_LABVIEW_DEVMODE
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }
    $normalized = $value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

$forceNoLabVIEW = Test-ForceNoLabVIEWDevMode
if ($forceNoLabVIEW -and $UseLabVIEWDevMode) {
    Write-Host 'LVIE_FORCE_NO_LABVIEW_DEVMODE=1; ignoring -UseLabVIEWDevMode.'
}
$script:PreferNoLabVIEWDevMode = $forceNoLabVIEW -or (-not $UseLabVIEWDevMode)

function Initialize-CsvHeader {
    param(
        [string]$Path,
        [string]$Header
    )

    if (-not (Test-Path -Path $Path)) {
        $Header | Set-Content -Path $Path
    }
}

function Write-StepHistoryEntry {
    param(
        [string]$Label,
        [string]$Status,
        [double]$DurationSeconds
    )

    if (-not $script:StepHistoryPath) {
        return
    }

    "{0},{1},{2},{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), ($Label -replace ',', ' '), $Status, $DurationSeconds | Add-Content -Path $script:StepHistoryPath
}

function Wait-ForIdle {
    param([string]$RunHistoryPath)

    while ($true) {
        $running = Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue
        if (-not $running) {
            return
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host ("Waiting for existing g-cli/LabVIEW processes to exit ({0} running)..." -f $running.Count)
        if ($RunHistoryPath) {
            "{0},{1},{2},{3}" -f $timestamp, 'wait', 'processes_running', $running.Count | Add-Content -Path $RunHistoryPath
        }
        Start-Sleep -Seconds 30
    }
}

function Resolve-RepoRoot {
    param([string]$PathOverride)
    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }
    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Get-RepoHeadSha {
    param([string]$RepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_SHA)) {
        $candidate = $env:GITHUB_SHA.Trim()
        if ($candidate -match '^[0-9a-fA-F]{7,40}$') {
            return $candidate.ToLowerInvariant()
        }
    }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        return $null
    }
    try {
        $sha = git -C $RepoRoot rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($sha)) {
            $candidate = $sha.Trim()
            if ($candidate -match '^[0-9a-fA-F]{7,40}$') {
                return $candidate.ToLowerInvariant()
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Get-LabVIEWInstallRoot {
    param([string]$Version, [string]$Bitness)

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

function Resolve-LabVIEWBitnessList {
    param(
        [string]$BitnessMode,
        [string]$Version
    )

    $mode = if ([string]::IsNullOrWhiteSpace($BitnessMode)) { 'both' } else { $BitnessMode.ToLowerInvariant() }

    if ($mode -eq '32' -or $mode -eq '64') {
        return @($mode)
    }

    if ($mode -eq 'installed') {
        $detected = @()
        foreach ($bitness in @('64', '32')) {
            if (Get-LabVIEWInstallRoot -Version $Version -Bitness $bitness) {
                $detected += $bitness
            }
        }

        if (-not $detected -or $detected.Count -eq 0) {
            throw "LabVIEW $Version install not found for 32-bit or 64-bit."
        }

        if ($detected.Count -eq 1) {
            Write-Warning ("Only LabVIEW {0} ({1}-bit) detected; running installed bitness only." -f $Version, $detected[0])
        }

        return $detected
    }

    $missing = @()
    foreach ($bitness in @('64', '32')) {
        if (-not (Get-LabVIEWInstallRoot -Version $Version -Bitness $bitness)) {
            $missing += $bitness
        }
    }
    if ($missing.Count -gt 0) {
        $missingLabel = ($missing | ForEach-Object { "$_-bit" }) -join ', '
        throw "LabVIEW $Version ($missingLabel) install not found. Install the missing bitness or rerun with -LabVIEWBitness installed for local runs."
    }

    return @('64', '32')
}

function Resolve-ViValidateVersion {
    param(
        [object]$LabVIEWInfo,
        [string]$RepoRoot
    )

    $versionHelper = Join-Path $RepoRoot 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $versionHelper) {
        . $versionHelper
        $info = Get-LabVIEWVersionInfo -RepoRoot $RepoRoot
        if ($info -and -not [string]::IsNullOrWhiteSpace($info.NumericVersion)) {
            return $info.NumericVersion
        }
    }

    $versionPath = Join-Path $RepoRoot '.lvversion'
    if (-not (Test-Path -Path $versionPath)) {
        if ($LabVIEWInfo -and -not [string]::IsNullOrWhiteSpace($LabVIEWInfo.NumericVersion)) {
            return $LabVIEWInfo.NumericVersion
        }
        throw ".lvversion not found at $versionPath"
    }
    $raw = (Get-Content -Raw -Path $versionPath).Trim()
    if (-not ($raw -match '^(?<major>\\d{2,4})(?:\\.(?<minor>\\d+))?$')) {
        throw "LabVIEW version '$raw' is invalid. Expected formats like '21.0' or '2021'."
    }
    $majorRaw = [int]$Matches['major']
    $minor = if ($Matches['minor']) { [int]$Matches['minor'] } else { 0 }
    $numericMajor = if ($majorRaw -ge 2000) { $majorRaw - 2000 } else { $majorRaw }

    return "$numericMajor.$minor"
}

function Get-ViValidatePlan {
    param(
        [string]$ProfileName,
        [string]$CustomConfigPath,
        [bool]$CustomConfigSpecified,
        [bool]$SkipVersionGate,
        [bool]$SkipVersionSpecified
    )

    $strictConfig = 'Tooling/pylavi/vi-validate.yml'
    $legacyConfig = 'Tooling/pylavi/vi-validate-legacy.yml'
    $plan = @()

    switch ($ProfileName) {
        'strict' {
            $plan += [pscustomobject]@{
                Label           = 'strict'
                ConfigPath      = if ($CustomConfigSpecified) { $CustomConfigPath } else { $strictConfig }
                SkipVersionGate = $SkipVersionGate
            }
        }
        'legacy' {
            $legacySkip = if ($SkipVersionSpecified) { $SkipVersionGate } else { $true }
            $plan += [pscustomobject]@{
                Label           = 'legacy'
                ConfigPath      = if ($CustomConfigSpecified) { $CustomConfigPath } else { $legacyConfig }
                SkipVersionGate = $legacySkip
            }
        }
        'both' {
            if ($CustomConfigSpecified) {
                Write-Warning "ViValidateConfigPath is ignored when ViValidateProfile=both."
            }
            $legacySkip = if ($SkipVersionSpecified) { $SkipVersionGate } else { $true }
            $plan += [pscustomobject]@{
                Label           = 'strict'
                ConfigPath      = $strictConfig
                SkipVersionGate = $SkipVersionGate
            }
            $plan += [pscustomobject]@{
                Label           = 'legacy'
                ConfigPath      = $legacyConfig
                SkipVersionGate = $legacySkip
            }
        }
    }

    return $plan
}

function New-ViValidateOffendersReport {
    param(
        [string[]]$OutputLines,
        [string]$Label,
        [string]$SourceSha
    )

    $lines = if ($null -ne $OutputLines) { @($OutputLines) } else { @() }
    $failDetails = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -like 'FAIL:*') {
            $pathValue = $null
            if ($i + 1 -lt $lines.Count) {
                $next = $lines[$i + 1]
                if ($next -match '^[\s]*(/|[A-Za-z]:|\\\\)') {
                    $pathValue = $next.Trim()
                }
            }
            $failDetails += [pscustomobject]@{
                Reason = $line
                File   = $pathValue
            }
        }
    }

    $rootsRaw = $env:LVIE_PYLAVI_ABSOLUTE_PATH_ROOTS
    $roots = if (-not [string]::IsNullOrWhiteSpace($rootsRaw)) {
        $rootsRaw -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
        @()
    }
    if ($roots.Count -gt 1) {
        $roots = $roots | Sort-Object -Unique
    }
    $redactPattern = $null
    if ($roots.Count -gt 0) {
        $redactPattern = ($roots | ForEach-Object { [regex]::Escape($_) }) -join '|'
    }
    function ConvertTo-RedactedValue {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
        if ([string]::IsNullOrWhiteSpace($redactPattern)) { return $Value }
        return [regex]::Replace($Value, $redactPattern, '<redacted>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $offenderCounts = @{}
    $offenderReasons = @{}
    $absoluteOffenderCounts = @{}
    foreach ($detail in $failDetails) {
        $key = if (-not [string]::IsNullOrWhiteSpace($detail.File)) { $detail.File } else { $detail.Reason }
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        if (-not $offenderCounts.ContainsKey($key)) {
            $offenderCounts[$key] = 0
            $offenderReasons[$key] = $detail.Reason
        }
        $offenderCounts[$key]++

        $isAbsolute = $false
        if (-not [string]::IsNullOrWhiteSpace($redactPattern) -and -not [string]::IsNullOrWhiteSpace($detail.File)) {
            $isAbsolute = $detail.File -match $redactPattern
        }
        if (-not $isAbsolute -and $detail.Reason -like 'FAIL: Absolute linker path found:*') {
            $isAbsolute = $true
        }
        if ($isAbsolute) {
            if (-not $absoluteOffenderCounts.ContainsKey($key)) {
                $absoluteOffenderCounts[$key] = 0
            }
            $absoluteOffenderCounts[$key]++
        }
    }

    $topOffenders = $offenderCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object {
        [pscustomobject]@{
            item          = (ConvertTo-RedactedValue -Value $_.Key)
            count         = $_.Value
            sample_reason = (ConvertTo-RedactedValue -Value $offenderReasons[$_.Key])
        }
    }
    $topAbsolute = $absoluteOffenderCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object {
        [pscustomobject]@{
            item  = (ConvertTo-RedactedValue -Value $_.Key)
            count = $_.Value
        }
    }

    $report = [ordered]@{
        label                  = $Label
        generated_utc          = (Get-Date).ToUniversalTime().ToString('o')
        total_fails            = $failDetails.Count
        configured_roots       = if ($roots.Count -gt 0) { '<redacted>' } else { '' }
        configured_root_count  = $roots.Count
        top_offenders          = $topOffenders
        top_absolute_offenders = $topAbsolute
    }
    if (-not [string]::IsNullOrWhiteSpace($SourceSha)) {
        $candidate = $SourceSha.Trim()
        if ($candidate -match '^[0-9a-fA-F]{7,40}$') {
            $report.source_sha = $candidate.ToLowerInvariant()
        }
    }
    return [pscustomobject]$report
}

function Write-ViValidateOffendersReport {
    param(
        [pscustomobject]$Report,
        [string]$RepoRoot
    )

    if (-not $Report -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return
    }

    try {
        $logRoot = Join-Path $RepoRoot 'TestResults\agent-logs'
        New-Item -Path $logRoot -ItemType Directory -Force | Out-Null

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $label = $Report.label
        $labelSuffix = if ([string]::IsNullOrWhiteSpace($label)) { '' } else { ".$label" }

        $latestPath = Join-Path $logRoot 'pylavi-offenders.latest.json'
        $latestLabelPath = Join-Path $logRoot ("pylavi-offenders.latest{0}.json" -f $labelSuffix)
        $datedPath = Join-Path $logRoot ("pylavi-offenders{0}.{1}.json" -f $labelSuffix, $timestamp)

        $reportJson = $Report | ConvertTo-Json -Depth 6
        $reportJson | Out-File -FilePath $datedPath -Encoding utf8
        $reportJson | Out-File -FilePath $latestPath -Encoding utf8
        if (-not [string]::IsNullOrWhiteSpace($labelSuffix)) {
            $reportJson | Out-File -FilePath $latestLabelPath -Encoding utf8
        }

        $shaValue = $null
        if ($Report.PSObject.Properties.Name -contains 'source_sha') {
            $shaValue = $Report.source_sha
        }
        if (-not [string]::IsNullOrWhiteSpace($shaValue)) {
            $candidate = $shaValue.ToString().Trim()
            if ($candidate -match '^[0-9a-fA-F]{7,40}$') {
                $shaValue = $candidate.ToLowerInvariant()
            } else {
                $shaValue = $null
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($shaValue)) {
            $shaPath = Join-Path $logRoot ("pylavi-offenders.{0}.json" -f $shaValue)
            $reportJson | Out-File -FilePath $shaPath -Encoding utf8
            if (-not [string]::IsNullOrWhiteSpace($label)) {
                $shaLabelPath = Join-Path $logRoot ("pylavi-offenders.{0}.{1}.json" -f $label, $shaValue)
                $reportJson | Out-File -FilePath $shaLabelPath -Encoding utf8
            }
        }
    } catch {
        Write-Warning ("Failed to write pylavi offenders report: {0}" -f $_.Exception.Message)
    }
}

function Invoke-ViValidate {
    param(
        [string]$RepoRoot,
        [object]$LabVIEWInfo,
        [string]$ConfigPath,
        [string]$Label,
        [switch]$ReportOnly,
        [switch]$SkipVersionGate
    )

    $viValidate = Get-Command vi_validate -ErrorAction SilentlyContinue
    if (-not $viValidate) {
        throw "vi_validate not found in PATH. Install pylavi (e.g., py -m pip install --user pylavi)."
    }

    $viArgs = @()
    $viConfig = $ConfigPath
    if (-not [string]::IsNullOrWhiteSpace($viConfig)) {
        if (-not [System.IO.Path]::IsPathRooted($viConfig)) {
            $viConfig = Join-Path $RepoRoot $viConfig
        }
        if (-not (Test-Path -Path $viConfig)) {
            throw "vi_validate config not found: $viConfig"
        }
        $viArgs += '--config'
        $viArgs += $viConfig
    } else {
        $viArgs += '--path'
        $viArgs += $RepoRoot
    }

    if (-not $SkipVersionGate) {
        $viVersion = Resolve-ViValidateVersion -LabVIEWInfo $LabVIEWInfo -RepoRoot $RepoRoot
        $viArgs += '--eq'
        $viArgs += $viVersion
    }

    $rootsRaw = $env:LVIE_PYLAVI_ABSOLUTE_PATH_ROOTS
    $roots = if (-not [string]::IsNullOrWhiteSpace($rootsRaw)) {
        $rootsRaw -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } else {
        @()
    }
    if ($roots.Count -gt 1) {
        $roots = $roots | Sort-Object -Unique
    }
    $redactRegex = $null
    if ($roots.Count -gt 0) {
        $pattern = ($roots | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $redactRegex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    function ConvertTo-RedactedValue {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
        if (-not $redactRegex) { return $Value }
        return $redactRegex.Replace($Value, '<redacted>')
    }
    function Format-CommandArgument {
        param([string[]]$Arguments)
        if (-not $Arguments) { return '' }
        return ($Arguments | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { '""' }
            elseif ($_ -match '\s') { '"' + $_ + '"' }
            else { $_ }
        }) -join ' '
    }

    $labelSuffix = if ([string]::IsNullOrWhiteSpace($Label)) { '' } else { " ($Label)" }
    $displayArgs = Format-CommandArgument -Arguments $viArgs
    Write-Host ("vi_validate command{0}: {1} {2}" -f $labelSuffix, $viValidate.Source, $displayArgs)
    $result = Invoke-CheckedWithOutput -Label "Validate LabVIEW files (pylavi$labelSuffix)" -Action {
        & $viValidate.Source @viArgs
    } -RedactionRegex $redactRegex

    $outputLines = if ($null -ne $result.Output) { @($result.Output) } else { @() }
    if ($roots.Count -gt 0 -and $outputLines.Count -gt 0) {
        $hits = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($root in $roots) {
            foreach ($line in $outputLines) {
                if ($line -like "*$root*") {
                    [void]$hits.Add($line)
                }
            }
        }
        if ($hits.Count -gt 0) {
            Write-Warning ("Absolute linker paths referencing configured roots detected (count: {0})." -f $hits.Count)
            $preview = $hits | Select-Object -First 20
            foreach ($hit in $preview) {
                Write-Warning (ConvertTo-RedactedValue -Value $hit)
            }
            if ($hits.Count -gt $preview.Count) {
                Write-Warning ("... {0} more" -f ($hits.Count - $preview.Count))
            }
        }
    }

    $sourceSha = Get-RepoHeadSha -RepoRoot $RepoRoot
    $offenderReport = New-ViValidateOffendersReport -OutputLines $outputLines -Label $Label -SourceSha $sourceSha
    Write-ViValidateOffendersReport -Report $offenderReport -RepoRoot $RepoRoot

    if ($result.Error) {
        throw $result.Error
    }
    if ($result.ExitCode -ne 0 -and $null -ne $result.ExitCode) {
        if ($ReportOnly) {
            Write-Warning ("vi_validate{0} exited with {1} (report-only)." -f $labelSuffix, $result.ExitCode)
        } else {
            throw "Validate LabVIEW files (pylavi$labelSuffix) failed with exit code $($result.ExitCode)."
        }
    }
}

function Assert-LabVIEWInstalled {
    param(
        [string]$Version,
        [string]$Bitness,
        [string]$BitnessMode
    )

    if (-not (Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness)) {
        $hint = if ($BitnessMode -eq 'both') { ' Install the missing bitness or rerun with -LabVIEWBitness installed for local runs.' } else { '' }
        throw ("LabVIEW {0} ({1}-bit) install not found.{2}" -f $Version, $Bitness, $hint)
    }
}

function Test-LabVIEWRunning {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $installRoot = Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness
    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        return $false
    }

    $processes = @()
    try {
        $processes = Get-CimInstance Win32_Process -Filter "Name='LabVIEW.exe'" -ErrorAction Stop
    } catch {
        $processes = @()
    }

    if (-not $processes) {
        return $false
    }

    $matchingProcesses = $processes | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)
    }

    return ($matchingProcesses -and $matchingProcesses.Count -gt 0)
}

function Invoke-CloseLabVIEW {
    param(
        [string]$Bitness,
        [string]$Context
    )

    $label = "Close LabVIEW $LabVIEWVersion ($Bitness-bit)"
    if ($CloseLabVIEWMode -eq 'if-running') {
        if (-not (Test-LabVIEWRunning -Version $LabVIEWVersion -Bitness $Bitness)) {
            Write-Host ("Skipping {0}{1} (not running)." -f $label, $(if ($Context) { " - $Context" } else { "" }))
            Write-StepHistoryEntry -Label $label -Status 'skipped' -DurationSeconds 0
            return
        }
    }

    Invoke-Checked -Label $label -Action {
        & (Join-Path $repoRoot '.github/actions/close-labview/Close_LabVIEW.ps1') `
            -LabVIEWVersion $LabVIEWVersion `
            -SupportedBitness $Bitness
    }
}

function Invoke-Checked {
    param(
        [string]$Label,
        [scriptblock]$Action
    )
    $stepStart = Get-Date
    $exitCode = $null
    $stepError = $null

    Write-Host ""
    Write-Host ("=== {0} ===" -f $Label)
    try {
        $global:LASTEXITCODE = $null
        & $Action
        $exitCode = $LASTEXITCODE
    }
    catch {
        $stepError = $_
    }

    $duration = [Math]::Round(((Get-Date) - $stepStart).TotalSeconds, 2)
    $status = if ($stepError) { 'error' } elseif ($null -eq $exitCode -or $exitCode -eq 0) { 'success' } else { "exit:$exitCode" }
    if ($script:StepHistoryPath) {
        "{0},{1},{2},{3}" -f $stepStart.ToString('yyyy-MM-dd HH:mm:ss'), ($Label -replace ',', ' '), $status, $duration | Add-Content -Path $script:StepHistoryPath
    }
    Write-Host ("=== {0} completed in {1}s ===" -f $Label, $duration)

    if ($stepError) {
        throw $stepError
    }
    if ($exitCode -ne 0 -and $null -ne $exitCode) {
        throw "$Label failed with exit code $exitCode."
    }
}

function Invoke-CheckedWithResult {
    param(
        [string]$Label,
        [scriptblock]$Action
    )

    $stepStart = Get-Date
    $exitCode = $null
    $stepError = $null

    Write-Host ""
    Write-Host ("=== {0} ===" -f $Label)
    try {
        $global:LASTEXITCODE = $null
        & $Action
        $exitCode = $LASTEXITCODE
    }
    catch {
        $stepError = $_
    }

    $duration = [Math]::Round(((Get-Date) - $stepStart).TotalSeconds, 2)
    $status = if ($stepError) { 'error' } elseif ($null -eq $exitCode -or $exitCode -eq 0) { 'success' } else { "exit:$exitCode" }
    if ($script:StepHistoryPath) {
        "{0},{1},{2},{3}" -f $stepStart.ToString('yyyy-MM-dd HH:mm:ss'), ($Label -replace ',', ' '), $status, $duration | Add-Content -Path $script:StepHistoryPath
    }
    Write-Host ("=== {0} completed in {1}s ===" -f $Label, $duration)

    return [pscustomobject]@{
        ExitCode  = $exitCode
        Error     = $stepError
        Status    = $status
        Duration  = $duration
    }
}

function Invoke-CheckedWithOutput {
    param(
        [string]$Label,
        [scriptblock]$Action,
        [System.Text.RegularExpressions.Regex]$RedactionRegex
    )

    $stepStart = Get-Date
    $exitCode = $null
    $stepError = $null
    $output = @()

    Write-Host ""
    Write-Host ("=== {0} ===" -f $Label)
    try {
        $global:LASTEXITCODE = $null
        $output = & $Action 2>&1
        $exitCode = $LASTEXITCODE
    }
    catch {
        $stepError = $_
    }

    $duration = [Math]::Round(((Get-Date) - $stepStart).TotalSeconds, 2)
    $status = if ($stepError) { 'error' } elseif ($null -eq $exitCode -or $exitCode -eq 0) { 'success' } else { "exit:$exitCode" }
    if ($script:StepHistoryPath) {
        "{0},{1},{2},{3}" -f $stepStart.ToString('yyyy-MM-dd HH:mm:ss'), ($Label -replace ',', ' '), $status, $duration | Add-Content -Path $script:StepHistoryPath
    }

    $normalizedOutput = @()
    if ($null -ne $output) {
        $normalizedOutput = @($output | ForEach-Object { $_.ToString() })
    }
    foreach ($line in $normalizedOutput) {
        $renderLine = $line
        if ($RedactionRegex) {
            $renderLine = $RedactionRegex.Replace($renderLine, '<redacted>')
        }
        Write-Host $renderLine
    }

    Write-Host ("=== {0} completed in {1}s ===" -f $Label, $duration)

    return [pscustomobject]@{
        ExitCode  = $exitCode
        Error     = $stepError
        Output    = $normalizedOutput
        Status    = $status
        Duration  = $duration
    }
}

function Test-ConnectTimeoutError {
    param([object]$ErrorRecord)

    if (-not $ErrorRecord) { return $false }
    $message = $ErrorRecord.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { return $false }
    return $message -match 'GCLI_CONNECT_TIMEOUT' -or $message -match 'Timed out waiting for app to connect to g-cli'
}

function Invoke-VerifyIEPath {
    param(
        [string]$Bitness,
        [int]$ConnectTimeoutMs,
        [int]$StatusTimeoutMs,
        [int]$ProcessTimeoutMs,
        [string]$VerifyArchive
    )

    $connectTimeoutMsValue = $ConnectTimeoutMs
    $statusTimeoutMsValue = $StatusTimeoutMs
    $processTimeoutMsValue = $ProcessTimeoutMs
    $verifyArchiveValue = $VerifyArchive

    return Invoke-CheckedWithResult -Label "Verify IE Paths gate ($Bitness-bit)" -Action {
        $verifyParams = @{
            LabVIEWVersion             = $LabVIEWVersion
            SupportedBitness           = $Bitness
            RepoRoot                   = $repoRoot
            ConnectTimeoutMs           = $connectTimeoutMsValue
            ProcessTimeoutMs           = $processTimeoutMsValue
            StatusFileTimeoutMs        = $statusTimeoutMsValue
            StatusFileArchiveDirectory = $verifyArchiveValue
            AutoRevertIfEnabled        = $true
            IgnoreGcliExitCode         = $true
        }
        if ($script:PreferNoLabVIEWDevMode) {
            $verifyParams.EnableDevModeNoLabVIEW = $true
        } else {
            $verifyParams.EnableDevMode = $true
            $verifyParams.AllowFallbackToNoLabVIEW = $true
        }

        & (Join-Path $repoRoot 'Tooling/Invoke-MissingIEFilesFromLVInstall.ps1') @verifyParams
    }
}

function Invoke-EnableDevModeWithRecovery {
    param(
        [string]$Bitness,
        [int]$ConnectTimeoutMs,
        [int]$ProcessTimeoutMs,
        [string]$Context
    )

    $connectTimeoutMsValue = $ConnectTimeoutMs
    $processTimeoutMsValue = $ProcessTimeoutMs

    Wait-ForIdle -RunHistoryPath $script:RunHistoryPath

    $label = if ([string]::IsNullOrWhiteSpace($Context)) {
        "Enable dev mode ($Bitness-bit)"
    } else {
        "Enable dev mode ($Context, $Bitness-bit)"
    }
    $result = Invoke-CheckedWithResult -Label $label -Action {
        $setParams = @{
            LabVIEWVersion   = $LabVIEWVersion
            SupportedBitness = $Bitness
            RepoRoot         = $repoRoot
            ConnectTimeoutMs = $connectTimeoutMsValue
            ProcessTimeoutMs = $processTimeoutMsValue
        }
        if (-not $script:PreferNoLabVIEWDevMode) {
            $setParams.UseLabVIEW = $true
            $setParams.AllowFallbackToNoLabVIEW = $true
        }
        & (Join-Path $repoRoot '.github/actions/set-development-mode/Set_Development_Mode.ps1') @setParams
    }

    if (-not $result.Error) {
        return
    }

    Write-Warning ("{0} failed; attempting revert and retry in case dev mode points at a different worktree." -f $label)
    $contextLabel = if ([string]::IsNullOrWhiteSpace($Context)) { "$Bitness-bit" } else { "$Context, $Bitness-bit" }
    Write-Host ("--- Dev mode recovery: revert + retry ({0}) ---" -f $contextLabel)
    Write-Warning ("Enable dev mode error: {0}" -f $result.Error.Exception.Message)
    $revertResult = Invoke-CheckedWithResult -Label "Revert dev mode before retry ($Bitness-bit)" -Action {
        $revertParams = @{
            LabVIEWVersion   = $LabVIEWVersion
            SupportedBitness = $Bitness
            RepoRoot         = $repoRoot
            ConnectTimeoutMs = $connectTimeoutMsValue
            ProcessTimeoutMs = $processTimeoutMsValue
        }
        if (-not $script:PreferNoLabVIEWDevMode) {
            $revertParams.UseLabVIEW = $true
            $revertParams.AllowFallbackToNoLabVIEW = $true
        }
        & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') @revertParams
    }
    if ($revertResult.Error) {
        Write-Warning ("Dev mode recovery failed during revert: {0}" -f $revertResult.Error.Exception.Message)
        Write-Host ("--- Dev mode recovery failed ({0}) ---" -f $contextLabel)
        throw $revertResult.Error
    }

    $retry = Invoke-CheckedWithResult -Label "Enable dev mode retry ($Bitness-bit)" -Action {
        $setParams = @{
            LabVIEWVersion   = $LabVIEWVersion
            SupportedBitness = $Bitness
            RepoRoot         = $repoRoot
            ConnectTimeoutMs = $connectTimeoutMsValue
            ProcessTimeoutMs = $processTimeoutMsValue
        }
        if (-not $script:PreferNoLabVIEWDevMode) {
            $setParams.UseLabVIEW = $true
            $setParams.AllowFallbackToNoLabVIEW = $true
        }
        & (Join-Path $repoRoot '.github/actions/set-development-mode/Set_Development_Mode.ps1') @setParams
    }
    if ($retry.Error) {
        Write-Warning ("Dev mode recovery failed on retry: {0}" -f $retry.Error.Exception.Message)
        Write-Host ("--- Dev mode recovery failed ({0}) ---" -f $contextLabel)
        throw $retry.Error
    }

    Write-Host ("Dev mode recovery succeeded after revert + retry ({0})." -f $contextLabel)
    Write-Host ("--- Dev mode recovery completed ({0}) ---" -f $contextLabel)
}

function Get-LocalVersionInfo {
    param([string]$BumpType)

    $versionPattern = '^(v)?\d+(\.\d+){0,2}$'
    $latestRaw = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0) {
        $latestRaw = ''
        $global:LASTEXITCODE = 0
    }
    if (-not [string]::IsNullOrWhiteSpace($latestRaw)) {
        $candidate = $latestRaw.Trim()
        if (-not ($candidate -match $versionPattern)) {
            $latestRaw = ''
        }
    }
    if ([string]::IsNullOrWhiteSpace($latestRaw)) {
        $tags = git tag --list 2>$null
        if ($LASTEXITCODE -ne 0) {
            $global:LASTEXITCODE = 0
        }
        if ($tags) {
            $semverTags = $tags | Where-Object { $_ -match $versionPattern }
            if ($semverTags) {
                $latestRaw = $semverTags | Sort-Object { [version]($_.TrimStart('v')) } -Descending | Select-Object -First 1
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($latestRaw)) {
        $maj = 0
        $min = 1
        $pat = 0
    } else {
        $latest = $latestRaw.Trim().TrimStart('v') -replace '-build.*'
        $parts = $latest.Split('.')
        $maj = [int]$parts[0]
        $min = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }
        $pat = if ($parts.Length -gt 2) { [int]$parts[2] } else { 0 }
    }

    switch ($BumpType) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++; $pat = 0 }
        'patch' { $pat++ }
        default { }
    }

    $build = [int](git rev-list --count HEAD)
    $commit = (git rev-parse HEAD).Trim()

    return [pscustomobject]@{
        Major  = $maj
        Minor  = $min
        Patch  = $pat
        Build  = $build
        Commit = $commit
    }
}

function Get-RepoInfo {
    param([string]$RepoRoot)

    $repoName = Split-Path -Path $RepoRoot -Leaf
    $remote = git config --get remote.origin.url
    $owner = ''
    $fullName = $repoName
    $url = ''

    if (-not [string]::IsNullOrWhiteSpace($remote) -and $remote -match 'github\.com[/:](?<owner>[^/]+)/(?<repo>[^/.]+)') {
        $owner = $Matches.owner
        $fullName = "$owner/$($Matches.repo)"
        $url = "https://github.com/$fullName"
    }

    return [pscustomobject]@{
        RepoName = $repoName
        Owner    = if ($owner) { $owner } else { $repoName }
        FullName = $fullName
        Url      = $url
    }
}

function Get-DisplayInformationJson {
    param(
        [string]$RepoRoot,
        [string]$ReleaseNotesPath,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build
    )

    $meta = Get-RepoInfo -RepoRoot $RepoRoot
    $releaseNotes = if (Test-Path $ReleaseNotesPath) { Get-Content -Raw -Path $ReleaseNotesPath } else { 'Release notes file not generated.' }
    $productName = $meta.RepoName
    $description = "$($meta.RepoName) VI Package build for $($meta.FullName)."

    $info = @{
        "Package Version" = @{
            "major" = $Major
            "minor" = $Minor
            "patch" = $Patch
            "build" = $Build
        }
        "Product Name" = $productName
        "Company Name" = $meta.Owner
        "Author Name (Person or Company)" = $meta.FullName
        "Product Homepage (URL)" = if ([string]::IsNullOrWhiteSpace($meta.Url)) { "" } else { $meta.Url }
        "Legal Copyright" = "(c) $(Get-Date -Format yyyy) $($meta.Owner)"
        "Product Description Summary" = $description
        "Product Description" = $description
        "Release Notes - Change Log" = $releaseNotes
    }

    return ($info | ConvertTo-Json -Depth 5 -Compress)
}

function Copy-LatestVipToBuild {
    param(
        [string]$RepoRoot,
        [datetime]$Since,
        [string]$ArtifactRoot
    )

    $artifactRootResolved = if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) { $env:LVIE_ARTIFACT_ROOT } else { $ArtifactRoot }
    $buildsDir = if ([string]::IsNullOrWhiteSpace($artifactRootResolved)) {
        Join-Path $RepoRoot 'builds'
    } else {
        Join-Path $artifactRootResolved 'builds'
    }
    $vipDir = Join-Path $buildsDir 'VI Package'
    New-Item -Path $vipDir -ItemType Directory -Force | Out-Null

    $vipCandidates = Get-ChildItem -Path $RepoRoot -Recurse -Filter *.vip -ErrorAction SilentlyContinue
    if ($Since) {
        $vipCandidates = $vipCandidates | Where-Object { $_.LastWriteTime -ge $Since }
    }

    $latestVip = $vipCandidates | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

    if (-not $latestVip) {
        Write-Warning "No .vip file found under $RepoRoot."
        return $null
    }

    if ($latestVip.DirectoryName -like "$vipDir*") {
        Write-Host ("Latest .vip already in builds\\VI Package: {0}" -f $latestVip.FullName)
        return $latestVip.FullName
    }

    $targetPath = Join-Path $vipDir $latestVip.Name
    Copy-Item -Path $latestVip.FullName -Destination $targetPath -Force
    Write-Host ("Copied .vip to builds\\VI Package: {0}" -f $targetPath)
    return $targetPath
}

function Write-GCliBuildLogTail {
    param(
        [string]$RepoRoot,
        [int]$TailLines = 120,
        [string]$ArtifactRoot
    )

    $artifactRootResolved = if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) { $env:LVIE_ARTIFACT_ROOT } else { $ArtifactRoot }
    $logFile = if ([string]::IsNullOrWhiteSpace($artifactRootResolved)) {
        Join-Path $RepoRoot 'builds/logs/gcli-build.log'
    } else {
        Join-Path $artifactRootResolved 'builds/logs/gcli-build.log'
    }
    if (-not (Test-Path -Path $logFile)) {
        Write-Host ("g-cli build log not found at {0}" -f $logFile)
        return
    }

    Write-Host ("---- g-cli build log (last {0} lines) ----" -f $TailLines)
    Get-Content -Path $logFile -Tail $TailLines | ForEach-Object { Write-Host $_ }
    Write-Host "---- end g-cli build log ----"
}

function Get-RunnerCliRuntime {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($IsWindows) { return 'win-x64' }
    if ($IsLinux) {
        if ($arch -eq 'Arm64') { return 'linux-arm64' }
        return 'linux-x64'
    }
    if ($IsMacOS) {
        if ($arch -eq 'Arm64') { return 'osx-arm64' }
        return 'osx-x64'
    }
    return 'win-x64'
}

function Get-RunnerCliFileName {
    param([string]$Runtime)
    if ($Runtime -like 'win-*') { return 'runner-cli.exe' }
    return 'runner-cli'
}

function Resolve-RunnerCliPath {
    param(
        [string]$ExplicitPath,
        [string]$RepoRoot
    )

    $runtime = Get-RunnerCliRuntime
    $cliFile = Get-RunnerCliFileName -Runtime $runtime

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates += $ExplicitPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CLI_PATH)) {
        $candidates += $env:LVIE_RUNNER_CLI_PATH
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $candidates += (Join-Path $RepoRoot 'Tooling\runner-cli\publish' $runtime $cliFile)
        $candidates += (Join-Path $RepoRoot 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0' $runtime 'publish' $cliFile)
        $candidates += (Join-Path $RepoRoot 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0' $runtime $cliFile)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $candidates += (Join-Path $env:RUNNER_TEMP 'runner-cli' $cliFile)
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path -Path $candidate) {
            return (Resolve-Path -Path $candidate -ErrorAction Stop).Path
        }
    }

    return $null
}

function Initialize-RunnerContractIfNeeded {
    param(
        [string]$RepoRoot,
        [string]$RunnerCliPath,
        [switch]$RequireRunnerCli
    )

    $contractHelper = Join-Path $RepoRoot 'Tooling\support\RunnerContract.ps1'
    if (-not (Test-Path -Path $contractHelper)) {
        return
    }

    . $contractHelper

    $contractPath = Resolve-RunnerContractPath -ContractPath $env:LVIE_RUNNER_CONTRACT_PATH -RunnerRoot $env:LVIE_RUNNER_ROOT -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
    if (-not [string]::IsNullOrWhiteSpace($contractPath) -and (Test-Path -Path $contractPath)) {
        return
    }

    $runnerRoot = $env:LVIE_RUNNER_ROOT
    $workRoot = Resolve-RunnerWorkRoot -RunnerRoot $runnerRoot -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
    if ([string]::IsNullOrWhiteSpace($workRoot)) {
        Write-Host 'Runner work root not resolved; skipping runner contract initialization.'
        return
    }
    if ([string]::IsNullOrWhiteSpace($runnerRoot)) {
        if ((Split-Path -Leaf $workRoot) -ieq '_work') {
            $runnerRoot = Split-Path -Parent $workRoot
        }
    }
    if ([string]::IsNullOrWhiteSpace($runnerRoot)) {
        Write-Host 'Runner root not resolved; skipping runner contract initialization.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($contractPath)) {
        $contractPath = Join-Path $workRoot 'lvie\runner-contract.json'
    }

    $cliPath = $null
    $ensureScript = Join-Path $RepoRoot 'Tooling\Ensure-RunnerCli.ps1'
    if (Test-Path -Path $ensureScript) {
        $ensureResult = & $ensureScript -RepoRoot $RepoRoot -RunnerCliPath $RunnerCliPath -Require:$RequireRunnerCli
        if ($ensureResult -and $ensureResult.Path) {
            $cliPath = $ensureResult.Path
        }
    }
    if (-not $cliPath) {
        $cliPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRoot $RepoRoot
    }

    if (-not $cliPath -or -not (Test-Path -Path $cliPath)) {
        if ($RequireRunnerCli.IsPresent) {
            throw 'runner-cli not available to initialize runner contract.'
        }
        Write-Host 'runner-cli not found; skipping runner contract initialization.'
        return
    }

    $runnerLabel = if ([string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) { 'self-hosted-windows-lv' } else { $env:LVIE_RUNNER_LABEL }
    $canonicalLabel = if ([string]::IsNullOrWhiteSpace($env:LVIE_CANONICAL_RUNNER_LABEL)) { 'self-hosted-windows-lv' } else { $env:LVIE_CANONICAL_RUNNER_LABEL }

    Write-Host ("Initializing runner contract with runner-cli: {0}" -f $cliPath)
    & $cliPath init-contract `
        --contract-path $contractPath `
        --runner-root $runnerRoot `
        --work-root $workRoot `
        --runner-label $runnerLabel `
        --canonical-label $canonicalLabel

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw ("runner-cli init-contract failed (exit {0})." -f $LASTEXITCODE)
    }

    $contract = Get-RunnerContract -ContractPath $contractPath -RunnerRoot $runnerRoot -WorkRoot $workRoot
    if ($contract) {
        Set-RunnerContractEnvironment -Contract $contract -ContractPath $contractPath
    }
}

function Invoke-RunnerContractValidation {
    param(
        [string]$RepoRoot,
        [string]$RunnerCliPath,
        [switch]$RequireRunnerCli
    )

    $contractPath = $env:LVIE_RUNNER_CONTRACT_PATH
    if ([string]::IsNullOrWhiteSpace($contractPath)) {
        Write-Host 'Runner contract not set; skipping runner-cli validation.'
        return
    }
    if (-not (Test-Path -Path $contractPath)) {
        Write-Warning ("Runner contract not found at {0}; skipping validation." -f $contractPath)
        return
    }

    $requireEnabled = $RequireRunnerCli.IsPresent -or -not $PSBoundParameters.ContainsKey('RequireRunnerCli')
    $ensureScript = Join-Path $RepoRoot 'Tooling\Ensure-RunnerCli.ps1'
    if (Test-Path -Path $ensureScript) {
        $ensureResult = & $ensureScript -RepoRoot $RepoRoot -RunnerCliPath $RunnerCliPath -Require:$requireEnabled
        if ($ensureResult -and $ensureResult.Path) {
            $RunnerCliPath = $ensureResult.Path
        }
    }

    $cliPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRoot $RepoRoot
    if ($cliPath -and (Test-Path -Path $cliPath)) {
        Write-Host ("Validating runner contract with runner-cli: {0}" -f $cliPath)
        & $cliPath validate-contract --contract-path $contractPath --fail-on-missing-safe-directory
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw ("runner-cli validation failed (exit {0})." -f $LASTEXITCODE)
        }
        return
    }

    $validateScript = Join-Path $RepoRoot 'Tooling\Validate-RunnerContract.ps1'
    if (Test-Path -Path $validateScript) {
        Write-Host 'runner-cli not found; using PowerShell fallback.'
        & $validateScript -ContractPath $contractPath -FailOnMissingSafeDirectory
    }
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$requireRunnerCliEnabled = $RequireRunnerCli.IsPresent -or -not $PSBoundParameters.ContainsKey('RequireRunnerCli')
$requireRunnerCliInit = $RequireRunnerCli.IsPresent
$artifactRootResolved = $null
$preflight = $null
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $repoRoot `
        -WorktreeRoot $WorktreeRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $LabVIEWBitness `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$AutoWorktree `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs `
        -RunId $RunId `
        -ArtifactRoot $ArtifactRoot `
        -CleanRoom:$CleanRoom `
        -RequireGcli:$(-not $ViValidateOnly) `
        -RequireViValidate:$($ViValidateOnly -or (-not $SkipViValidate)) `
        -RunnerCliPath $RunnerCliPath `
        -RequireRunnerCli:$requireRunnerCliEnabled
    if ($preflight.Reinvoked) {
        return
    }
    $repoRoot = $preflight.RepoRoot
    $artifactRootResolved = $preflight.ArtifactRoot
}

Initialize-RunnerContractIfNeeded -RepoRoot $repoRoot -RunnerCliPath $RunnerCliPath -RequireRunnerCli:$requireRunnerCliInit

Invoke-RunnerContractValidation -RepoRoot $repoRoot -RunnerCliPath $RunnerCliPath -RequireRunnerCli:$requireRunnerCliEnabled

$assertScript = Join-Path $repoRoot 'Tooling\Assert-LabVIEWVersion.ps1'
if (Test-Path -Path $assertScript) {
    & $assertScript -RepoRoot $repoRoot -ExpectedVersion $LabVIEWVersion -AllowMismatch:$AllowVersionMismatch -Context 'ci-local'
}

$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewInfo = if ($preflight -and $preflight.LabVIEWInfo) { $preflight.LabVIEWInfo } else { $null }
if (-not $labviewInfo -and (Test-Path -Path $versionHelper)) {
    . $versionHelper
    $labviewInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $LabVIEWVersion = $labviewInfo.Year
}
if ($labviewInfo -and -not [string]::IsNullOrWhiteSpace($labviewInfo.Year)) {
    $LabVIEWVersion = $labviewInfo.Year
}
if ([string]::IsNullOrWhiteSpace($LabVIEWVersion)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}
Push-Location -Path $repoRoot
$script:RunFailed = $false
$runStart = Get-Date
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot = if ($artifactRootResolved) { Join-Path $artifactRootResolved 'agent-logs' } else { Join-Path $repoRoot 'TestResults/agent-logs' }
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$script:RunHistoryPath = Join-Path $logRoot 'run-history.csv'
$script:StepHistoryPath = Join-Path $logRoot 'step-history.csv'
$script:CloseHistoryPath = Join-Path $logRoot ("close-history-{0}.csv" -f $runTimestamp)
Initialize-CsvHeader -Path $script:RunHistoryPath -Header 'timestamp,status,duration_seconds,command'
Initialize-CsvHeader -Path $script:StepHistoryPath -Header 'timestamp,step,status,duration_seconds'
$env:LABVIEW_CLOSE_METRICS_PATH = $script:CloseHistoryPath
$runLog = Join-Path $logRoot "ci-local-$runTimestamp.log"
$commandLine = "Run-CICompositeLocal.ps1 -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness -AllowVersionMismatch:$AllowVersionMismatch -DryRun:$DryRun -EnsureCleanState:$EnsureCleanState -SkipVerifyIEPaths:$SkipVerifyIEPaths -SkipVipc:$SkipVipc -SkipMissingInProject:$SkipMissingInProject -SkipUnitTests:$SkipUnitTests -SkipBuildPpl:$SkipBuildPpl -SkipBuildVip:$SkipBuildVip -SkipViValidate:$SkipViValidate -ViValidateConfigPath $ViValidateConfigPath -ViValidateProfile $ViValidateProfile -ViValidateReportOnly:$ViValidateReportOnly -ViValidateSkipVersionGate:$ViValidateSkipVersionGate -ViValidateOnly:$ViValidateOnly -UseLabVIEWDevMode:$UseLabVIEWDevMode -BumpType $BumpType -ConnectTimeoutMs $ConnectTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -StatusFileTimeoutMs $StatusFileTimeoutMs -VipmTimeoutSeconds $VipmTimeoutSeconds -CloseLabVIEWMode $CloseLabVIEWMode -WorktreeRoot $WorktreeRoot -SkipWorktreeRootCheck:$SkipWorktreeRootCheck -AutoWorktree:$AutoWorktree -RunId $RunId -ArtifactRoot $ArtifactRoot -CleanRoom:$CleanRoom -RunnerCliPath $RunnerCliPath -RequireRunnerCli:$requireRunnerCliEnabled"
$script:TranscriptStarted = $false
try {
    Start-Transcript -Path $runLog -Append | Out-Null
    $script:TranscriptStarted = $true
}
catch {
    Write-Warning "Failed to start transcript logging to $runLog. Continuing without transcript."
}

try {
    $viValidatePlan = @()
    if ($ViValidateOnly -or (-not $SkipViValidate)) {
        $viValidatePlan = Get-ViValidatePlan `
            -ProfileName $ViValidateProfile `
            -CustomConfigPath $ViValidateConfigPath `
            -CustomConfigSpecified:$customViConfigSpecified `
            -SkipVersionGate:$ViValidateSkipVersionGate `
            -SkipVersionSpecified:$skipViVersionSpecified
    }

    if ($ViValidateOnly) {
        foreach ($entry in $viValidatePlan) {
            Invoke-ViValidate `
                -RepoRoot $repoRoot `
                -LabVIEWInfo $labviewInfo `
                -ConfigPath $entry.ConfigPath `
                -Label $entry.Label `
                -ReportOnly:$ViValidateReportOnly `
                -SkipVersionGate:$entry.SkipVersionGate
        }
        Write-Host ""
        Write-Host "vi_validate completed; exiting due to -ViValidateOnly."
        return
    }

    if ($DryRun) {
        $bitnessList = Resolve-LabVIEWBitnessList -BitnessMode $LabVIEWBitness -Version $LabVIEWVersion
        foreach ($bitness in $bitnessList) {
            Assert-LabVIEWInstalled -Version $LabVIEWVersion -Bitness $bitness -BitnessMode $LabVIEWBitness
        }
        Write-Host ("Dry run complete. Version contract and LabVIEW installs validated for {0} ({1})." -f $LabVIEWVersion, ($bitnessList -join ', '))
        return
    }

    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw "g-cli.exe not found in PATH."
    }

    if (-not $SkipViValidate) {
        foreach ($entry in $viValidatePlan) {
            Invoke-ViValidate `
                -RepoRoot $repoRoot `
                -LabVIEWInfo $labviewInfo `
                -ConfigPath $entry.ConfigPath `
                -Label $entry.Label `
                -ReportOnly:$ViValidateReportOnly `
                -SkipVersionGate:$entry.SkipVersionGate
        }
    }

    Wait-ForIdle -RunHistoryPath $script:RunHistoryPath

    $bitnessList = Resolve-LabVIEWBitnessList -BitnessMode $LabVIEWBitness -Version $LabVIEWVersion
    foreach ($bitness in $bitnessList) {
        Assert-LabVIEWInstalled -Version $LabVIEWVersion -Bitness $bitness -BitnessMode $LabVIEWBitness
    }
    if (-not $SkipBuildVip -and ($bitnessList -notcontains '64')) {
        throw "VIP build requires LabVIEW $LabVIEWVersion (64-bit). Install 64-bit LabVIEW or rerun with -SkipBuildVip."
    }
    $vipLabVIEWMinorRevision = if ($labviewInfo) { [int]$labviewInfo.MinorRevision } else { 0 }

    $versionInfo = Get-LocalVersionInfo -BumpType $BumpType
    if ($PSBoundParameters.ContainsKey('Major')) { $versionInfo.Major = $Major }
    if ($PSBoundParameters.ContainsKey('Minor')) { $versionInfo.Minor = $Minor }
    if ($PSBoundParameters.ContainsKey('Patch')) { $versionInfo.Patch = $Patch }
    if ($PSBoundParameters.ContainsKey('Build')) { $versionInfo.Build = $Build }
    if ($PSBoundParameters.ContainsKey('Commit')) { $versionInfo.Commit = $Commit }

    $artifactsRoot = if ($artifactRootResolved) { Join-Path $artifactRootResolved 'ci-local' } else { Join-Path $repoRoot 'TestResults/ci-local' }
    New-Item -Path $artifactsRoot -ItemType Directory -Force | Out-Null

    if (-not $SkipVerifyIEPaths) {
        $verifyArchive = Join-Path $artifactsRoot 'verify-iepaths'
        New-Item -Path $verifyArchive -ItemType Directory -Force | Out-Null

        foreach ($bitness in $bitnessList) {
            $verifyConnectTimeoutMs = 15000

            Wait-ForIdle -RunHistoryPath $script:RunHistoryPath

            if ($EnsureCleanState) {
                $revertResult = Invoke-CheckedWithResult -Label "Revert dev mode before enabling VerifyIEPaths ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot 'Tooling/Revert-DevelopmentMode-NoLabVIEW.ps1') `
                        -LabVIEWVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot
                }

                if ($revertResult.Error) {
                    throw $revertResult.Error
                }
            }

            $verifyResult = Invoke-VerifyIEPath -Bitness $bitness -ConnectTimeoutMs $verifyConnectTimeoutMs -StatusTimeoutMs $StatusFileTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -VerifyArchive $verifyArchive
            if ($verifyResult.Error) {
                throw $verifyResult.Error
            }
        }
    }

    if (-not $SkipVipc) {
        foreach ($bitness in $bitnessList) {
            Invoke-Checked -Label "Apply VIPC (LV$LabVIEWVersion $bitness-bit)" -Action {
                & (Join-Path $repoRoot '.github/actions/apply-vipc/ApplyVIPC.ps1') `
                    -LabVIEWVersion $LabVIEWVersion `
                    -SupportedBitness $bitness `
                    -RepoRoot $repoRoot `
                    -VIPCPath $VipcPath
            }
        }

    }

    if (-not $SkipMissingInProject) {
        $missingDir = Join-Path $artifactsRoot 'missing-in-project'
        New-Item -Path $missingDir -ItemType Directory -Force | Out-Null

        $projectFile = Get-ChildItem -Path $repoRoot -Filter *.lvproj | Select-Object -First 1 -ExpandProperty FullName
        if (-not $projectFile) {
            throw "No .lvproj file found in repo root."
        }

        foreach ($bitness in $bitnessList) {
            try {
                Invoke-EnableDevModeWithRecovery -Bitness $bitness -ConnectTimeoutMs $ConnectTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -Context 'missing-in-project'

                Invoke-Checked -Label "Missing-in-project ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1') `
                        -LVVersion $LabVIEWVersion `
                        -Arch $bitness `
                        -ProjectFile $projectFile
                }
            }
            finally {
                try {
                    Invoke-CloseLabVIEW -Bitness $bitness -Context 'after missing-in-project'
                } catch {
                    Write-Warning ("Failed to close LabVIEW after missing-in-project: {0}" -f $_.Exception.Message)
                }
                Wait-ForIdle -RunHistoryPath $script:RunHistoryPath
                $revertParams = @{
                    LabVIEWVersion   = $LabVIEWVersion
                    SupportedBitness = $bitness
                    RepoRoot         = $repoRoot
                    ConnectTimeoutMs = $ConnectTimeoutMs
                    ProcessTimeoutMs = $ProcessTimeoutMs
                }
                if (-not $script:PreferNoLabVIEWDevMode) {
                    $revertParams.UseLabVIEW = $true
                    $revertParams.AllowFallbackToNoLabVIEW = $true
                }
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') @revertParams | Out-Null
            }

            $missingPath = Join-Path $repoRoot '.github/actions/missing-in-project/missing_files.txt'
            if (Test-Path $missingPath) {
                Copy-Item -Path $missingPath -Destination (Join-Path $missingDir "missing-files-$bitness.txt") -Force
            }
        }
    }

    if (-not $SkipUnitTests) {
        foreach ($bitness in $bitnessList) {
            try {
                Invoke-EnableDevModeWithRecovery -Bitness $bitness -ConnectTimeoutMs $ConnectTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -Context 'unit tests'

                Invoke-Checked -Label "Run unit tests ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/run-unit-tests/RunUnitTests.ps1') `
                        -LabVIEWVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -ProjectPath (Join-Path $repoRoot 'lv_icon_editor.lvproj')
                }
            }
            finally {
                try {
                    Invoke-CloseLabVIEW -Bitness $bitness -Context 'after unit tests'
                } catch {
                    Write-Warning ("Failed to close LabVIEW after unit tests: {0}" -f $_.Exception.Message)
                }
                Wait-ForIdle -RunHistoryPath $script:RunHistoryPath
                $revertParams = @{
                    LabVIEWVersion   = $LabVIEWVersion
                    SupportedBitness = $bitness
                    RepoRoot         = $repoRoot
                    ConnectTimeoutMs = $ConnectTimeoutMs
                    ProcessTimeoutMs = $ProcessTimeoutMs
                }
                if (-not $script:PreferNoLabVIEWDevMode) {
                    $revertParams.UseLabVIEW = $true
                    $revertParams.AllowFallbackToNoLabVIEW = $true
                }
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') @revertParams | Out-Null
            }
        }
    }

    if (-not $SkipBuildPpl) {
        foreach ($bitness in $bitnessList) {
            try {
                Invoke-EnableDevModeWithRecovery -Bitness $bitness -ConnectTimeoutMs $ConnectTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -Context 'build PPL'

                Invoke-Checked -Label "Build PPL ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/build-lvlibp/Build_lvlibp.ps1') `
                        -LabVIEWVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot `
                        -Major $versionInfo.Major `
                        -Minor $versionInfo.Minor `
                        -Patch $versionInfo.Patch `
                        -Build $versionInfo.Build `
                        -Commit $versionInfo.Commit
                }
            }
            finally {
                try {
                    Invoke-CloseLabVIEW -Bitness $bitness -Context 'after PPL build'
                } catch {
                    Write-Warning ("Failed to close LabVIEW after PPL build: {0}" -f $_.Exception.Message)
                }
                Wait-ForIdle -RunHistoryPath $script:RunHistoryPath
                $revertParams = @{
                    LabVIEWVersion   = $LabVIEWVersion
                    SupportedBitness = $bitness
                    RepoRoot         = $repoRoot
                    ConnectTimeoutMs = $ConnectTimeoutMs
                    ProcessTimeoutMs = $ProcessTimeoutMs
                }
                if (-not $script:PreferNoLabVIEWDevMode) {
                    $revertParams.UseLabVIEW = $true
                    $revertParams.AllowFallbackToNoLabVIEW = $true
                }
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') @revertParams | Out-Null
            }

            $currentFile = Join-Path $repoRoot 'resource/plugins/lv_icon.lvlibp'
            $targetFile = if ($bitness -eq '32') {
                Join-Path $repoRoot 'resource/plugins/lv_icon_x86.lvlibp'
            } else {
                Join-Path $repoRoot 'resource/plugins/lv_icon_x64.lvlibp'
            }

            if (Test-Path -Path $targetFile) {
                Remove-Item -Path $targetFile -Force
            }

            Invoke-Checked -Label "Rename PPL ($bitness-bit)" -Action {
                & (Join-Path $repoRoot '.github/actions/rename-file/Rename-file.ps1') `
                    -CurrentFilename $currentFile `
                    -NewFilename $targetFile
            }
        }
    }

    if (-not $SkipBuildVip) {
        $vipBuildStart = Get-Date

        Invoke-Checked -Label "Generate release notes" -Action {
            & (Join-Path $repoRoot '.github/actions/generate-release-notes/GenerateReleaseNotes.ps1') `
                -OutputPath $ReleaseNotesPath
        }

        $displayInfo = Get-DisplayInformationJson -RepoRoot $repoRoot -ReleaseNotesPath (Join-Path $repoRoot $ReleaseNotesPath) -Major $versionInfo.Major -Minor $versionInfo.Minor -Patch $versionInfo.Patch -Build $versionInfo.Build

        Invoke-Checked -Label "Modify VIPB display info (LV$LabVIEWVersion 64-bit)" -Action {
            & (Join-Path $repoRoot '.github/actions/modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1') `
                -SupportedBitness 64 `
                -RepoRoot $repoRoot `
                -VIPBPath $VipbPath `
                -LabVIEWVersion $LabVIEWVersion `
                -LabVIEWMinorRevision $vipLabVIEWMinorRevision `
                -Major $versionInfo.Major `
                -Minor $versionInfo.Minor `
                -Patch $versionInfo.Patch `
                -Build $versionInfo.Build `
                -Commit $versionInfo.Commit `
                -ReleaseNotesFile (Join-Path $repoRoot $ReleaseNotesPath) `
                -DisplayInformationJSON $displayInfo
        }

        try {
            Invoke-Checked -Label "Build VIP (LV$LabVIEWVersion 64-bit)" -Action {
                & (Join-Path $repoRoot 'Tooling/Invoke-VipBuild.ps1') `
                    -SupportedBitness 64 `
                    -RepoRoot $repoRoot `
                    -VIPBPath $VipbPath `
                    -LabVIEWVersion $LabVIEWVersion `
                    -LabVIEWMinorRevision $vipLabVIEWMinorRevision `
                    -Major $versionInfo.Major `
                    -Minor $versionInfo.Minor `
                    -Patch $versionInfo.Patch `
                    -Build $versionInfo.Build `
                    -Commit $versionInfo.Commit `
                    -ReleaseNotesFile (Join-Path $repoRoot $ReleaseNotesPath) `
                    -DisplayInformationJSON $displayInfo `
                    -VipmTimeoutSeconds $VipmTimeoutSeconds
            }
        }
        catch {
            Write-GCliBuildLogTail -RepoRoot $repoRoot -ArtifactRoot $artifactRootResolved
            throw
        }

        $vipOutput = Copy-LatestVipToBuild -RepoRoot $repoRoot -Since $vipBuildStart -ArtifactRoot $artifactRootResolved
        if (-not $vipOutput) {
            Write-GCliBuildLogTail -RepoRoot $repoRoot -ArtifactRoot $artifactRootResolved
            throw "VIP build did not produce a .vip after $($vipBuildStart.ToString('yyyy-MM-dd HH:mm:ss'))."
        }

        Invoke-CloseLabVIEW -Bitness 64 -Context 'after VIP build'
    }

    Write-Host ""
    Write-Host "Local CI parity run completed successfully."
}
catch {
    $script:RunFailed = $true
    throw
}
finally {
    if ($script:TranscriptStarted) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
            Write-Verbose ("Stop-Transcript failed. {0}" -f $_.Exception.Message)
        }
    }
    if ($preflight -and $preflight.CleanRoomAfter) {
        Invoke-PreflightCleanup -RepoRoot $preflight.RepoRoot -Phase 'after'
    }
    if ($env:LABVIEW_CLOSE_METRICS_PATH) {
        Remove-Item Env:LABVIEW_CLOSE_METRICS_PATH -ErrorAction SilentlyContinue
    }
    $runDuration = [Math]::Round(((Get-Date) - $runStart).TotalSeconds, 2)
    $runStatus = if ($script:RunFailed) {
        'error'
    } elseif ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0) {
        'success'
    } else {
        "exit:$LASTEXITCODE"
    }
    "{0},{1},{2},{3}" -f $runTimestamp, $runStatus, $runDuration, ($commandLine -replace ',', ' ') | Add-Content -Path $script:RunHistoryPath
    Pop-Location
}






