#Requires -Version 7.0
<#
.SYNOPSIS
    Runs a local, CI-composite parity sequence for LabVIEW Icon Editor.

.DESCRIPTION
    Executes the key LabVIEW steps from ci-composite.yml locally:
    - Verify IE Paths gate (2021 32/64)
    - Apply VIPC dependencies (2021 32/64)
    - Missing-in-project checks (2021 32/64)
    - Unit tests (2021 32/64)
    - Build PPLs (2021 32/64) + rename
    - Build VIP (2021 64)

    GitHub-only gates (issue-status, labels, artifact upload) are not included.

.PARAMETER LabVIEWVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SkipVerifyIEPaths
    Skip the Verify IE Paths gate.

.PARAMETER EnsureCleanState
    Revert dev mode before running Verify IE Paths.

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
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$LabVIEWVersion = '2021',

    [switch]$SkipVerifyIEPaths,
    [switch]$EnsureCleanState,
    [switch]$SkipVipc,
    [switch]$SkipMissingInProject,
    [switch]$SkipUnitTests,
    [switch]$SkipBuildPpl,
    [switch]$SkipBuildVip,

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
    [int]$Major,

    [Parameter(Mandatory = $false)]
    [int]$Minor,

    [Parameter(Mandatory = $false)]
    [int]$Patch,

    [Parameter(Mandatory = $false)]
    [int]$Build,

    [Parameter(Mandatory = $false)]
    [string]$Commit
)

$ErrorActionPreference = 'Stop'

