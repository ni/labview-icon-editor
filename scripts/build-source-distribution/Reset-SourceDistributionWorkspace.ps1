[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [switch]$ArchiveExisting,
    [string]$ArchiveLabel,
    [switch]$SkipCleanup,
    [switch]$RunCommitIndex,
    [switch]$RunFullBuild,
    [string]$Runner = "gcli",
    [switch]$DryRun,
    [switch]$IncludeLogStash = $true,
    [switch]$AllowDirty = $true,
    [switch]$VerboseGit,
    [switch]$PerfCpu,
    [string[]]$AdditionalPaths,
    [string]$SummaryJsonPath,
    [switch]$EmitSummaryToConsole
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:ActionLog = @()

function Write-Step {
    param([string]$Message)
    Write-Host ("[step] {0}" -f $Message)
}

function Add-ActionLogEntry {
    param([pscustomobject]$Entry)
    $script:ActionLog += $Entry
}

function Invoke-Action {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    $entry = [pscustomobject]@{
        description = $Description
        timestamp   = (Get-Date).ToUniversalTime().ToString('o')
        dryRun      = [bool]$DryRun
        status      = $null
    }

    Write-Step $Description
    if ($DryRun) {
        Write-Host "  (dry-run)"
        $entry.status = "skipped-dry-run"
        Add-ActionLogEntry -Entry $entry
        return
    }

    try {
        & $Action
        $entry.status = "completed"
    }
    catch {
        $entry.status = "failed"
        $errorMessage = $_.Exception.Message
        if ($entry.PSObject.Properties['error']) {
            $entry.error = $errorMessage
        }
        else {
            $entry | Add-Member -NotePropertyName error -NotePropertyValue $errorMessage
        }
        Add-ActionLogEntry -Entry $entry
        throw
    }

    Add-ActionLogEntry -Entry $entry
}

function Resolve-CandidatePath {
    param(
        [string]$Base,
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        return $Candidate
    }

    return (Join-Path $Base $Candidate)
}

function Get-DirStats {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path = $Path; Files = 0; Bytes = 0 }
    }

    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue
    $count = if ($files) { $files.Count } else { 0 }
    $bytes = if ($files) { ($files | Measure-Object Length -Sum).Sum } else { 0 }
    return [pscustomobject]@{
        Path  = $Path
        Files = $count
        Bytes = $bytes
    }
}

function Get-ArchiveLabel {
    param([string]$Base)
    if ($ArchiveLabel) { return $ArchiveLabel }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return "${Base}-${timestamp}"
}

function Get-InventorySnapshot {
    param([array]$TargetList)

    $results = foreach ($t in $TargetList) {
        $stats = Get-DirStats -Path $t.Path
        [pscustomobject]@{
            Name  = $t.Name
            Path  = $stats.Path
            Files = $stats.Files
            SizeMB = [math]::Round($stats.Bytes / 1MB, 2)
        }
    }

    return $results
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$buildsRoot = Join-Path $repo 'builds'
$sdRoot = Join-Path $buildsRoot 'LabVIEWIconAPI'
$artifactsRoot = Join-Path $buildsRoot 'artifacts'
$logStashRoot = Join-Path $buildsRoot 'log-stash'
$cacheRoot = Join-Path $buildsRoot 'cache'

$targets = @(
    @{ Name = 'SourceDist'; Path = $sdRoot }
    @{ Name = 'Artifacts'; Path = $artifactsRoot }
)
if ($IncludeLogStash) {
    $targets += @{ Name = 'LogStash'; Path = $logStashRoot }
}
if ($AdditionalPaths) {
    foreach ($extra in $AdditionalPaths) {
        $resolvedExtra = Resolve-CandidatePath -Base $repo -Candidate $extra
        if (-not [string]::IsNullOrWhiteSpace($resolvedExtra)) {
            $label = Split-Path -Path $resolvedExtra -Leaf
            if ([string]::IsNullOrWhiteSpace($label)) { $label = $resolvedExtra }
            $targets += @{ Name = "Extra:$label"; Path = $resolvedExtra }
        }
    }
}

Write-Step "Inventory (files + size)"
$inventoryBefore = Get-InventorySnapshot -TargetList $targets
$inventoryBefore | Format-Table -AutoSize | Out-String | Write-Host

if ($ArchiveExisting) {
    $archiveRoot = Join-Path $buildsRoot 'archive'
    if (-not (Test-Path -LiteralPath $archiveRoot)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $archiveRoot | Out-Null
        }
    }
    $label = Get-ArchiveLabel -Base 'source-dist'
    $archivePath = Join-Path $archiveRoot $label
    if (-not $DryRun -and -not (Test-Path -LiteralPath $archivePath)) {
        New-Item -ItemType Directory -Path $archivePath | Out-Null
    }

    foreach ($t in $targets) {
        if (-not (Test-Path -LiteralPath $t.Path)) { continue }
        $dest = Join-Path $archivePath ([IO.Path]::GetFileName($t.Path))
        Invoke-Action -Description ("Archive {0} -> {1}" -f $t.Path, $dest) -Action {
            Move-Item -LiteralPath $t.Path -Destination $dest
        }
    }
}

