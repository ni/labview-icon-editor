<#
.SYNOPSIS
    Updates a VIPB file's display information and builds the VI package.

.DESCRIPTION
    Resolves paths, merges version details into DisplayInformation JSON, and
    calls vipm CLI to build the final VI package.

.PARAMETER SupportedBitness
    LabVIEW bitness for the build ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to update.

.PARAMETER Package_LabVIEW_Version
    Minimum LabVIEW version supported by the package.

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (0 or 3).

.PARAMETER Major
    Major version component for the package.

.PARAMETER Minor
    Minor version component for the package.

.PARAMETER Patch
    Patch version component for the package.

.PARAMETER Build
    Build number component for the package.

.PARAMETER Commit
    Commit identifier embedded in the package metadata.

.PARAMETER ReleaseNotesFile
    Path to a release notes file injected into the build.

.PARAMETER DisplayInformationJSON
    JSON string representing the VIPB display information to update.

.EXAMPLE
    .\build_vip.ps1 -SupportedBitness "64" -RepositoryPath "C:\repo" -VIPBPath "Tooling\deployment\seed.vipb" -Package_LabVIEW_Version 2021 -LabVIEWMinorRevision 3 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>

param (
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [string]$VIPBPath,

    [Alias('MinimumSupportedLVVersion')]
    [int]$Package_LabVIEW_Version,

    [ValidateSet("0","3")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [switch]$Simulate,
    [switch]$SkipPPLCheck,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON
)

# 1) Resolve paths
try {
    $ResolvedRepositoryPath = Resolve-Path -Path $RepositoryPath -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($VIPBPath)) {
        $ResolvedVIPBPath = $null
    }
    elseif ([System.IO.Path]::IsPathRooted($VIPBPath)) {
        $ResolvedVIPBPath = Resolve-Path -Path $VIPBPath -ErrorAction Stop
    }
    else {
        $ResolvedVIPBPath = Join-Path -Path $ResolvedRepositoryPath -ChildPath $VIPBPath -ErrorAction Stop
    }

    # If the resolved path points to a directory (e.g., empty input), treat it as unset so we trigger discovery
    if ($ResolvedVIPBPath -and (Test-Path -LiteralPath $ResolvedVIPBPath)) {
        $item = Get-Item -LiteralPath $ResolvedVIPBPath -ErrorAction SilentlyContinue
        if ($item -and $item.PSIsContainer) {
            $ResolvedVIPBPath = $null
        }
    }

    Write-Verbose "RepositoryPath resolved to $ResolvedRepositoryPath"
    if ($ResolvedVIPBPath) {
        Write-Verbose "VIPBPath resolved to $ResolvedVIPBPath"
    }
    if ($Commit) {
        Write-Verbose "Embedding commit metadata: $Commit" -Verbose:$VerbosePreference
    }
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving paths. Ensure RepositoryPath and VIPBPath are valid."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# If VIPBPath is unset/invalid, attempt to auto-discover the single .vipb in the repo
if (-not $ResolvedVIPBPath -or -not (Test-Path -LiteralPath $ResolvedVIPBPath)) {
    $candidates = @(Get-ChildItem -Path $ResolvedRepositoryPath -Filter *.vipb -File -Recurse)
    if (-not $candidates -or $candidates.Count -eq 0) {
        Write-Error ("VIPB not found{0} and no .vipb files discovered under {1}." -f (if ($ResolvedVIPBPath) { " at '$ResolvedVIPBPath'" } else { "" }), $ResolvedRepositoryPath)
        exit 1
    }
    if ($candidates.Count -gt 1) {
        Write-Error ("VIPB not found{0} and multiple .vipb files discovered: {1}. Specify vipb_path explicitly." -f (if ($ResolvedVIPBPath) { " at '$ResolvedVIPBPath'" } else { "" }), ($candidates | ForEach-Object { $_.FullName } -join '; '))
        exit 1
    }
    $ResolvedVIPBPath = $candidates[0].FullName
    Write-Verbose ("Auto-discovered VIPB at {0}" -f $ResolvedVIPBPath)
}

# 2) Create release notes if needed and resolve the paths
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Information "Release notes file '$ReleaseNotesFile' does not exist. Creating it..." -InformationAction Continue
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

try {
    $ResolvedReleaseNotesFile = Resolve-Path -Path $ReleaseNotesFile -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving ReleaseNotesFile. Ensure the path exists and is accessible."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 3a) Ensure build log directory exists for troubleshooting
$LogDirectory = Join-Path -Path $ResolvedRepositoryPath -ChildPath "builds/logs"
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

# 3b) Preflight VIPB structure and staged PPLs before invoking vipm to avoid opaque parser errors/timeouts
try {
    [xml]$vipbXml = Get-Content -LiteralPath $ResolvedVIPBPath -Raw
}
catch {
    Write-Error ("Failed to load VIPB XML at {0}: {1}" -f $ResolvedVIPBPath, $_.Exception.Message)
    exit 1
}

if (-not $vipbXml.VI_Package_Builder_Settings -or -not $vipbXml.VI_Package_Builder_Settings.Library_General_Settings) {
    Write-Error ("VIPB is missing VI_Package_Builder_Settings/Library_General_Settings: {0}" -f $ResolvedVIPBPath)
    exit 1
}

$pkgLvFromVipb = [string]$vipbXml.VI_Package_Builder_Settings.Library_General_Settings.Package_LabVIEW_Version
if ([string]::IsNullOrWhiteSpace($pkgLvFromVipb)) {
    Write-Error ("VIPB missing Package_LabVIEW_Version: {0}" -f $ResolvedVIPBPath)
    exit 1
}
Write-Information ("VIPB preflight: path={0}; length={1}; md5={2}; Package_LV_Version={3}" -f $ResolvedVIPBPath, (Get-Item -LiteralPath $ResolvedVIPBPath).Length, (Get-FileHash -LiteralPath $ResolvedVIPBPath -Algorithm MD5).Hash, $pkgLvFromVipb) -InformationAction Continue

# Ensure staged PPL variants exist so the post-install selector can work
$pplDir    = Join-Path $ResolvedRepositoryPath 'resource\plugins'
$pplNeutral = Join-Path $pplDir 'lv_icon.lvlibp'
$pplWin64   = Join-Path $pplDir 'lv_icon.lvlibp.windows_x64'
$pplWin86   = Join-Path $pplDir 'lv_icon.lvlibp.windows_x86'
$pplVipb64  = Join-Path $pplDir 'lv_icon_x64.lvlibp'
$pplVipb86  = Join-Path $pplDir 'lv_icon_x86.lvlibp'

function Restore-MissingPpls {
    param(
        [string[]]$Targets,
        [string]$SearchRoot
    )

    # Allow equivalents (e.g., windows_x64 vs vipb x64). Prefer the source path if present.
    $aliases = @{
        ($pplVipb64) = $pplWin64
        ($pplVipb86) = $pplWin86
    }

    $allCandidates = Get-ChildItem -Path $SearchRoot -Filter 'lv_icon.lvlibp*' -File -Recurse -ErrorAction SilentlyContinue
    foreach ($target in $Targets) {
        if (Test-Path -LiteralPath $target) { continue }
        $leaf = Split-Path -Leaf $target
        $match = $allCandidates | Where-Object { $_.Name -ieq $leaf } | Select-Object -First 1
        if ($match) {
            $destDir = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $match.FullName -Destination $target -Force
            Write-Information ("Restored missing PPL {0} from {1}" -f $leaf, $match.FullName) -InformationAction Continue
        }
    }

    # If VIPB-style names are missing but windows_* exist, copy them into place
    foreach ($alias in $aliases.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $alias.Key) -and (Test-Path -LiteralPath $alias.Value)) {
            Copy-Item -LiteralPath $alias.Value -Destination $alias.Key -Force
            Write-Information ("Hydrated expected VIPB PPL name {0} from {1}" -f $alias.Key, $alias.Value) -InformationAction Continue
        }
    }
}

