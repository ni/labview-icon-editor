#Requires -Version 7.0
<#
.SYNOPSIS
    Runs VerifyIEPaths.vi via g-cli and reads the status file.

.DESCRIPTION
    Executes Tooling\VerifyIEPaths.vi with no VI arguments using g-cli for the
    specified LabVIEW version and bitness. Reads the status file produced at
    the repo root to report pass/fail details.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).
    Alias: MinimumSupportedLVVersion.

.PARAMETER SupportedBitness
    LabVIEW bitness to target ("32" or "64"). Defaults to "64".

.PARAMETER EnableDevMode
    Enable LabVIEW Icon Editor development mode before running VerifyIEPaths.
    When enabled, missing paths that are expected in dev mode (LabVIEW Icon API and lv_icon.lvlibp)
    are treated as success; other missing paths still fail the check.
    Non-zero VerifyIEPaths g-cli exit codes are ignored so the status file can be evaluated.

.PARAMETER EnableDevModeNoLabVIEW
    Enable development mode without launching LabVIEW by editing install files and LabVIEW.ini.
    When enabled, missing paths that are expected in dev mode (LabVIEW Icon API and lv_icon.lvlibp)
    are treated as success; other missing paths still fail the check.

.PARAMETER AllowFallbackToNoLabVIEW
    When EnableDevMode is set, allow fallback to the no-LabVIEW path if the
    LabVIEW toggle fails.

.PARAMETER AutoRevertIfEnabled
    When enabled, automatically revert dev mode if the install appears to be
    in dev mode (or mixed state) before running VerifyIEPaths.

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.

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

.PARAMETER StatusFileName
    Optional status file name (relative to repo root) or absolute path.

.PARAMETER StatusFileTimeoutMs
    Timeout in milliseconds to wait for the status file to appear.

.PARAMETER DevModeConnectTimeoutMs
    g-cli connect timeout in milliseconds for PrepareIESource.vi when dev mode is enabled.

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
    [AllowNull()]
    [AllowEmptyString()]
    [Alias('MinimumSupportedLVVersion')]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness = '64',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$DevModeConnectTimeoutMs = 15000,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDevMode,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDevModeNoLabVIEW,

    [Parameter(Mandatory = $false)]
    [switch]$AllowFallbackToNoLabVIEW,

    [Parameter(Mandatory = $false)]
    [switch]$AutoRevertIfEnabled,

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
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [switch]$SkipWorktreeRootCheck,

    [switch]$AutoWorktree,

    [string]$RunId,

    [string]$ArtifactRoot,

    [switch]$CleanRoom
)

$ErrorActionPreference = 'Stop'

$devModeRequested = $EnableDevMode -or $EnableDevModeNoLabVIEW
if ($EnableDevMode -and $EnableDevModeNoLabVIEW) {
    Write-Warning "EnableDevModeNoLabVIEW is set; ignoring EnableDevMode."
}

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

function Test-IEDevModeEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWInstallRoot
    )

    $installPaths = @{
        IconApiFolder = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API'
        IconApiZip    = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API.zip'
        Lvlibp        = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.lvlibp'
        Ship          = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.ship'
    }

    $hasLvlibp = Test-Path -Path $installPaths.Lvlibp
    $hasShip = Test-Path -Path $installPaths.Ship
    $hasIconFolder = Test-Path -Path $installPaths.IconApiFolder
    $hasIconZip = Test-Path -Path $installPaths.IconApiZip

    return ($hasShip -and (-not $hasLvlibp) -and (-not $hasIconFolder) -and $hasIconZip)
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

    switch ($raw.Trim().ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default { return $Fallback }
    }
}

function Get-IEInstallState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWInstallRoot
    )

    $paths = [ordered]@{
        IconApiFolder = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API'
        IconApiZip    = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API.zip'
        Lvlibp        = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.lvlibp'
        Ship          = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.ship'
    }

    $state = [ordered]@{
        InstallRoot     = $LabVIEWInstallRoot
        HasIconApiFolder = Test-Path -Path $paths.IconApiFolder
        HasIconApiZip    = Test-Path -Path $paths.IconApiZip
        HasLvlibp        = Test-Path -Path $paths.Lvlibp
        HasShip          = Test-Path -Path $paths.Ship
    }
    $state.DevModeEnabled = ($state.HasShip -and (-not $state.HasLvlibp) -and (-not $state.HasIconApiFolder) -and $state.HasIconApiZip)
    $state.MixedState = (($state.HasShip -and $state.HasLvlibp) -or ($state.HasIconApiFolder -and $state.HasIconApiZip))
    return $state
}