function Ensure-CsvHeader {
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
    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
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

function Assert-LabVIEWInstalled {
    param([string]$Version, [string]$Bitness)
    if (-not (Get-LabVIEWInstallRoot -Version $Version -Bitness $Bitness)) {
        throw "LabVIEW $Version ($Bitness-bit) install not found."
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

    $matches = $processes | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($installRoot, [System.StringComparison]::OrdinalIgnoreCase)
    }

    return ($matches -and $matches.Count -gt 0)
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
            -MinimumSupportedLVVersion $LabVIEWVersion `
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
    $status = if ($stepError) { 'error' } elseif ($exitCode -eq $null -or $exitCode -eq 0) { 'success' } else { "exit:$exitCode" }
    if ($script:StepHistoryPath) {
        "{0},{1},{2},{3}" -f $stepStart.ToString('yyyy-MM-dd HH:mm:ss'), ($Label -replace ',', ' '), $status, $duration | Add-Content -Path $script:StepHistoryPath
    }
    Write-Host ("=== {0} completed in {1}s ===" -f $Label, $duration)

    if ($stepError) {
        throw $stepError
    }
    if ($exitCode -ne 0 -and $exitCode -ne $null) {
        throw "$Label failed with exit code $exitCode."
    }
}

function Get-LocalVersionInfo {
    param([string]$RepoRoot, [string]$BumpType)

    $latestRaw = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0) {
        $latestRaw = ''
        $global:LASTEXITCODE = 0
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

function Get-RepoMetadata {
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

    $meta = Get-RepoMetadata -RepoRoot $RepoRoot
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
        "License Agreement Name" = "LICENSE"
        "Product Description Summary" = $description
        "Product Description" = $description
        "Release Notes - Change Log" = $releaseNotes
    }

    return ($info | ConvertTo-Json -Depth 5 -Compress)
}

function Copy-LatestVipToBuilds {
    param(
        [string]$RepoRoot,
        [datetime]$Since
    )

    $buildsDir = Join-Path $RepoRoot 'builds'
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
        [int]$TailLines = 120
    )

    $logFile = Join-Path $RepoRoot 'builds/logs/gcli-build.log'
    if (-not (Test-Path -Path $logFile)) {
        Write-Host ("g-cli build log not found at {0}" -f $logFile)
        return
    }

    Write-Host ("---- g-cli build log (last {0} lines) ----" -f $TailLines)
    Get-Content -Path $logFile -Tail $TailLines | ForEach-Object { Write-Host $_ }
    Write-Host "---- end g-cli build log ----"
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$worktreeRoot = $env:LVIE_WORKTREE_ROOT
if ([string]::IsNullOrWhiteSpace($worktreeRoot)) {
    $worktreeRoot = 'C:\dev'
}
$worktreeRootFull = [System.IO.Path]::GetFullPath($worktreeRoot)
if (-not $worktreeRootFull.EndsWith('\')) {
    $worktreeRootFull += '\'
}
$repoRootFull = [System.IO.Path]::GetFullPath($repoRoot)
if (-not $repoRootFull.EndsWith('\')) {
    $repoRootFull += '\'
}
if (-not $repoRootFull.StartsWith($worktreeRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning ("RepoRoot '{0}' is not under worktree root '{1}'. Consider using a short path or set LVIE_WORKTREE_ROOT." -f $repoRootFull.TrimEnd('\'), $worktreeRootFull.TrimEnd('\'))
}
Push-Location -Path $repoRoot
$script:RunFailed = $false
$runStart = Get-Date
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot = Join-Path $repoRoot 'TestResults/agent-logs'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$script:RunHistoryPath = Join-Path $logRoot 'run-history.csv'
$script:StepHistoryPath = Join-Path $logRoot 'step-history.csv'
$script:CloseHistoryPath = Join-Path $logRoot ("close-history-{0}.csv" -f $runTimestamp)
Ensure-CsvHeader -Path $script:RunHistoryPath -Header 'timestamp,status,duration_seconds,command'
Ensure-CsvHeader -Path $script:StepHistoryPath -Header 'timestamp,step,status,duration_seconds'
$env:LABVIEW_CLOSE_METRICS_PATH = $script:CloseHistoryPath
$runLog = Join-Path $logRoot "ci-local-$runTimestamp.log"
$commandLine = "Run-CICompositeLocal.ps1 -LabVIEWVersion $LabVIEWVersion -EnsureCleanState:$EnsureCleanState -SkipVerifyIEPaths:$SkipVerifyIEPaths -SkipVipc:$SkipVipc -SkipMissingInProject:$SkipMissingInProject -SkipUnitTests:$SkipUnitTests -SkipBuildPpl:$SkipBuildPpl -SkipBuildVip:$SkipBuildVip -BumpType $BumpType -ConnectTimeoutMs $ConnectTimeoutMs -ProcessTimeoutMs $ProcessTimeoutMs -StatusFileTimeoutMs $StatusFileTimeoutMs -VipmTimeoutSeconds $VipmTimeoutSeconds -CloseLabVIEWMode $CloseLabVIEWMode"
$script:TranscriptStarted = $false
try {
    Start-Transcript -Path $runLog -Append | Out-Null
    $script:TranscriptStarted = $true
}
catch {
    Write-Warning "Failed to start transcript logging to $runLog. Continuing without transcript."
}

try {
    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw "g-cli.exe not found in PATH."
    }

    Wait-ForIdle -RunHistoryPath $script:RunHistoryPath

    $bitnessList = @('64', '32')
    foreach ($bitness in $bitnessList) {
        Assert-LabVIEWInstalled -Version $LabVIEWVersion -Bitness $bitness
    }
    $vipLabVIEWMinorRevision = "0"

    $versionInfo = Get-LocalVersionInfo -RepoRoot $repoRoot -BumpType $BumpType
    if ($PSBoundParameters.ContainsKey('Major')) { $versionInfo.Major = $Major }
    if ($PSBoundParameters.ContainsKey('Minor')) { $versionInfo.Minor = $Minor }
    if ($PSBoundParameters.ContainsKey('Patch')) { $versionInfo.Patch = $Patch }
    if ($PSBoundParameters.ContainsKey('Build')) { $versionInfo.Build = $Build }
    if ($PSBoundParameters.ContainsKey('Commit')) { $versionInfo.Commit = $Commit }

    $artifactsRoot = Join-Path $repoRoot 'TestResults/ci-local'
    New-Item -Path $artifactsRoot -ItemType Directory -Force | Out-Null

    if (-not $SkipVerifyIEPaths) {
        $verifyArchive = Join-Path $artifactsRoot 'verify-iepaths'
        New-Item -Path $verifyArchive -ItemType Directory -Force | Out-Null

        foreach ($bitness in $bitnessList) {
            if ($EnsureCleanState) {
                Invoke-Checked -Label "Revert dev mode before VerifyIEPaths ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot `
                        -ConnectTimeoutMs $ConnectTimeoutMs `
                        -ProcessTimeoutMs $ProcessTimeoutMs
                }
            }

            Invoke-Checked -Label "Verify IE Paths gate ($bitness-bit)" -Action {
                & (Join-Path $repoRoot 'Tooling/Invoke-MissingIEFilesFromLVInstall.ps1') `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
                    -SupportedBitness $bitness `
                    -RepoRoot $repoRoot `
                    -ConnectTimeoutMs $ConnectTimeoutMs `
                    -ProcessTimeoutMs $ProcessTimeoutMs `
                    -StatusFileTimeoutMs $StatusFileTimeoutMs `
                    -StatusFileArchiveDirectory $verifyArchive
            }
        }
    }

    if (-not $SkipVipc) {
        foreach ($bitness in $bitnessList) {
            Invoke-Checked -Label "Apply VIPC (LV$LabVIEWVersion $bitness-bit)" -Action {
                & (Join-Path $repoRoot '.github/actions/apply-vipc/ApplyVIPC.ps1') `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
                    -VIP_LVVersion $LabVIEWVersion `
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
                Invoke-Checked -Label "Enable dev mode (missing-in-project, $bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/set-development-mode/Set_Development_Mode.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot `
                        -ConnectTimeoutMs $ConnectTimeoutMs `
                        -ProcessTimeoutMs $ProcessTimeoutMs
                }

                Invoke-Checked -Label "Missing-in-project ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1') `
                        -LVVersion $LabVIEWVersion `
                        -Arch $bitness `
                        -ProjectFile $projectFile
                }
            }
            finally {
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
                    -SupportedBitness $bitness `
                    -RepoRoot $repoRoot `
                    -ConnectTimeoutMs $ConnectTimeoutMs `
                    -ProcessTimeoutMs $ProcessTimeoutMs | Out-Null
                Invoke-CloseLabVIEW -Bitness $bitness -Context 'after missing-in-project'
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
                Invoke-Checked -Label "Enable dev mode (unit tests, $bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/set-development-mode/Set_Development_Mode.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot `
                        -ConnectTimeoutMs $ConnectTimeoutMs `
                        -ProcessTimeoutMs $ProcessTimeoutMs
                }

                Invoke-Checked -Label "Run unit tests ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/run-unit-tests/RunUnitTests.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -ProjectPath (Join-Path $repoRoot 'lv_icon_editor.lvproj')
                }
            }
            finally {
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
                    -SupportedBitness $bitness `
                    -RepoRoot $repoRoot `
                    -ConnectTimeoutMs $ConnectTimeoutMs `
                    -ProcessTimeoutMs $ProcessTimeoutMs | Out-Null
                Invoke-CloseLabVIEW -Bitness $bitness -Context 'after unit tests'
            }
        }
    }

    if (-not $SkipBuildPpl) {
        foreach ($bitness in $bitnessList) {
            try {
                Invoke-Checked -Label "Enable dev mode (build PPL, $bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/set-development-mode/Set_Development_Mode.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
                        -SupportedBitness $bitness `
                        -RepoRoot $repoRoot `
                        -ConnectTimeoutMs $ConnectTimeoutMs `
                        -ProcessTimeoutMs $ProcessTimeoutMs
                }

                Invoke-Checked -Label "Build PPL ($bitness-bit)" -Action {
                    & (Join-Path $repoRoot '.github/actions/build-lvlibp/Build_lvlibp.ps1') `
                        -MinimumSupportedLVVersion $LabVIEWVersion `
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
                & (Join-Path $repoRoot '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1') `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
                    -SupportedBitness $bitness `
                    -RepoRoot $repoRoot `
                    -ConnectTimeoutMs $ConnectTimeoutMs `
                    -ProcessTimeoutMs $ProcessTimeoutMs | Out-Null
                Invoke-CloseLabVIEW -Bitness $bitness -Context 'after PPL build'
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
                -MinimumSupportedLVVersion $LabVIEWVersion `
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
                & (Join-Path $repoRoot '.github/actions/build-vip/build_vip.ps1') `
                    -SupportedBitness 64 `
                    -RepoRoot $repoRoot `
                    -VIPBPath $VipbPath `
                    -MinimumSupportedLVVersion $LabVIEWVersion `
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
            Write-GCliBuildLogTail -RepoRoot $repoRoot
            throw
        }

        $vipOutput = Copy-LatestVipToBuilds -RepoRoot $repoRoot -Since $vipBuildStart
        if (-not $vipOutput) {
            Write-GCliBuildLogTail -RepoRoot $repoRoot
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
            # ignore transcript failures
        }
    }
    if ($env:LABVIEW_CLOSE_METRICS_PATH) {
        Remove-Item Env:LABVIEW_CLOSE_METRICS_PATH -ErrorAction SilentlyContinue
    }
    $runDuration = [Math]::Round(((Get-Date) - $runStart).TotalSeconds, 2)
    $runStatus = if ($script:RunFailed) {
        'error'
    } elseif ($LASTEXITCODE -eq $null -or $LASTEXITCODE -eq 0) {
        'success'
    } else {
        "exit:$LASTEXITCODE"
    }
    "{0},{1},{2},{3}" -f $runTimestamp, $runStatus, $runDuration, ($commandLine -replace ',', ' ') | Add-Content -Path $script:RunHistoryPath
    Pop-Location
}