function Ensure-VipHasEntries {
    param(
        [Parameter(Mandatory=$true)]
        [string]$VipPath,
        [Parameter(Mandatory=$true)]
        [string[]]$RequiredEntries,
        [Parameter(Mandatory=$true)]
        [string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $VipPath -PathType Leaf)) {
        throw ("VIP path not found for content validation: {0}" -f $VipPath)
    }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    }
    catch {
        throw ("Unable to load compression assembly for VIP validation: {0}" -f $_.Exception.Message)
    }

    # Attempt to add missing entries from the staged repo before failing.
    $zip = [System.IO.Compression.ZipFile]::Open($VipPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $existing = $zip.Entries | ForEach-Object { $_.FullName.ToLowerInvariant() }
        $missing = $RequiredEntries | Where-Object { -not ($existing -contains $_.ToLowerInvariant()) }

        foreach ($entry in $missing) {
            $sourcePath = Join-Path $RepoRoot $entry
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                continue
            }

            # Normalize entry path to use forward slashes inside the zip
            $zipEntryName = $entry -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $sourcePath, $zipEntryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            Write-Information ("Injected missing entry into VIP: {0}" -f $zipEntryName) -InformationAction Continue
        }
    }
    finally {
        $zip.Dispose()
    }

    # Re-open to validate final set
    $zip = [System.IO.Compression.ZipFile]::OpenRead($VipPath)
    try {
        $finalEntries = $zip.Entries | ForEach-Object { $_.FullName.ToLowerInvariant() }
    }
    finally {
        $zip.Dispose()
    }

    $stillMissing = @($RequiredEntries | Where-Object { -not ($finalEntries -contains $_.ToLowerInvariant()) })
    if ($stillMissing.Count -gt 0) {
        throw ("Built VIP missing expected entries after injection attempt: {0}" -f ($stillMissing -join '; '))
    }

    Write-Information ("VIP content validation passed for {0}" -f $VipPath) -InformationAction Continue
}

