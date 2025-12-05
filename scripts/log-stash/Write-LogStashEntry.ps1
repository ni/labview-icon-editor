[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$Category,

    [string]$Label,
    [string[]]$LogPaths,
    [string[]]$AttachmentPaths,

    [string]$Status = 'success',
    [string]$Commit,
    [string]$GitRef,
    [string]$LabVIEWVersion,
    [string[]]$Bitness,

    [string]$ProducerScript,
    [string]$ProducerTask,
    [hashtable]$ProducerArgs,

    [datetime]$StartedAtUtc,
    [int]$DurationMs,

    [int]$RetentionDays = 14,

    [string]$BundleTimestamp,
    [switch]$CompressBundle,

    [int]$IndexTrim = 50
)

$ErrorActionPreference = 'Stop'

function Get-CommitKey {
    param([string]$RepoPath,[string]$CommitParam)
    if (-not [string]::IsNullOrWhiteSpace($CommitParam)) { return $CommitParam }
    $key = $null
    try {
        Push-Location -LiteralPath $RepoPath
        $key = (git rev-parse --short HEAD 2>$null).Trim()
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
    if ([string]::IsNullOrWhiteSpace($key)) { $key = 'manual' }
    return $key
}

function Get-GitRef {
    param([string]$RepoPath,[string]$RefParam)
    if (-not [string]::IsNullOrWhiteSpace($RefParam)) { return $RefParam }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REF)) { return $env:GITHUB_REF }
    $ref = $null
    try {
        Push-Location -LiteralPath $RepoPath
        $ref = (git symbolic-ref --short HEAD 2>$null).Trim()
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
    return $ref
}

function Sanitize-Name {
    param([string]$Value,[string]$Fallback)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Fallback }
    # Replace path separators and other invalid chars with '-'
    $clean = $Value -replace '[\\/:*?"<>|]+', '-'
    $clean = $clean.Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) { return $Fallback }
    return $clean
}

function Get-RelativePathSafe {
    param([string]$Base,[string]$Target)
    try {
        return [System.IO.Path]::GetRelativePath($Base, $Target)
    }
    catch {
        return $Target
    }
}