function Format-IEInstallState {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    return ("lv_icon.lvlibp={0}; lv_icon.ship={1}; icon_api_folder={2}; icon_api_zip={3}; dev_mode={4}; mixed_state={5}" -f `
            $State.HasLvlibp, $State.HasShip, $State.HasIconApiFolder, $State.HasIconApiZip, $State.DevModeEnabled, $State.MixedState)
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
$artifactRootResolved = $null
$preflight = $null
$skipGuard = $SkipWorktreeRootCheck
if (-not $skipGuard -and -not [string]::IsNullOrWhiteSpace($env:LVIE_SKIP_WORKTREE_ROOT_CHECK)) {
    $normalized = $env:LVIE_SKIP_WORKTREE_ROOT_CHECK.Trim().ToLowerInvariant()
    if ($normalized -notin @('0', 'false', 'no')) {
        $skipGuard = $true
    }
}

if ($AutoWorktree -and -not $skipGuard) {
    $ensureScript = Join-Path $repoRoot 'Tooling\Ensure-WorktreeRoot.ps1'
    $newWorktreeScript = Join-Path $repoRoot 'Tooling\New-CIWorktree.ps1'
    if ((Test-Path -Path $ensureScript) -and (Test-Path -Path $newWorktreeScript)) {
        $resolvedWorktreeRoot = & $ensureScript -WorktreeRoot $WorktreeRoot
        $repoFull = [System.IO.Path]::GetFullPath($repoRoot)
        $rootFull = [System.IO.Path]::GetFullPath($resolvedWorktreeRoot)
        if (-not $repoFull.EndsWith('\')) { $repoFull += '\' }
        if (-not $rootFull.EndsWith('\')) { $rootFull += '\' }
        $underRoot = $repoFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)

        if (-not $underRoot) {
            $env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot
            $envName = $env:LVIE_WORKTREE_NAME
            $envPrefix = $env:LVIE_WORKTREE_NAME_PREFIX
            $noRepoPrefix = $false
            if (-not [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_NO_REPO_PREFIX)) {
                $flag = $env:LVIE_WORKTREE_NO_REPO_PREFIX.Trim().ToLowerInvariant()
                $noRepoPrefix = ($flag -notin @('0', 'false', 'no'))
            }

            $suffix = if ([string]::IsNullOrWhiteSpace($envName)) {
                $prefix = if ([string]::IsNullOrWhiteSpace($envPrefix)) { 'ci-guard' } else { $envPrefix.Trim() }
                "{0}-{1}" -f $prefix, (Get-Date -Format 'yyyyMMdd-HHmmss')
            } else {
                $envName.Trim()
            }

            $worktreeArgs = @(
                '-Ref', 'HEAD',
                '-Name', $suffix,
                '-WorktreeRoot', $resolvedWorktreeRoot
            )
            if ($noRepoPrefix) {
                $worktreeArgs += '-NoRepoNamePrefix'
            }

            Write-Host ("RepoRoot '{0}' is not under worktree root '{1}'. Re-invoking from worktree..." -f $repoRoot, $resolvedWorktreeRoot)
            $worktreePath = & $newWorktreeScript @worktreeArgs
            Write-Host ("Using worktree: {0}" -f $worktreePath)

            $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
            $reinvokeArgs = @()
            for ($i = 0; $i -lt $scriptArgs.Count; $i++) {
                $arg = $scriptArgs[$i]
                if ($arg -eq '-AutoWorktree') {
                    continue
                }
                if ($arg -eq '-WorktreeRoot') {
                    $i++
                    continue
                }
                $reinvokeArgs += $arg
            }
            $relativeScript = [System.IO.Path]::GetRelativePath($repoRoot, $PSCommandPath)
            $scriptFull = Join-Path $worktreePath $relativeScript
            & pwsh -NoProfile -File $scriptFull @reinvokeArgs
            return
        }
    }
}
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflightParams = @{
        RepoRoot       = $repoRoot
        LabVIEWVersion = $LabVIEWVersion
        LabVIEWBitness = $SupportedBitness
        ScriptPath     = $relativeScript
        ScriptArguments = $scriptArgs
        RequireGcli    = $true
    }
    if ($SkipWorktreeRootCheck) { $preflightParams.SkipWorktreeRootCheck = $true }
    if ($AutoWorktree) { $preflightParams.AutoWorktree = $true }
    if ($PSBoundParameters.ContainsKey('RunId')) { $preflightParams.RunId = $RunId }
    if ($PSBoundParameters.ContainsKey('ArtifactRoot')) { $preflightParams.ArtifactRoot = $ArtifactRoot }
    if ($CleanRoom) { $preflightParams.CleanRoom = $true }

    $preflight = Invoke-Preflight @preflightParams
    if ($preflight.Reinvoked) {
        return
    }
    $repoRoot = $preflight.RepoRoot
    $artifactRootResolved = $preflight.ArtifactRoot
}
$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    $labviewYear = '2021'
}
if ([string]::IsNullOrWhiteSpace($StatusFileArchiveDirectory) -and $artifactRootResolved) {
    $StatusFileArchiveDirectory = Join-Path $artifactRootResolved 'verify-iepaths'
}
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

$installRoot = Get-LabVIEWInstallRoot -Version $labviewYear -Bitness $SupportedBitness
if (-not $installRoot) {
    throw "LabVIEW $labviewYear ($SupportedBitness-bit) install not found."
}

$summaryPath = $env:GITHUB_STEP_SUMMARY
function Write-VerifyIEPathsSummaryLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($summaryPath)) {
        return
    }
    $Line | Out-File -FilePath $summaryPath -Append -Encoding utf8
}

$strictState = Resolve-BoolFromEnv -Name 'LVIE_VERIFY_IEPATHS_STRICT' -Fallback $false
$autoRevert = $AutoRevertIfEnabled -or (Resolve-BoolFromEnv -Name 'LVIE_VERIFY_IEPATHS_AUTO_REVERT' -Fallback $false)
$forceNoLabVIEW = Resolve-BoolFromEnv -Name 'LVIE_FORCE_NO_LABVIEW_DEVMODE' -Fallback $false
$preferNoLabVIEW = $forceNoLabVIEW -or $EnableDevModeNoLabVIEW -or (Resolve-BoolFromEnv -Name 'LVIE_VERIFY_IEPATHS_NO_LABVIEW' -Fallback $false)
$preState = Get-IEInstallState -LabVIEWInstallRoot $installRoot
Write-Host ("Install state (pre): {0}" -f (Format-IEInstallState -State $preState))
Write-VerifyIEPathsSummaryLine ("Verify IE Paths pre-state ({0} {1}-bit): {2}" -f $labviewYear, $SupportedBitness, (Format-IEInstallState -State $preState))

if (($preState.MixedState -or $preState.DevModeEnabled) -and $autoRevert) {
    Write-Host "Pre-run install state indicates dev mode or mixed state; reverting before VerifyIEPaths."
    Write-VerifyIEPathsSummaryLine "Verify IE Paths auto-revert: pre-state indicated dev mode or mixed state; attempting revert."

    $revertScript = Join-Path $repoRoot '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
    if (-not (Test-Path -Path $revertScript)) {
        throw "RevertDevelopmentMode.ps1 not found at $revertScript"
    }

    if ($preferNoLabVIEW) {
        & $revertScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness $SupportedBitness `
            -RepoRoot $repoRoot `
            -ConnectTimeoutMs $ConnectTimeoutMs `
            -ProcessTimeoutMs $ProcessTimeoutMs
    } else {
        & $revertScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness $SupportedBitness `
            -RepoRoot $repoRoot `
            -ConnectTimeoutMs $ConnectTimeoutMs `
            -ProcessTimeoutMs $ProcessTimeoutMs `
            -UseLabVIEW `
            -AllowFallbackToNoLabVIEW:$AllowFallbackToNoLabVIEW
    }

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Dev mode auto-revert failed with exit code $LASTEXITCODE."
    }

    $postRevertState = Get-IEInstallState -LabVIEWInstallRoot $installRoot
    Write-Host ("Install state (post-revert): {0}" -f (Format-IEInstallState -State $postRevertState))
    Write-VerifyIEPathsSummaryLine ("Verify IE Paths post-revert ({0} {1}-bit): {2}" -f $labviewYear, $SupportedBitness, (Format-IEInstallState -State $postRevertState))
    $preState = $postRevertState
}

if ($preState.MixedState) {
    $message = "Install appears to be in a mixed dev-mode state before VerifyIEPaths."
    if ($strictState) {
        throw $message
    }
    Write-Warning $message
}
if ($devModeRequested -and $preState.DevModeEnabled) {
    $message = "Dev mode appears enabled before VerifyIEPaths; previous runs may have left the runner in dev mode."
    if ($strictState) {
        throw $message
    }
    Write-Warning $message
}

if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
    throw "g-cli.exe not found in PATH."
}

$gCliPath = (Get-Command g-cli -ErrorAction SilentlyContinue).Source

if ($devModeRequested) {
    if ($preferNoLabVIEW) {
        $devModeScript = Join-Path $repoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
        if (-not (Test-Path -Path $devModeScript)) {
            throw "Set-DevelopmentMode-NoLabVIEW.ps1 not found at $devModeScript"
        }

        Write-Host ("Enabling development mode without LabVIEW before VerifyIEPaths (LV{0} {1}-bit)..." -f $labviewYear, $SupportedBitness)
        & $devModeScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness $SupportedBitness `
            -RepoRoot $repoRoot
    } else {
        $devModeScript = Join-Path $repoRoot '.github\actions\set-development-mode\Set_Development_Mode.ps1'
        if (-not (Test-Path -Path $devModeScript)) {
            throw "Set_Development_Mode.ps1 not found at $devModeScript"
        }

        Write-Host ("Enabling development mode before VerifyIEPaths (LV{0} {1}-bit)..." -f $labviewYear, $SupportedBitness)
        & $devModeScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness $SupportedBitness `
            -RepoRoot $repoRoot `
            -ConnectTimeoutMs $DevModeConnectTimeoutMs `
            -ProcessTimeoutMs $ProcessTimeoutMs `
            -UseLabVIEW `
            -AllowFallbackToNoLabVIEW:$AllowFallbackToNoLabVIEW
    }

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Development mode enable failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-IEDevModeEnabled -LabVIEWInstallRoot $installRoot)) {
        Write-Warning ("Development mode did not appear enabled (LV{0} {1}-bit). VerifyIEPaths may not behave as expected." -f $labviewYear, $SupportedBitness)
    }

    $postEnableState = Get-IEInstallState -LabVIEWInstallRoot $installRoot
    Write-Host ("Install state (post-enable): {0}" -f (Format-IEInstallState -State $postEnableState))
    Write-VerifyIEPathsSummaryLine ("Verify IE Paths post-enable ({0} {1}-bit): {2}" -f $labviewYear, $SupportedBitness, (Format-IEInstallState -State $postEnableState))
}

$gCliArgs = @(
    '--lv-ver', $labviewYear,
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
        $allowGcliExit = $IgnoreGcliExitCode -or $devModeRequested
        if ($allowGcliExit) {
            $reason = if ($IgnoreGcliExitCode) { 'IgnoreGcliExitCode is set' } else { 'development mode is enabled' }
            Write-Warning ("VerifyIEPaths.vi returned exit code {0}; continuing because {1}." -f $result.ExitCode, $reason)
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
            Write-VerifyIEPathsSummaryLine ("Verify IE Paths status: {0}" -f $statusInfo.RawStatus)
            if ($statusInfo.MissingPaths -and $statusInfo.MissingPaths.Count -gt 0) {
                $missingSummary = $statusInfo.MissingPaths -join ', '
                Write-VerifyIEPathsSummaryLine ("Verify IE Paths missing paths: {0}" -f $missingSummary)
            }

            if ($statusInfo.IsFailure -and -not $IgnoreStatusFailure) {
                $missing = if ($statusInfo.MissingPaths -and $statusInfo.MissingPaths.Count -gt 0) {
                    $statusInfo.MissingPaths -join ', '
                } else {
                    $statusInfo.RawStatus
                }

                if ($devModeRequested) {
                    $unexpected = @()
                    if ($statusInfo.MissingPaths -and $statusInfo.MissingPaths.Count -gt 0) {
                        $unexpected = $statusInfo.MissingPaths | Where-Object {
                            $path = $_
                            -not ($path -match '(?i)LabVIEW Icon API') `
                                -and -not ($path -match '(?i)lv_icon\.lvlibp') `
                                -and -not ($path -match '(?i)lv_icon\.vi(t)?') `
                                -and -not ($path -match '(?i)lv_iconeditor\.lvlib') `
                                -and -not ($path -match '(?i)NIIconEditor')
                        }
                    }

                    if ($unexpected -and $unexpected.Count -gt 0) {
                        throw "VerifyIEPaths reported unexpected missing paths in dev mode: $missing"
                    }

                    Write-Host "VerifyIEPaths reported missing paths expected in development mode; treating as success."
                } else {
                    throw "VerifyIEPaths reported missing paths: $missing"
                }
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
            Write-VerifyIEPathsSummaryLine $message
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
        & g-cli --lv-ver $labviewYear --arch $SupportedBitness QuitLabVIEW | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW: {0}" -f $_.Exception.Message)
    }
}

if ($preflight -and $preflight.CleanRoomAfter) {
    Invoke-PreflightCleanup -RepoRoot $preflight.RepoRoot -Phase 'after'
}