if (-not $SkipPPLCheck) {
    $required = @($pplNeutral, $pplWin64, $pplWin86)
    $missingPpl = @()
    foreach ($candidate in $required) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            $missingPpl += $candidate
        }
    }

    if ($missingPpl.Count -gt 0) {
        Restore-MissingPpls -Targets $missingPpl -SearchRoot $ResolvedRepositoryPath
        $missingPpl = @()
        foreach ($candidate in $required) {
            if (-not (Test-Path -LiteralPath $candidate)) {
                $missingPpl += $candidate
            }
        }
    }

    # Hydrate VIPB-expected filenames from windows_* copies when possible
    foreach ($alias in @($pplVipb64, $pplVipb86)) {
        if (-not (Test-Path -LiteralPath $alias)) {
            $source = if ($alias -eq $pplVipb64) { $pplWin64 } else { $pplWin86 }
            if (Test-Path -LiteralPath $source) {
                Copy-Item -LiteralPath $source -Destination $alias -Force
                Write-Information ("Hydrated {0} from {1}" -f $alias, $source) -InformationAction Continue
            } else {
                $missingPpl += $alias
            }
        }
    }

    if ($missingPpl.Count -gt 0) {
        Write-Error ("Missing staged PPL(s) required for post-install selection: {0}" -f ($missingPpl -join '; '))
        exit 1
    }
} else {
    Write-Host "Skipping staged PPL presence check (SkipPPLCheck enabled)." -ForegroundColor Yellow
}

# 3c) Preflight custom-action VIs referenced by VIPB (fail fast if missing)
$vipbDir = Split-Path -Parent $ResolvedVIPBPath
$customActionsDir = Join-Path $vipbDir 'custom-actions'
$expectedCustomActions = @(
    'VIP_Pre-Install Custom Action.vi',
    'VIP_Post-Install Custom Action.vi',
    'VIP_Pre-Uninstall Custom Action.vi',
    'VIP_Post-Uninstall Custom Action.vi'
)
$missingActions = @()
foreach ($ca in $expectedCustomActions) {
    $candidate = Join-Path $customActionsDir $ca
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $missingActions += $candidate
    }
}
Write-Information ("Custom-action folder: {0}" -f $customActionsDir) -InformationAction Continue
Write-Information ("Custom-action files present: {0}/{1}" -f ($expectedCustomActions.Count - $missingActions.Count), $expectedCustomActions.Count) -InformationAction Continue
if ($missingActions.Count -gt 0) {
    Write-Error ("VIPM custom-action VI(s) missing: {0}. Ensure they exist relative to the VIPB at {1}" -f ($missingActions -join '; '), $customActionsDir)
    exit 1
}

# Pre-compute commit/output paths so we can clear stale artifacts before the build
$commitKey = if ([string]::IsNullOrWhiteSpace($Commit)) { "manual" } else { $Commit }
$outputDir = Join-Path -Path $ResolvedRepositoryPath -ChildPath ("builds/vip-stash/{0}" -f $commitKey)
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$staleVips = Get-ChildItem -Path $outputDir -Filter *.vip -File -ErrorAction SilentlyContinue
if ($staleVips) {
    $staleList = ($staleVips | ForEach-Object { $_.Name }) -join ', '
    Write-Information ("Cleaning stale VIP(s) before build from {0}: {1}" -f $outputDir, $staleList) -InformationAction Continue
    $staleVips | Remove-Item -Force -ErrorAction SilentlyContinue
}
else {
    Write-Information ("VIP output dir ready (no existing .vip): {0}" -f $outputDir) -InformationAction Continue
}

