[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$VipbPath = 'Tooling/deployment/seed.vipb',
    [string]$BuildSpecName = 'Editor Packed Library',
    [string]$TargetName = 'My Computer',
    [string]$LabVIEWCLIPath = 'LabVIEWCLI',
    [string]$LabVIEWPath,
    [int]$PortNumber,
    [string]$LogFilePath,
    [string]$ManifestPath,
    [switch]$AllowLabVIEWFallback = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
$projectFull = (Resolve-Path -LiteralPath $ProjectPath).ProviderPath
$vipbFull = $null
try {
    $vipbCandidate = if ([System.IO.Path]::IsPathRooted($VipbPath)) { $VipbPath } else { Join-Path $repoRoot $VipbPath }
    $vipbFull = (Resolve-Path -LiteralPath $vipbCandidate).ProviderPath
} catch {
    Write-Warning "[lvsd] Unable to resolve VIPB at $VipbPath; LabVIEW version will be unknown."
}

# Capture repo commit/ref
$repoCommit = $null
$repoRef = $null
try {
    $repoCommit = (git -C $repoRoot rev-parse --short HEAD).Trim()
} catch {}
try {
    $repoRef = (git -C $repoRoot symbolic-ref --short -q HEAD).Trim()
} catch {}

# Derive LabVIEW version from VIPB if available
$lvVersion = $null
$getLvVersionScript = Join-Path $repoRoot 'scripts/get-package-lv-version.ps1'
if ($vipbFull -and (Test-Path -LiteralPath $getLvVersionScript -PathType Leaf)) {
    try {
        $lvVersion = & $getLvVersionScript -RepositoryPath $repoRoot
    } catch {
        Write-Warning ("[lvsd] Failed to parse LabVIEW version from {0}: {1}" -f $vipbFull, $_.Exception.Message)
    }
}

# Derive LabVIEW bitness if available
$lvBitness = $null
$getBitnessScript = Join-Path $repoRoot 'scripts/get-package-lv-bitness.ps1'
if ($vipbFull -and (Test-Path -LiteralPath $getBitnessScript -PathType Leaf)) {
    try {
        $lvBitness = & $getBitnessScript -RepositoryPath $repoRoot
        if ($lvBitness -eq 'both') { $lvBitness = '64' }
    } catch {
        Write-Warning ("[lvsd] Failed to parse LabVIEW bitness from {0}: {1}" -f $vipbFull, $_.Exception.Message)
    }
}

# Derive LabVIEW path if not provided and version/bitness are known
if (-not $LabVIEWPath -and $lvVersion -and $lvBitness) {
    $candidate = if ($lvBitness -eq '32') {
        "C:\Program Files (x86)\National Instruments\LabVIEW $lvVersion\LabVIEW.exe"
    } else {
        "C:\Program Files\National Instruments\LabVIEW $lvVersion\LabVIEW.exe"
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $LabVIEWPath = $candidate
    } else {
        $msg = "[lvsd] Expected LabVIEW {0}-bit executable not found at {1}. Install LabVIEW {2} or pass -LabVIEWPath to override."
        if ($AllowLabVIEWFallback) {
            Write-Warning ($msg -f $lvBitness, $candidate, $lvVersion)
        } else {
            throw ($msg -f $lvBitness, $candidate, $lvVersion)
        }
    }
}

# If a port was not provided, try to read it from LabVIEW.ini next to the executable; default to 3363 otherwise.
if (-not $PortNumber -and $LabVIEWPath) {
    $ini = Join-Path (Split-Path -Parent $LabVIEWPath) 'LabVIEW.ini'
    if (Test-Path -LiteralPath $ini -PathType Leaf) {
        $line = Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*server\.tcp\.port\s*=\s*(\d+)' } | Select-Object -First 1
        if ($line -and $Matches[1]) {
            $PortNumber = [int]$Matches[1]
        }
    }
}
if (-not $PortNumber) { $PortNumber = 3363 }

if (-not $ManifestPath) {
    $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
    $ManifestPath = Join-Path $repoRoot ("reports/source-distribution-manifest-{0}.json" -f $stamp)
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ManifestPath) | Out-Null

$start = Get-Date
$tmpOut = New-TemporaryFile
$tmpErr = New-TemporaryFile

$argsList = @(
    '-OperationName', 'ExecuteBuildSpec',
    '-ProjectPath', $projectFull,
    '-TargetName', $TargetName
)
if ($BuildSpecName) { $argsList += @('-BuildSpecName', $BuildSpecName) }
if ($LogFilePath) {
    try {
        $LogFilePath = [System.IO.Path]::GetFullPath($LogFilePath)
        $logDir = Split-Path -Parent $LogFilePath
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
    } catch { }
    $argsList += @('-LogFilePath', $LogFilePath)
}
if ($LabVIEWPath) {
    $argsList += @('-LabVIEWPath', $LabVIEWPath)
}
if ($PortNumber) {
    $argsList += @('-PortNumber', $PortNumber)
}

$argString = ($argsList | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '
Write-Host "[lvsd] Invoking LabVIEWCLI: $LabVIEWCLIPath $argString"
$proc = Start-Process -FilePath $LabVIEWCLIPath -ArgumentList $argString -NoNewWindow -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -PassThru -Wait
$exit = $proc.ExitCode
$durationMs = [int]((Get-Date) - $start).TotalMilliseconds

$stdout = Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue
$stderr = Get-Content -LiteralPath $tmpErr -ErrorAction SilentlyContinue
Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

if ($stdout) { Write-Host $stdout }
if ($stderr) { Write-Warning ($stderr -join [Environment]::NewLine) }

# Parse generated files from CLI output.
$generated = @()
$capture = $false
foreach ($line in $stdout) {
    if ($line -match 'Generated files are:') {
        $capture = $true
        continue
    }
    if ($capture) {
        $trimmed = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed) -and (Test-Path -LiteralPath $trimmed)) {
            $generated += (Resolve-Path -LiteralPath $trimmed).ProviderPath
        }
    }
}