if (-not $SkipCleanup) {
    foreach ($t in $targets) {
        if (-not (Test-Path -LiteralPath $t.Path)) { continue }
        Invoke-Action -Description ("Remove {0}" -f $t.Path) -Action {
            Remove-Item -LiteralPath $t.Path -Recurse -Force
        }
    }
}

if (-not (Test-Path -LiteralPath $cacheRoot)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }
}

$buildScript = Join-Path $repo 'scripts/build-source-distribution/Build_Source_Distribution.ps1'
if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Missing Build_Source_Distribution.ps1 at $buildScript"
}

function Resolve-LabVIEWSettings {
    param([string]$Repo)
    $versionScript = Join-Path $Repo 'scripts/get-package-lv-version.ps1'
    $bitnessScript = Join-Path $Repo 'scripts/get-package-lv-bitness.ps1'
    $lvVersion = & $versionScript -RepositoryPath $Repo
    $bitness = & $bitnessScript -RepositoryPath $Repo
    if ($bitness -eq 'both') { $bitness = '64' }
    return @{ Version = $lvVersion; Bitness = $bitness }
}

$lvSettings = $null
if ($RunCommitIndex -or $RunFullBuild) {
    $lvSettings = Resolve-LabVIEWSettings -Repo $repo
    Write-Step ("Resolved LV version {0} bitness {1}" -f $lvSettings.Version, $lvSettings.Bitness)
}

if ($RunCommitIndex) {
    $commitIndexScript = Join-Path $repo 'scripts/build-source-distribution/New-CommitIndex.ps1'
    if (-not (Test-Path -LiteralPath $commitIndexScript)) {
        throw "Missing New-CommitIndex.ps1 at $commitIndexScript"
    }

    $commitIndexPath = Join-Path $cacheRoot 'commit-index.json'
    Invoke-Action -Description "Generate commit index" -Action {
        & $commitIndexScript -RepositoryPath $repo -OutputPath $commitIndexPath -AllowDirty
    }
}

if ($RunFullBuild) {
    $xcliScript = Join-Path $repo 'scripts/run-xcli.ps1'
    if (-not (Test-Path -LiteralPath $xcliScript)) { throw "Missing run-xcli.ps1 at $xcliScript" }
    $xcliArgs = @('source-dist-build', '--repo', $repo, '--commit-index', 'builds/cache/commit-index.json')
    if ($VerboseGit) { $xcliArgs += '--verbose-git' }
    if ($PerfCpu) { $xcliArgs += '--perf-cpu' }
    if ($AllowDirty) { $xcliArgs += '--allow-dirty' }
    $invokeParams = @{
        Runner  = $Runner
        XcliArgs = $xcliArgs
    }
    Invoke-Action -Description "Run source-dist-build via run-xcli" -Action {
        & $xcliScript @invokeParams
    }
}

$inventoryAfter = Get-InventorySnapshot -TargetList $targets
Write-Step "Post-clean inventory"
$inventoryAfter | Format-Table -AutoSize | Out-String | Write-Host

$summary = [pscustomobject]@{
    repo                = $repo
    timestamp           = (Get-Date).ToUniversalTime().ToString('o')
    dryRun              = [bool]$DryRun
    archiveExisting     = [bool]$ArchiveExisting
    skipCleanup         = [bool]$SkipCleanup
    includeLogStash     = [bool]$IncludeLogStash
    runCommitIndex      = [bool]$RunCommitIndex
    runFullBuild        = [bool]$RunFullBuild
    runner              = $Runner
    additionalPaths     = $AdditionalPaths
    targets             = $targets
    inventoryBefore     = $inventoryBefore
    inventoryAfter      = $inventoryAfter
    actions             = $script:ActionLog
}

if ($SummaryJsonPath) {
    $summaryPath = Resolve-CandidatePath -Base $repo -Candidate $SummaryJsonPath
    $summaryDir = Split-Path -Parent $summaryPath
    if ($summaryDir -and -not (Test-Path -LiteralPath $summaryDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
        }
    }
    if (-not $DryRun) {
        $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    }
}

if ($EmitSummaryToConsole) {
    $summary | ConvertTo-Json -Depth 8 | Write-Host
}

Write-Step "Complete"