# 3) Resolve LabVIEW version from VIPB to ensure determinism, overriding any inbound value
$versionScriptCandidates = @(
    (Join-Path $ResolvedRepositoryPath 'scripts/get-package-lv-version.ps1'),
    (Join-Path $ResolvedRepositoryPath '.github/scripts/get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\scripts\get-package-lv-version.ps1')
) | Where-Object { Test-Path $_ }

if (-not $versionScriptCandidates) {
    $errorObject = [PSCustomObject]@{
        error = "Unable to locate get-package-lv-version.ps1 relative to repository or action path."
        repo  = $ResolvedRepositoryPath
        action= $PSScriptRoot
    }
    $errorObject | ConvertTo-Json -Depth 6
    exit 1
}

$versionScript = $versionScriptCandidates | Select-Object -First 1
$Package_LabVIEW_Version = & $versionScript -RepositoryPath $RepositoryPath

# Calculate the LabVIEW version string
$lvNumericMajor    = $Package_LabVIEW_Version - 2000
$lvNumericVersion  = "$($lvNumericMajor).$LabVIEWMinorRevision"
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
}
else {
    $VIP_LVVersion_A = $lvNumericVersion
}
Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# 4) Parse and update the DisplayInformationJSON
try {
    $jsonObj = $DisplayInformationJSON | ConvertFrom-Json
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Failed to parse DisplayInformationJSON into valid JSON."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# If "Package Version" doesn't exist, create it as a subobject
if (-not $jsonObj.'Package Version') {
    $jsonObj | Add-Member -MemberType NoteProperty -Name 'Package Version' -Value ([PSCustomObject]@{
        major = $Major
        minor = $Minor
        patch = $Patch
        build = $Build
    })
}
else {
    # "Package Version" exists, so just overwrite its fields
    $jsonObj.'Package Version'.major = $Major
    $jsonObj.'Package Version'.minor = $Minor
    $jsonObj.'Package Version'.patch = $Patch
    $jsonObj.'Package Version'.build = $Build
}

# 5) Resolve vipm executable and execute the build with retries and log capture
$vipmExecutable = $null
$envVipmPath = [Environment]::GetEnvironmentVariable('VIPM_PATH')
if ($envVipmPath -and (Test-Path -LiteralPath $envVipmPath -PathType Leaf)) {
    $vipmExecutable = (Resolve-Path -LiteralPath $envVipmPath).Path
} elseif ($envVipmPath) {
    Write-Verbose ("VIPM_PATH is set but did not resolve to a file: {0}" -f $envVipmPath)
}

if (-not $vipmExecutable) {
    $vipmCli = Get-Command vipm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vipmCli) {
        $vipmExecutable = $vipmCli.Path
    }
}

if (-not $vipmExecutable) {
    Write-Error "vipm CLI is not available (PATH and VIPM_PATH were checked); cannot build the VI package."
    exit 1
}

$vipmArgs = @(
    "build",
    "--labview-version", $Package_LabVIEW_Version.ToString(),
    "--labview-bitness", $SupportedBitness,
    $ResolvedVIPBPath
)

$prettyCommand = ('"{0}" {1}' -f $vipmExecutable, ($vipmArgs -join ' '))
Write-Output "Using vipm executable: $vipmExecutable"
Write-Output "Base build command:"
Write-Output $prettyCommand

if ($Simulate) {
    Write-Host "Simulate mode enabled: skipping vipm build. Preflight passed, would run command above." -ForegroundColor Yellow
    exit 0
}

$logFile = Join-Path -Path $LogDirectory -ChildPath "vipm-build-attempt-1.log"
Write-Information "Starting vipm build. Log: $logFile" -InformationAction Continue

try {
    & $vipmExecutable @vipmArgs 2>&1 | Tee-Object -FilePath $logFile
}
catch {
    $_ | Out-String | Tee-Object -FilePath $logFile -Append | Out-Null
    $LASTEXITCODE = 1
}