function New-DirectorySafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Add-IndexEntry {
    param(
        [string]$IndexPath,
        [hashtable]$Entry,
        [int]$TrimCount
    )

    $list = @()
    if (Test-Path -LiteralPath $IndexPath) {
        try {
            $list = Get-Content -LiteralPath $IndexPath -Raw | ConvertFrom-Json
        }
        catch {
            $list = @()
        }
    }

    $list = @($Entry) + @($list)
    if ($TrimCount -gt 0 -and $list.Count -gt $TrimCount) {
        $list = $list | Select-Object -First $TrimCount
    }
    $list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $IndexPath -Encoding utf8
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$commitKey = Get-CommitKey -RepoPath $repoRoot -CommitParam $Commit
$gitRef = Get-GitRef -RepoPath $repoRoot -RefParam $GitRef
$isCi = ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true')
$runProvider = if ($env:GITHUB_ACTIONS -eq 'true') { 'github' } else { $null }
$runId = $env:GITHUB_RUN_ID
$runAttempt = $env:GITHUB_RUN_ATTEMPT
$runJob = $env:GITHUB_JOB

$labelValue = $Label
if ([string]::IsNullOrWhiteSpace($labelValue)) {
    if ($isCi -and -not [string]::IsNullOrWhiteSpace($runJob)) {
        $labelValue = $runJob
    }
    else {
        $labelValue = 'local'
    }
}

$timestamp = if (-not [string]::IsNullOrWhiteSpace($BundleTimestamp)) { $BundleTimestamp } else { Get-Date -Format "yyyyMMdd-HHmmss" }
$categoryClean = Sanitize-Name -Value $Category -Fallback 'unknown'
$labelClean = Sanitize-Name -Value $labelValue -Fallback 'log'
$bundleRoot = Join-Path $repoRoot "builds\log-stash"
$bundleDir = Join-Path $bundleRoot (Join-Path $commitKey (Join-Path $categoryClean ("$timestamp-$labelClean")))

$logsDir = Join-Path $bundleDir 'logs'
$attachmentsDir = Join-Path $bundleDir 'attachments'

New-DirectorySafe -Path $logsDir
New-DirectorySafe -Path $attachmentsDir

$copiedLogs = @()
$copiedAttachments = @()

foreach ($logPath in ($LogPaths ?? @())) {
    if (-not [string]::IsNullOrWhiteSpace($logPath) -and (Test-Path -LiteralPath $logPath)) {
        $dest = Join-Path $logsDir (Split-Path -Leaf $logPath)
        Copy-Item -LiteralPath $logPath -Destination $dest -Force
        $copiedLogs += Get-RelativePathSafe -Base $repoRoot -Target (Resolve-Path -LiteralPath $dest).ProviderPath
    }
    else {
        Write-Warning ("[log-stash] Log path missing or empty: {0}" -f $logPath)
    }
}

foreach ($att in ($AttachmentPaths ?? @())) {
    if (-not [string]::IsNullOrWhiteSpace($att) -and (Test-Path -LiteralPath $att)) {
        $dest = Join-Path $attachmentsDir (Split-Path -Leaf $att)
        Copy-Item -LiteralPath $att -Destination $dest -Force
        $copiedAttachments += Get-RelativePathSafe -Base $repoRoot -Target (Resolve-Path -LiteralPath $dest).ProviderPath
    }
}

$startUtc = if ($StartedAtUtc) { $StartedAtUtc.ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
$retentionUtc = $null
if ($RetentionDays -gt 0) {
    try {
        $retentionUtc = $startUtc.AddDays($RetentionDays)
    }
    catch {
        $retentionUtc = $null
    }
}

$manifest = [ordered]@{
    type           = 'log'
    category       = $categoryClean
    commit         = $commitKey
    git_ref        = $gitRef
    run            = $null
    labview_version= $LabVIEWVersion
    bitness        = $Bitness
    producer       = $null
    status         = $Status
    started_utc    = $startUtc.ToString("o")
    duration_ms    = $DurationMs
    retention_utc  = if ($retentionUtc) { $retentionUtc.ToString("o") } else { $null }
    files          = [ordered]@{
        logs        = $copiedLogs
        attachments = $copiedAttachments
        bundle      = Get-RelativePathSafe -Base $repoRoot -Target $bundleDir
    }
    notes          = @()
}

$runObj = @{}
if ($isCi) { $runObj['ci'] = $true }
if ($runProvider) { $runObj['provider'] = $runProvider }
if ($runId) { $runObj['run_id'] = $runId }
if ($runAttempt) { $runObj['attempt'] = $runAttempt }
if ($runJob) { $runObj['job'] = $runJob }
if ($runObj.Keys.Count -gt 0) { $manifest.run = $runObj }

$prodObj = @{}
if ($ProducerScript) { $prodObj['script'] = $ProducerScript }
if ($ProducerTask) { $prodObj['task'] = $ProducerTask }
if ($ProducerArgs) { $prodObj['args'] = $ProducerArgs }
if ($prodObj.Keys.Count -gt 0) { $manifest.producer = $prodObj }

$manifestPath = Join-Path $bundleDir 'manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$indexPath = Join-Path $bundleRoot 'index.json'
$entry = @{
    commit    = $commitKey
    category  = $categoryClean
    status    = $Status
    bundle    = Get-RelativePathSafe -Base $repoRoot -Target $bundleDir
    timestamp = $manifest.started_utc
    retention = $manifest.retention_utc
}
Add-IndexEntry -IndexPath $indexPath -Entry $entry -TrimCount $IndexTrim

$bundleZipPath = $null
if ($CompressBundle) {
    $bundleZipPath = "$bundleDir.zip"
    if (Test-Path -LiteralPath $bundleZipPath) {
        Remove-Item -LiteralPath $bundleZipPath -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -LiteralPath $bundleDir -DestinationPath $bundleZipPath -Force
    $manifest.files.bundle_zip = Get-RelativePathSafe -Base $repoRoot -Target $bundleZipPath
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
}

Write-Host ("[artifact][log-stash] Bundle: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target $bundleDir))
Write-Host ("[artifact][log-stash] Manifest: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target $manifestPath))
if ($bundleZipPath) {
    Write-Host ("[artifact][log-stash] Bundle zip: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target $bundleZipPath))
}