if (-not $generated -and $exit -eq 0) {
    Write-Warning "[lvsd] No generated files detected from CLI output; manifest will contain an empty outputs list."
}

function Get-GitCommitHash {
    param([string]$Repo, [string]$FilePath)
    try {
        $rel = [System.IO.Path]::GetRelativePath($Repo, $FilePath)
        $hash = git -C $Repo log -n 1 --pretty=format:%H -- "$rel" 2>$null
        if ($LASTEXITCODE -eq 0 -and $hash) { return $hash.Trim() }
    } catch { }
    return $null
}

$timestamp = (Get-Date).ToString('o')
$outputs = @()
foreach ($file in $generated) {
    $entry = [ordered]@{
        vi_path   = [System.IO.Path]::GetRelativePath($repoRoot, $file)
        commit    = Get-GitCommitHash -Repo $repoRoot -FilePath $file
        build_spec= $BuildSpecName
        timestamp = $timestamp
    }
    $outputs += $entry
}

$manifest = [ordered]@{
    schema     = 'lvsd-manifest/v1'
    project    = $projectFull
    target     = $TargetName
    build_spec = $BuildSpecName
    labview_version = $lvVersion
    labview_bitness = $lvBitness
    labview_path = $LabVIEWPath
    port_number = $PortNumber
    repo_commit = $repoCommit
    git_ref     = $repoRef
    vipb_path   = $vipbFull
    vipb_hash   = if ($vipbFull) { try { (Get-FileHash -Algorithm SHA256 -LiteralPath $vipbFull).Hash } catch { $null } }
    output_root = (if ($generated -and $generated.Count -gt 0) { Split-Path -Parent $generated[0] } else { $null })
    timestamp  = $timestamp
    cli        = $LabVIEWCLIPath
    exit_code  = $exit
    duration_ms= $durationMs
    log_paths  = @()
    status     = if ($exit -eq 0) { 'success' } else { 'failed' }
    outputs    = $outputs
    notes      = @()
}

# If a log file path exists, add it into manifest log_paths
if ($LogFilePath -and (Test-Path -LiteralPath $LogFilePath)) {
    $manifest.log_paths += (Resolve-Path -LiteralPath $LogFilePath).ProviderPath
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
Write-Host "[lvsd] Manifest written to $ManifestPath"

# Publish via log-stash if available
$stashScript = Join-Path $repoRoot 'scripts/log-stash/Write-LogStashEntry.ps1'
if (Test-Path -LiteralPath $stashScript -PathType Leaf) {
    try {
        $status = if ($exit -eq 0) { 'success' } else { 'failed' }
        $attachments = @($ManifestPath) + $generated
        $logPaths = @()
        if ($LogFilePath -and (Test-Path -LiteralPath $LogFilePath)) { $logPaths += $LogFilePath }
        & $stashScript `
            -RepositoryPath $repoRoot `
            -Category 'lvsd' `
            -Label $BuildSpecName `
            -LogPaths $logPaths `
            -AttachmentPaths $attachments `
            -Status $status `
            -ProducerScript $PSCommandPath `
            -ProducerArgs @{ ProjectPath = $projectFull; BuildSpecName = $BuildSpecName; LabVIEWVersion = $lvVersion; LabVIEWBitness = $lvBitness; RepoCommit = $repoCommit; GitRef = $repoRef } `
            -StartedAtUtc $start.ToUniversalTime() `
            -DurationMs $durationMs | Out-Null
    } catch {
        Write-Warning "[lvsd] Failed to write log-stash bundle: $($_.Exception.Message)"
    }
}

if ($exit -ne 0) {
    Write-Error "[lvsd] LabVIEWCLI exited with code $exit"
    exit $exit
}

Write-Host "[lvsd] Source distribution build completed."