# Ensure the log file exists even if vipm/tee didn't create it (for downstream artifact collection)
if (-not (Test-Path -LiteralPath $logFile)) {
    "vipm build completed but no log was emitted by vipm." | Set-Content -LiteralPath $logFile -Encoding UTF8
}

if ($LASTEXITCODE -ne 0) {
    if (Test-Path $logFile) {
        Write-Information ("---- vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
        Get-Content -Path $logFile -Tail 20 | ForEach-Object { Write-Information $_ -InformationAction Continue }
        Write-Information ("---- end vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
    }
    else {
        Write-Warning ("vipm build log not found at {0}" -f $logFile)
    }

    $errorObject = [PSCustomObject]@{
        error    = "vipm build failed."
        exitCode = $LASTEXITCODE
        logs     = @($logFile)
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}
Write-Information ("VIPM log saved at {0}" -f $logFile) -InformationAction Continue

# Move or confirm the produced VIP is under builds/vip-stash for downstream steps
function Find-ProducedVip {
    $vip = Get-ChildItem -Path $outputDir -Filter *.vip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $vip) {
        $vip = Get-ChildItem -Path $vipbDir -Filter *.vip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $vip) {
        $fallbackRoot = Join-Path $ResolvedRepositoryPath 'builds'
        $vip = Get-ChildItem -Path $fallbackRoot -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($vip) {
            Write-Information ("Found VIP outside expected path (possible path mismatch): {0}" -f $vip.FullName) -InformationAction Continue
        }
    }
    return $vip
}

$vipPath = $null
$vipProduced = Find-ProducedVip
if ($vipProduced) {
    if ($vipProduced.DirectoryName -ne $outputDir.TrimEnd('\','/')) {
        $destPath = Join-Path -Path $outputDir -ChildPath $vipProduced.Name
        Move-Item -LiteralPath $vipProduced.FullName -Destination $destPath -Force
        Write-Information ("Relocated built VIP to {0}" -f $destPath) -InformationAction Continue
        $vipPath = $destPath
    }
    else {
        $vipPath = $vipProduced.FullName
        Write-Information ("Built VIP located at {0}" -f $vipPath) -InformationAction Continue
    }
}
elseif (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    Write-Error ("vipm reported success but the output dir was not created: {0}. Check vipm log: {1}" -f $outputDir, $logFile)
    if (Test-Path $logFile) {
        Write-Information ("---- vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
        Get-Content -Path $logFile -Tail 20 | ForEach-Object { Write-Information $_ -InformationAction Continue }
        Write-Information ("---- end vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
    }
    exit 1
}

if (-not $vipProduced -or -not $vipPath -or -not (Test-Path -LiteralPath $vipPath)) {
    $fallbackRoot = Join-Path $ResolvedRepositoryPath 'builds'
    $otherVips = Get-ChildItem -Path $fallbackRoot -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    $otherList = if ($otherVips) { ($otherVips | ForEach-Object { $_.FullName }) -join '; ' } else { '(none found)' }
    Write-Error ("vipm reported success but no .vip was found in expected locations (path mismatch). Searched: {0} and {1}. Sample VIPs under builds/: {2}. Check vipm log: {3}" -f $outputDir, $vipbDir, $otherList, $logFile)
    if (Test-Path $logFile) {
        Write-Information ("---- vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
        Get-Content -Path $logFile -Tail 20 | ForEach-Object { Write-Information $_ -InformationAction Continue }
        Write-Information ("---- end vipm build log tail ({0}) ----" -f $logFile) -InformationAction Continue
    }
    exit 1
}

$expectedEntries = @(
    'resource/plugins/lv_icon.lvlibp',
    'resource/plugins/lv_icon.lvlibp.windows_x64',
    'resource/plugins/lv_icon.lvlibp.windows_x86'
)
Ensure-VipHasEntries -VipPath $vipPath -RequiredEntries $expectedEntries -RepoRoot $ResolvedRepositoryPath
try {
    $vipHash = Get-FileHash -LiteralPath $vipPath -Algorithm SHA256
    $vipSize = (Get-Item -LiteralPath $vipPath).Length
    Write-Information ("VIP ready: {0} (size={1} bytes, sha256={2})" -f $vipPath, $vipSize, $vipHash.Hash) -InformationAction Continue
}
catch {
    Write-Verbose ("Unable to hash built VIP at {0}: {1}" -f $vipPath, $_.Exception.Message)
}

Write-Information "Successfully built VI package." -InformationAction Continue
