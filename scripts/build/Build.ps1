<#
.SYNOPSIS
  This script automates the build process for the LabVIEW Icon Editor project.
  It performs the following tasks:
    1. Cleans up old .lvlibp files in the plugins folder.
    2. Builds the LabVIEW library (32-bit and 64-bit).
    3. Closes LabVIEW (32-bit and 64-bit).
    4. Renames the built files.
    5. Builds the VI package (64-bit) with DisplayInformationJSON fields.
    6. Closes LabVIEW (64-bit).

  Dependencies are no longer applied during build; run the "01 Verify / Apply dependencies" task before building if VIPC packages need to be refreshed.

  Example usage:
    .\Build.ps1 `
      -RepositoryPath "C:\release\labview-icon-editor-fork" `
      -Major 1 -Minor 0 -Patch 0 -Build 3 -Commit "Placeholder" `
      -CompanyName "Acme Corporation" `
      -AuthorName "John Doe (Acme Corp)" `
      -Verbose
#>

[CmdletBinding()]  # Enables -Verbose, -Debug, etc.
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [int]$Major = 1,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 1,
    [string]$Commit,
    # LabVIEW "minor" revision (0 or 3)
    [Parameter(Mandatory = $false)]
    [int]$LabVIEWMinorRevision = 3,

    [ValidateSet('both','64','32')]
    [string]$LvlibpBitness = 'both',

[string]$VIPBPath = 'Tooling\deployment\seed.vipb',

    # New parameters that will populate the JSON fields
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

[Parameter(Mandatory = $true)]
[string]$AuthorName,

    [string]$ProductHomepageUrl,

    # Auto-disable color/progress in CI (e.g., GitHub Actions) to keep logs clean
    [switch]$ForcePlainOutput,

    # When true (default for non-CI), prompt the user to acknowledge any first-launch LabVIEW/VIPM dialog.
    [switch]$PromptForVipmReady,

    # Determinism and host expectation knobs
    [int]$BuildNumberOverride,
    [switch]$SkipReleaseNotes,
    [string]$ReleaseNotesRef,
    [string]$ExpectedVipmVersion,
    [string]$ExpectedLabVIEWPath32,
    [string]$ExpectedLabVIEWPath64,
    [switch]$AssertLabVIEWPaths
)
$global:LASTEXITCODE = 0
trap {
    $pos = '(no invocation info)'
    if ($_.InvocationInfo) { $pos = $_.InvocationInfo.PositionMessage }
    Write-Host ("Invocation info: {0}" -f $pos)
    throw
}

$ReleaseNotesFile = Join-Path $RepositoryPath 'Tooling\deployment\release_notes.md'
$helpersPath = Join-Path $RepositoryPath 'scripts/build-helpers.psm1'
$metaUtilsPath = Join-Path $RepositoryPath 'scripts/build-meta-utils.psm1'
if (-not (Test-Path -LiteralPath $helpersPath)) {
    Write-Error "Helper module not found at $helpersPath"
    exit 1
}
Import-Module -Name $helpersPath -Force
if (-not (Test-Path -LiteralPath $metaUtilsPath)) {
    Write-Error "Metadata helper module not found at $metaUtilsPath"
    exit 1
}
Import-Module -Name $metaUtilsPath -Force

# Derive LabVIEW version/bitness from the repo metadata and ensure dev mode is bound to this repo/worktree.
function Resolve-LabVIEWVersionFromVipb {
    param([string]$RepoPath)
    $script = Join-Path $RepoPath 'scripts/get-package-lv-version.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Unable to locate get-package-lv-version.ps1 under $RepoPath"
    }
    $ver = & $script -RepositoryPath $RepoPath
    if (-not $ver) { throw "Failed to resolve LabVIEW version from VIPB under $RepoPath" }
    return $ver
}

function Resolve-LabVIEWBitnessFromVipb {
    param([string]$RepoPath)
    $script = Join-Path $RepoPath 'scripts/get-package-lv-bitness.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Unable to locate get-package-lv-bitness.ps1 under $RepoPath"
    }
    $bit = & $script -RepositoryPath $RepoPath
    if (-not $bit) { throw "Failed to resolve LabVIEW bitness from VIPB under $RepoPath" }
    if ($bit -eq 'both') { $bit = '64' } # single-bitness flow: default to 64-bit
    return $bit
}

function Assert-DevModeTokenForRepo {
    param(
        [string]$RepoPath,
        [string]$LvVersion,
        [string]$Bitness
    )
    $pf64 = ${env:ProgramFiles}
    $pf32 = ${env:ProgramFiles(x86)}
    $iniCandidates = @()
    if ($Bitness -eq '32') {
        if ($pf32) { $iniCandidates += (Join-Path $pf32 "National Instruments\LabVIEW $LvVersion\LabVIEW.ini") }
        if ($pf64) { $iniCandidates += (Join-Path $pf64 "National Instruments\LabVIEW $LvVersion (32-bit)\LabVIEW.ini") }
    }
    else {
        if ($pf64) { $iniCandidates += (Join-Path $pf64 "National Instruments\LabVIEW $LvVersion\LabVIEW.ini") }
    }

    $repoFull = (Resolve-Path -LiteralPath $RepoPath).Path.TrimEnd('\','/')
    foreach ($ini in $iniCandidates) {
        if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { continue }
        try {
            $lines = Get-Content -LiteralPath $ini -ErrorAction Stop
            $entry = $lines | Where-Object { $_ -match '^\s*LocalHost\.LibraryPaths\s*=' } | Select-Object -First 1
            if (-not $entry) { continue }
            $val = ($entry -split '=',2)[1].Trim().Trim('"')
            $paths = $val -split ';' | ForEach-Object { $_.Trim().Trim('"') }
            foreach ($p in $paths) {
                try {
                    $norm = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path.TrimEnd('\','/')
                    if ($norm -eq $repoFull) { return }
                }
                catch {
                    if ($p -eq $RepoPath) { return }
                }
            }
        }
        catch { }
    }

    throw ("Dev-mode token not found for {0}-bit LabVIEW {1} pointing to {2}. Run task '06 DevMode: Bind (auto)' first, then rerun the build." -f $Bitness, $LvVersion, $repoFull)
}

$commitKey = $null
function Resolve-CommitKey {
    param([string]$RepoPath,[string]$CommitParam)
    $key = $CommitParam
    if ([string]::IsNullOrWhiteSpace($key) -or $key -eq 'manual') {
        try {
            Push-Location -LiteralPath $RepoPath
            $key = (git rev-parse --short HEAD).Trim()
        }
        catch {
            throw "Cannot resolve commit identifier; provide -Commit or ensure git is available."
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
        }
    }
    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "Commit identifier is required; cannot proceed without a commit key."
    }
    return $key
}

$isCi = ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true' -or $ForcePlainOutput)
if ($isCi) {
    try { $PSStyle.OutputRendering = 'PlainText' } catch { }
    $ProgressPreference = 'SilentlyContinue'
    $env:NO_COLOR = '1'
    $env:CLICOLOR = '0'
}

$hasStyle = (-not $isCi) -and ($PSStyle -ne $null)
$bitnessPalette = @{}
$bitnessPalette['32'] = ''
if ($hasStyle) { $bitnessPalette['32'] = $PSStyle.Foreground.BrightCyan }
$bitnessPalette['64'] = ''
if ($hasStyle) { $bitnessPalette['64'] = $PSStyle.Foreground.BrightMagenta }

# Verify dev-mode token matches this repo/worktree for the VIPB-declared version/bitness.
$resolvedLvVersion = Resolve-LabVIEWVersionFromVipb -RepoPath $RepositoryPath
$resolvedBitness = Resolve-LabVIEWBitnessFromVipb -RepoPath $RepositoryPath
Assert-DevModeTokenForRepo -RepoPath $RepositoryPath -LvVersion $resolvedLvVersion -Bitness $resolvedBitness

$stagePalette = @{}
$stagePalette['devmode'] = ''
if ($hasStyle) { $stagePalette['devmode'] = $PSStyle.Foreground.BrightCyan }
$stagePalette['close'] = ''
if ($hasStyle) { $stagePalette['close'] = $PSStyle.Foreground.BrightMagenta }
$stagePalette['build'] = ''
if ($hasStyle) { $stagePalette['build'] = $PSStyle.Foreground.BrightGreen }
$recapDevModeOk = $false
$recapPplOk = $false
$recapVipmOk = $false
$recapVipPath = $null
$recapVipReason = $null
$resetColor = ''
if ($hasStyle) { $resetColor = $PSStyle.Reset }
$script:LogTimer = $null
$script:LastLogElapsed = [TimeSpan]::Zero

function New-LogPrefix {
    param([string]$Label = $null)
    if (-not $script:LogTimer) {
        if ($Label) { return "[${Label}] " } else { return '' }
    }
    $elapsed = $script:LogTimer.Elapsed
    $delta = $elapsed - $script:LastLogElapsed
    $script:LastLogElapsed = $elapsed
    if ($Label) {
        return ("[{0}][(T+{1:F3}s Δ+{2:N0}ms)] " -f $Label, $elapsed.TotalSeconds, $delta.TotalMilliseconds)
    }
    return ("[(T+{0:F3}s Δ+{1:N0}ms)] " -f $elapsed.TotalSeconds, $delta.TotalMilliseconds)
}
function Show-BitnessBanner {
    param([string]$Arch)
    $color = $bitnessPalette[$Arch]
    $prefix = New-LogPrefix 'build'
    Write-Host ("{0}{1}==== {2}-bit build phase ===={3}" -f $prefix, $color, $Arch, $resetColor)
}

function Show-BitnessDone {
    param([string]$Arch)
    $color = $bitnessPalette[$Arch]
    $prefix = New-LogPrefix 'build'
    Write-Host ("{0}{1}---- {2}-bit phase complete ----{3}" -f $prefix, $color, $Arch, $resetColor)
}

function Write-Stage {
    param(
        [string]$Label,
        [ValidateSet('devmode','close','build')]
        [string]$StageKey = 'build'
    )
    $color = $stagePalette[$StageKey]
    $line = "=" * 78
    $prefix = New-LogPrefix 'build'
    $now = Get-Date
    $elapsed = 0
    if ($script:BuildStart) { $elapsed = ($now - $script:BuildStart).TotalSeconds }
    $banner = "[STAGE] $Label (t +{0:n1}s)" -f $elapsed
    if ($hasStyle -and $color) {
        Write-Host ($color + $prefix + $line + $resetColor)
        Write-Host ($color + $prefix + $banner + $resetColor)
        Write-Host ($color + $prefix + $line + $resetColor)
    }
    else {
        Write-Host ($prefix + $line)
        Write-Host ($prefix + $banner)
        Write-Host ($prefix + $line)
    }
}

# Structured step logger with timestamp/elapsed and optional color
function Write-Step {
    param(
        [string]$Step,
        [string]$Message,
        [string]$Color,
        [string]$Symbol = '→'
    )
    $now = Get-Date
    $ts = $now.ToString("HH:mm:ss")
    $elapsed = 0
    if ($script:BuildStart) { $elapsed = ($now - $script:BuildStart).TotalSeconds }
    $elapsedPretty = "{0:n1}" -f $elapsed
    $icon = ''
    if (-not [string]::IsNullOrWhiteSpace($Symbol)) { $icon = "[$Symbol] " }
    $prefix = "[STEP $Step $ts +${elapsedPretty}s] $icon"
    if ($hasStyle -and $Color) {
        Write-Host "$prefix $Message" -ForegroundColor $Color
    }
    else {
        Write-Host "$prefix $Message"
    }
}

# Snapshot g-cli/LabVIEW ancestry so developers can see which LabVIEW instance is active
function Show-GCliLabVIEWTree {
    param([string]$Label = "Process snapshot")
    try {
        $procs = Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name,CommandLine
    }
    catch {
        Write-Warning ("[proc] {0}: unable to read process list ({1})" -f $Label, $_.Exception.Message)
        return
    }

    $byPid = @{}
    foreach ($p in $procs) { $byPid[[string]$p.ProcessId] = $p }
    $targets = $procs | Where-Object { $_.Name -match 'g-cli|LabVIEW' }
    if (-not $targets) {
        Write-Host ("[proc] {0}: no g-cli or LabVIEW processes found." -f $Label)
        return
    }

    foreach ($t in ($targets | Select-Object -First 3)) {
        Write-Host ("[proc] {0}: Target {1} ({2})" -f $Label, $t.Name, $t.ProcessId)
        $chain = @()
        $current = [string]$t.ProcessId
        while ($byPid.ContainsKey($current)) {
            $p = $byPid[$current]
            $chain += $p
            $parentKey = [string]$p.ParentProcessId
            if ($p.ParentProcessId -eq 0 -or -not $byPid.ContainsKey($parentKey)) { break }
            $current = $parentKey
        }
        [array]::Reverse($chain)
        $indent = 0
        foreach ($item in $chain) {
            $cmd = $item.CommandLine
            if ($cmd -and $cmd.Length -gt 140) { $cmd = $cmd.Substring(0,140) + ' ...' }
            $lvYear = $null
            if ($item.Name -like 'LabVIEW*' -and $cmd) {
                $m = [regex]::Match($cmd, 'LabVIEW\\s+(?<year>\\d{4})')
                if ($m.Success) { $lvYear = $m.Groups['year'].Value }
            }
            $suffix = ""
            if ($lvYear) { $suffix = " LV=$lvYear" }
            $prefix = ' ' * $indent
            Write-Host ("{0}{1} ({2}) PPID={3}{4} {5}" -f $prefix, $item.Name, $item.ProcessId, $item.ParentProcessId, $suffix, $cmd)
            $indent += 2
        }
    }
    if ($targets.Count -gt 3) {
        Write-Host ("[proc] {0}: ... {1} more target(s) suppressed" -f $Label, ($targets.Count - 3))
    }
}

$dotnetCli = Get-Command dotnet -ErrorAction SilentlyContinue
function Get-XCliProjectPath {
    param([string]$RepoPath)
    $proj = Join-Path $RepoPath 'Tooling/x-cli/src/XCli/XCli.csproj'
    if (Test-Path -LiteralPath $proj -PathType Leaf) {
        return $proj
    }
    return $null
}

function Invoke-XCliCommand {
    param(
        [string]$Project,
        [string[]]$PayloadArgs,
        [string]$WorkingDirectory
    )
    if (-not $dotnetCli -or -not (Test-Path -LiteralPath $Project)) {
        return $null
    }
    $oldEnv = $env:XCLI_ALLOW_PROCESS_START
    $env:XCLI_ALLOW_PROCESS_START = '1'
    try {
        $payload = if ($PayloadArgs) { $PayloadArgs } else { @() }
        $fullArgs = @("run", "--project", $Project, "--") + $payload
        Write-Verbose ("x-cli: dotnet {0}" -f ($fullArgs -join ' '))
        $output = & $dotnetCli.Source @fullArgs 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output
        }
    }
    finally {
        $env:XCLI_ALLOW_PROCESS_START = $oldEnv
    }
}

function Invoke-DevModeBindWithXcli {
    param(
        [string]$RepoPath,
        [int]$LvVersion,
        [string]$Bitness
    )

    $proj = Get-XCliProjectPath -RepoPath $RepoPath
    if (-not $proj) { return $null }

    $programFiles = if ($Bitness -eq '64') { $env:ProgramFiles } else { ${env:ProgramFiles(x86)} }
    $iniPath = if ($programFiles) { Join-Path $programFiles ("National Instruments\LabVIEW {0}\LabVIEW.ini" -f $LvVersion) } else { $null }
    if (-not $iniPath -or -not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
        Write-Verbose ("x-cli devmode: LabVIEW.ini not found for {0}-bit {1} at expected path; skipping x-cli binder." -f $Bitness, $LvVersion)
        return $null
    }

    # If the required path isn't already present, let the PowerShell binder perform the initial bind.
    try {
        $iniLines = Get-Content -LiteralPath $iniPath -ErrorAction Stop
        $entry = $iniLines | Where-Object { $_ -match '^\\s*LocalHost\\.LibraryPaths\\s*=' }
        $hasRequired = $false
        if ($entry) {
            $value = ($entry -split '=',2)[1]
            $paths = $value -split ';' | ForEach-Object { $_.Trim().Trim('"') }
            $hasRequired = $paths | Where-Object { $_ -eq $RepoPath } | ForEach-Object { $true } | Select-Object -First 1
        }
        if (-not $hasRequired) {
            Write-Verbose ("x-cli devmode: LocalHost.LibraryPaths does not yet contain repo path; using PowerShell binder for {0}-bit." -f $Bitness)
            return $null
        }
    }
    catch {
        Write-Verbose ("x-cli devmode: unable to read LabVIEW.ini to validate LocalHost.LibraryPaths ({0}); skipping x-cli binder." -f $_.Exception.Message)
        return $null
    }

    $oldIni = $env:XCLI_LABVIEW_INI_PATH
    $oldRequired = $env:XCLI_LOCALHOST_REQUIRED_PATH
    $env:XCLI_LABVIEW_INI_PATH = $iniPath
    $env:XCLI_LOCALHOST_REQUIRED_PATH = $RepoPath
    $args = @(
        "labview-devmode-enable",
        "--lvaddon-root", $RepoPath,
        "--lv-version", [string]$LvVersion,
        "--bitness", $Bitness,
        "--operation", "bind",
        "--args-json", '["force"]'
    )
    try {
        return Invoke-XCliCommand -Project $proj -PayloadArgs $args -WorkingDirectory $RepoPath
    }
    finally {
        $env:XCLI_LABVIEW_INI_PATH = $oldIni
        $env:XCLI_LOCALHOST_REQUIRED_PATH = $oldRequired
    }
}

function Resolve-VipbPath {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$VipbPath
    )

    $base = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).ProviderPath

    if (-not [string]::IsNullOrWhiteSpace($VipbPath)) {
        $candidate = $VipbPath
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path -Path $base -ChildPath $candidate
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
        }
        Write-Verbose ("VIPBPath provided but not found at {0}; falling back to discovery." -f $candidate)
    }

    $vipbs = Get-ChildItem -Path $base -Filter *.vipb -File -Recurse
    if (-not $vipbs -or $vipbs.Count -eq 0) {
        throw "No .vipb file found under $base"
    }
    if ($vipbs.Count -gt 1) {
        throw ("Multiple .vipb files found; specify -VIPBPath to disambiguate. Candidates: {0}" -f (($vipbs | Select-Object -ExpandProperty FullName) -join '; '))
    }
    return $vipbs[0].FullName
}

function Invoke-PplBuildWithXcli {
    param(
        [string]$RepoPath,
        [int]$LvVersion,
        [string]$Bitness,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build,
        [string]$Commit
    )

    $proj = Get-XCliProjectPath -RepoPath $RepoPath
    if (-not $proj) { return $null }

    $reqDir = Join-Path $RepoPath 'builds\logs'
    if (-not (Test-Path -LiteralPath $reqDir)) {
        New-Item -ItemType Directory -Path $reqDir -Force | Out-Null
    }
    $reqPath = Join-Path $reqDir ("xcli-ppl-request-{0}.json" -f $Bitness)
    $request = [pscustomobject]@{
        RepoRoot                 = $RepoPath
        IconEditorRoot           = $RepoPath
        MinimumSupportedLVVersion = $LvVersion
        Major                    = $Major
        Minor                    = $Minor
        Patch                    = $Patch
        Build                    = $Build
        Commit                   = $Commit
        BitnessTargets           = @($Bitness)
    }
    $request | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reqPath -Encoding utf8

    $result = Invoke-XCliCommand -Project $proj -PayloadArgs @('ppl-build', '--request', $reqPath) -WorkingDirectory $RepoPath
    return $result
}

function Get-StashManifest {
    param(
        [string]$StashDir,
        [string]$Type
    )

    if ([string]::IsNullOrWhiteSpace($StashDir)) { return $null }
    $manifestPath = Join-Path $StashDir 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { return $null }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning ("Failed to read stash manifest at {0}: {1}" -f $manifestPath, $_.Exception.Message)
        return $null
    }

    if ($Type -and $manifest.type -and ($manifest.type -ne $Type)) {
        return $null
    }

    return $manifest
}

function Write-StashManifest {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)]$Content
    )

    try {
        $Content | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
    }
    catch {
        Write-Warning ("Failed to write stash manifest at {0}: {1}" -f $ManifestPath, $_.Exception.Message)
    }
}

function Test-PplStashCompatibility {
    param(
        $Manifest,
        [string]$CommitKey,
        [string]$LvVersion,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build
    )

    if (-not $Manifest -or $Manifest.type -ne 'ppl') { return $false }

    $version = $Manifest.version
    $matchesVersion = $version -and
        $version.major -eq $Major -and
        $version.minor -eq $Minor -and
        $version.patch -eq $Patch -and
        $version.build -eq $Build

    return ($Manifest.commit -eq $CommitKey) -and
        ($Manifest.labviewVersion -eq $LvVersion) -and
        $matchesVersion
}

function Sync-PplStashManifest {
    param(
        [string]$StashDir,
        [string]$CommitKey,
        [string]$LvVersion,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build
    )

    if (-not (Test-Path -LiteralPath $StashDir)) { return }

    $artifacts = @()
    $ppl32 = Join-Path $StashDir 'lv_icon_x86.lvlibp'
    $ppl64 = Join-Path $StashDir 'lv_icon_x64.lvlibp'
    if (Test-Path -LiteralPath $ppl32) {
        $artifacts += [pscustomobject]@{ bitness = '32'; file = (Split-Path -Leaf $ppl32) }
    }
    if (Test-Path -LiteralPath $ppl64) {
        $artifacts += [pscustomobject]@{ bitness = '64'; file = (Split-Path -Leaf $ppl64) }
    }

    $manifest = [pscustomobject]@{
        type           = 'ppl'
        commit         = $CommitKey
        labviewVersion = "$LvVersion"
        version        = [pscustomobject]@{
            major = $Major
            minor = $Minor
            patch = $Patch
            build = $Build
        }
        artifacts      = $artifacts
        timestampUtc   = (Get-Date).ToUniversalTime().ToString("o")
    }

    $manifestPath = Join-Path $StashDir 'manifest.json'
    Write-StashManifest -ManifestPath $manifestPath -Content $manifest
}

function Test-VipStashCompatibility {
    param(
        $Manifest,
        [string]$CommitKey,
        [string]$LvVersion,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build
    )

    if (-not $Manifest -or $Manifest.type -ne 'vip') { return $false }

    $version = $Manifest.version
    $matchesVersion = $version -and
        $version.major -eq $Major -and
        $version.minor -eq $Minor -and
        $version.patch -eq $Patch -and
        $version.build -eq $Build

    return ($Manifest.commit -eq $CommitKey) -and
        ($Manifest.labviewVersion -eq $LvVersion) -and
        $matchesVersion
}

function Sync-VipStashManifest {
    param(
        [string]$StashDir,
        [string]$CommitKey,
        [string]$LvVersion,
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build,
        [string]$VipFileName
    )

    if (-not (Test-Path -LiteralPath $StashDir)) { return }

    $manifest = [pscustomobject]@{
        type           = 'vip'
        commit         = $CommitKey
        labviewVersion = "$LvVersion"
        version        = [pscustomobject]@{
            major = $Major
            minor = $Minor
            patch = $Patch
            build = $Build
        }
        vipFile        = $VipFileName
        timestampUtc   = (Get-Date).ToUniversalTime().ToString("o")
    }

    $manifestPath = Join-Path $StashDir 'manifest.json'
    Write-StashManifest -ManifestPath $manifestPath -Content $manifest
}

function Close-LabVIEWSafe {
    param(
        [string]$LvVer,
        [ValidateSet('32','64')][string]$Bitness,
        [int]$TimeoutSec = 20
    )

    $label = "LabVIEW $LvVer ($Bitness-bit)"
    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        Write-Warning ("[proc] {0}: g-cli.exe not found; skipping graceful close." -f $label)
        return $false
    }

    $gcliArgs = @("--lv-ver", $LvVer, "--arch", $Bitness, "QuitLabVIEW")
    Write-Information ("[proc] closing {0} via g-cli: {1}" -f $label, ($gcliArgs -join ' ')) -InformationAction Continue
    $output   = & g-cli @gcliArgs 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Information $_ -InformationAction Continue }

    function Get-LabVIEWProcs {
        param([string]$LvVer,[string]$Bitness)

        $programFilesPattern = '*Program Files (x86)*'
        if ($Bitness -eq '64') { $programFilesPattern = '*Program Files*' }
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $path = $null
            try { $path = $_.MainModule.FileName } catch { $path = $null }
            if (-not $path) { return $false }
            $_.ProcessName -like 'LabVIEW*' -and
            $path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $LvVer) -and
            $path -like $programFilesPattern
        }
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $closed = $false
    do {
        $procs = Get-LabVIEWProcs -LvVer $LvVer -Bitness $Bitness
        if (-not $procs) { $closed = $true; break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $closed) {
        Write-Warning ("[proc] {0}: still running after {1}s; force-terminating." -f $label, $TimeoutSec)
        Stop-LabVIEWForBitness -Bitness $Bitness -LvVer $LvVer
        Start-Sleep -Seconds 2
        $procs = Get-LabVIEWProcs -LvVer $LvVer -Bitness $Bitness
        $closed = -not $procs
    }

    return $closed
}

# Helper function to verify a file/folder path exists
function Test-PathExistence {
    param(
        [string]$Path,
        [string]$Description
    )
    Write-Verbose "Checking if '$Description' exists at path: $Path"
    if (-not (Test-Path -Path $Path)) {
        Write-Error "The '$Description' does not exist: $Path"
        exit 1
    }
    Write-Verbose "Confirmed '$Description' exists at path: $Path"
}

# Helper function to run another script with arguments safely
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [hashtable]$ArgumentMap,
        [string[]]$ArgumentList,
        [int]$TimeoutSec = 0,
        [string]$DisplayName
    )
    if (-not $ScriptPath) { throw "ScriptPath is required" }
    if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "ScriptPath '$ScriptPath' not found" }

    $label = Split-Path -Leaf $ScriptPath
    if (-not [string]::IsNullOrWhiteSpace($DisplayName)) { $label = $DisplayName }
    $render = $null
    if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("[cmd] {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if ($TimeoutSec -gt 0) {
            $job = Start-Job -ScriptBlock {
                param($p,$argMap,$argList,$useMap)
                if ($useMap) { & $p @argMap } elseif ($argList) { & $p @argList } else { & $p }
                [pscustomobject]@{ ExitCode = $LASTEXITCODE }
            } -ArgumentList @($ScriptPath,$ArgumentMap,$ArgumentList, [bool]$ArgumentMap)
            if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
                # Stop-Job in PowerShell Core doesn't support -Force; Stop then remove explicitly
                Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
                Receive-Job $job -Keep | ForEach-Object { Write-Host $_ }
                Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
                throw ("{0} timed out after {1} seconds (possible UI prompt or hang)." -f $label, $TimeoutSec)
            }
            $output = Receive-Job $job -Wait -AutoRemoveJob
            $exitObj = $output | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties['ExitCode'] }
            ($output | Where-Object { -not ($_ -is [pscustomobject]) }) | ForEach-Object { Write-Host $_ }
            $exitCode = 0
            if ($exitObj) { $exitCode = $exitObj.ExitCode }
            if ($exitCode -ne 0) {
                throw ("{0} failed with exit code {1}" -f $label, $exitCode)
            }
        }
        else {
            if ($ArgumentMap) {
                & $ScriptPath @ArgumentMap
            } elseif ($ArgumentList) {
                & $ScriptPath @ArgumentList
            } else {
                & $ScriptPath
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $render. Exit code: $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        }
    }
    catch {
        Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $render. Exiting. Details: $($_.Exception.Message)"
        exit 1
    }
    finally {
        $timer.Stop()
        Write-Verbose ("{0} completed in {1:n1}s" -f $label, $timer.Elapsed.TotalSeconds)
    }
}

function Assert-ExpectedPPLSet {
    param(
        [string]$PluginsDir,
        [string[]]$ExpectedNames
    )

    if (-not (Test-Path -LiteralPath $PluginsDir)) {
        throw "Plugins folder not found at $PluginsDir"
    }

    # Match the base, suffixed, and staged copies (e.g., lv_icon.lvlibp.windows_x64)
    $files = Get-ChildItem -LiteralPath $PluginsDir -Filter '*.lvlibp*' -File -ErrorAction SilentlyContinue
    $names = $files | ForEach-Object { $_.Name }

    $missing = @($ExpectedNames | Where-Object { $names -notcontains $_ })
    $extra   = @($names | Where-Object { $ExpectedNames -notcontains $_ })

    if ($missing.Count -gt 0) {
        throw ("Expected PPL(s) missing from {0}: {1}" -f $PluginsDir, ($missing -join ', '))
    }
    if ($extra.Count -gt 0) {
        throw ("Unexpected PPL(s) present in {0}: {1}" -f $PluginsDir, ($extra -join ', '))
    }

    Write-Information "PPL set validated: $($ExpectedNames -join ', ')" -InformationAction Continue
    foreach ($f in $files | Sort-Object Name) {
        try {
            $hash = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256
            Write-Information ("PPL {0} SHA256={1}" -f $f.Name, $hash.Hash) -InformationAction Continue
        }
        catch {
            Write-Warning ("Could not hash {0}: {1}" -f $f.FullName, $_.Exception.Message)
        }
    }
}

function Ensure-VipmReady {
    param(
        [switch]$Interactive
    )

    try {
        $ver = & vipm --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $ver) {
            Write-Information ("vipm version: {0}" -f ($ver -join ' ')) -InformationAction Continue
            return
        }
    }
    catch {
        # fall through to interactive flow
    }

    if (-not $Interactive) {
        throw "vipm CLI did not respond; rerun with -PromptForVipmReady (or outside CI) to acknowledge any LabVIEW prompt and retry."
    }

    Write-Warning "vipm CLI did not respond; launching 'vipm --version' to surface any LabVIEW dialog."
    try {
        $proc = Start-Process -FilePath "vipm" -ArgumentList "--version" -PassThru -WindowStyle Normal
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Warning ("Failed to start vipm --version interactively: {0}" -f $_.Exception.Message)
    }

    Write-Host ""
    Write-Host "=== ACTION REQUIRED ======================================================"
    Write-Host "If LabVIEW shows a dialog (first-launch), acknowledge it now."
    Write-Host "Then press Enter here to retry vipm --version."
    Write-Host "=========================================================================="
    [void][Console]::ReadLine()

    $ver = & vipm --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $ver) {
        throw "vipm CLI still not responding after user acknowledgment. Resolve the LabVIEW/VIPM prompt and retry."
    }

    Write-Information ("vipm version: {0}" -f ($ver -join ' ')) -InformationAction Continue
}

function Assert-VipmVersion {
    param(
        [string]$Expected
    )
    if ([string]::IsNullOrWhiteSpace($Expected)) { return }
    try {
        $ver = & vipm --version 2>&1
        if ($LASTEXITCODE -ne 0 -or -not $ver) {
            throw "vipm --version failed with exit code $LASTEXITCODE"
        }
        $actual = ($ver -join ' ').Trim()
        if ($actual -notlike "*$Expected*") {
            throw ("vipm version mismatch. Expected substring '{0}', got '{1}'." -f $Expected, $actual)
        }
        Write-Information ("vipm version matches expected '{0}'." -f $Expected) -InformationAction Continue
    }
    catch {
        throw ("vipm version check failed: {0}" -f $_.Exception.Message)
    }
}

function Assert-LabVIEWPath {
    param(
        [Parameter(Mandatory)][string]$LvVersion,
        [Parameter(Mandatory)][string]$Bitness,
        [string]$PathOverride
    )

    if ($Bitness -eq '32') {
        $defaultPath = "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.exe"
    }
    else {
        $defaultPath = "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.exe"
    }

    $candidate = $defaultPath
    if ($PathOverride) { $candidate = $PathOverride }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw ("LabVIEW {0}-bit executable not found at '{1}'. Set ExpectedLabVIEWPath{0} or install LabVIEW {2} for {0}-bit." -f $Bitness, $candidate, $LvVersion)
    }
    Write-Information ("Validated LabVIEW {0}-bit at {1}" -f $Bitness, $candidate) -InformationAction Continue
}

# Deprecated: vipm list sanity checks were noisy and have been removed.
function Assert-VipmAccess { }

function Ensure-LibraryPathsReady {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Bitness,
        [Parameter(Mandatory)][string]$DevModeScript
    )

    $readPaths = Join-Path $RepoPath 'scripts/read-library-paths.ps1'
    if (-not (Test-Path -LiteralPath $readPaths)) {
        Write-Verbose "read-library-paths.ps1 not found at $readPaths; skipping library path preflight." -Verbose
        return
    }
    if (-not (Test-Path -LiteralPath $DevModeScript)) {
        Write-Verbose "Set_Development_Mode.ps1 not found at $DevModeScript; skipping auto dev-mode remediation." -Verbose
        return
    }

    $testArgs = @{
        RepositoryPath   = $RepoPath
        SupportedBitness = $Bitness
        FailOnMissing    = $true
    }

    $TestPaths = {
        & $readPaths @testArgs
        return $LASTEXITCODE -eq 0
    }

    $ok = & $TestPaths
    if ($ok) { return }

    Write-Information ("LocalHost.LibraryPaths missing for {0}-bit; running Set_Development_Mode to populate INI tokens..." -f $Bitness) -InformationAction Continue
    Invoke-ScriptSafe -ScriptPath $DevModeScript -ArgumentMap @{
        RepositoryPath   = $RepoPath
        SupportedBitness = $Bitness
    } -DisplayName ("Set Development Mode ({0}-bit)" -f $Bitness)

    $ok = & $TestPaths
    if (-not $ok) {
        throw ("LocalHost.LibraryPaths still missing after Set_Development_Mode for {0}-bit. Check LabVIEW.ini and rerun." -f $Bitness)
    }
}

function Ensure-LibraryPathsAbsent {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Bitness,
        [Parameter(Mandatory)][string]$BindScript,
        [Parameter(Mandatory)][string]$LvVersion
    )

    if (-not (Test-Path -LiteralPath $BindScript)) {
        Write-Verbose "BindDevelopmentMode.ps1 not found at $BindScript; cannot manage LocalHost.LibraryPaths before dependency apply." -Verbose
        return
    }

    $iniPath = if ($Bitness -eq '64') {
        "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
    } else {
        "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
    }

    if (-not (Test-Path -LiteralPath $iniPath)) {
        Write-Verbose "LabVIEW ini not found for {0}-bit at {1}; skipping token check." -f $Bitness, $iniPath -Verbose
        return
    }

    $lines = Get-Content -LiteralPath $iniPath -ErrorAction SilentlyContinue
    if (-not $lines) { $lines = @() }
    $entries = @($lines | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d*=' })
    $entryCount = @($entries).Count
    if ($entryCount -eq 0) {
        # None present; fine to proceed
        return
    }

    # If existing entries already point at this repo, keep them (stage 1 handles binding)
    $repoFull = [System.IO.Path]::GetFullPath($RepoPath)
    $entryTargets = @()
    foreach ($e in @($entries)) {
        $split = $e -split '=', 2
        if ($split.Count -lt 2) { continue }
        try {
            $entryTargets += [System.IO.Path]::GetFullPath($split[1].Trim())
        }
        catch {
            $entryTargets += $split[1].Trim()
        }
    }
    $entryTargetsArr = @($entryTargets)
    $allMatchRepo = $entryTargetsArr.Count -gt 0 -and (@($entryTargetsArr | Where-Object {
        -not [string]::Equals($_, $repoFull, [System.StringComparison]::OrdinalIgnoreCase)
    })).Count -eq 0
    if ($allMatchRepo) {
        Write-Verbose "LocalHost.LibraryPaths already targets $repoFull for $Bitness-bit; skipping unbind before dependency apply."
        return
    }

    # Entries present (any path) -> unbind this bitness to enforce NONE before dependency apply
    Invoke-ScriptSafe -ScriptPath $BindScript -ArgumentMap @{
        RepositoryPath = $RepoPath
        Mode           = 'unbind'
        Bitness        = $Bitness
        Force          = $true
    } -DisplayName ("Dev mode unbind ({0}-bit)" -f $Bitness)

    $lines = Get-Content -LiteralPath $iniPath -ErrorAction SilentlyContinue
    $entries = @($lines | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d*=' })
    if (@($entries).Count -gt 0) {
        throw ("LocalHost.LibraryPaths still present for {0}-bit after unbind; cannot apply dependencies while token exists." -f $Bitness)
    }
}

function Write-ReleaseNotesFromGit {
    param(
        [string]$RepoPath,
        [string]$DestinationPath,
        [string]$RefSpec
    )

    if ($RefSpec) {
        $range = $RefSpec
        $header = "Release Notes (ref: $RefSpec)"
    }
    else {
        $lastTag = $null
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $lastTag = git -C $RepoPath describe --tags --abbrev=0 2>$null
            }
            catch {
                $lastTag = $null
            }
        }
        if (-not $lastTag) {
            $range  = 'HEAD'
            $header = 'Release Notes'
        }
        else {
            $range  = "$lastTag..HEAD"
            $header = "Release Notes (since $lastTag)"
        }
    }

    $log = if (Get-Command git -ErrorAction SilentlyContinue) {
        git -C $RepoPath log $range --pretty='- %h %s' --no-merges
    } else { $null }

    if (-not $log) {
        $log = "No commits found for $range."
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Verbose "git not found; skipping release notes generation from git."
        return
    }

    $body = "$header`n`n$log`n"
    $destDir = Split-Path -Path $DestinationPath -Parent
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Set-Content -Path $DestinationPath -Value $body -Encoding utf8
    Write-Information "Generated release notes from git into $DestinationPath" -InformationAction Continue
}

function Get-LabVIEWVersionFromVipb {
    param([Parameter(Mandatory)][string]$RootPath)
    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) { throw "No .vipb file found under $RootPath" }
    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) { throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)" }
    $raw = $match.Groups['ver'].Value
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) { throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)" }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    $computed = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $computed
}

try {
    Write-Host ('-' * 80)
    Write-Host "-- Build start"
    Write-Host ('-' * 80)
    Write-Verbose "Script: Build.ps1 starting."
    Write-Verbose "Parameters received:"
    Write-Verbose " - RepositoryPath: $RepositoryPath"
    Write-Verbose " - Major: $Major"
    Write-Verbose " - Minor: $Minor"
    Write-Verbose " - Patch: $Patch"
    Write-Verbose " - Build: $Build"
    Write-Verbose " - Commit: $Commit"
    Write-Verbose " - LabVIEWMinorRevision: $LabVIEWMinorRevision"
    Write-Verbose " - LvlibpBitness: $LvlibpBitness"
    Write-Verbose " - CompanyName: $CompanyName"
    Write-Verbose " - AuthorName: $AuthorName"

    # Track build start for elapsed logging
    $script:BuildStart = Get-Date
    $script:BuildStatus = 'success'

    # Begin transcript to capture console output
    $transcriptStarted = $false
    try {
        $logDir = Join-Path $RepositoryPath 'builds/logs'
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $logFile = Join-Path $logDir ("build-{0:yyyyMMdd-HHmmss}.log" -f $script:BuildStart)
        Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
        Write-Information ("Transcript logging enabled at {0}" -f $logFile) -InformationAction Continue
    }
    catch {
        Write-Warning ("Failed to start transcript logging: {0}" -f $_.Exception.Message)
    }

    # Ensure the repo root exists before reading the VIPB version
    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        Write-Error "RepositoryPath does not exist: $RepositoryPath"
        exit 1
    }

    $vipmCommand = Get-Command vipm -ErrorAction SilentlyContinue
    $vipmAvailable = [bool]$vipmCommand
    if (-not $vipmAvailable) {
        Write-Warning "vipm CLI not found on PATH; dependency task will fail and the build will skip VIPM packaging (lvlibp still builds)."
    }
    else {
        if (-not $PSBoundParameters.ContainsKey('PromptForVipmReady')) {
            $PromptForVipmReady = -not $env:CI -and -not $env:GITHUB_ACTIONS
        }
        Ensure-VipmReady -Interactive:$PromptForVipmReady
    }

    # Derive build number from total commits when available
    $envBuildOverride = $env:BUILD_NUMBER_OVERRIDE
    $buildOverrideValue = $BuildNumberOverride
    if (-not $buildOverrideValue -and $envBuildOverride) {
        [int]::TryParse($envBuildOverride, [ref]$buildOverrideValue) | Out-Null
    }
    if ($buildOverrideValue) {
        $Build = $buildOverrideValue
        Write-Information ("Using provided build number override: {0}" -f $Build) -InformationAction Continue
    }
    else {
        try {
            $isShallowRepo = git -C $RepositoryPath rev-parse --is-shallow-repository 2>$null
            if ($LASTEXITCODE -eq 0 -and $isShallowRepo -and $isShallowRepo.Trim().ToLower() -eq 'true') {
                git -C $RepositoryPath fetch --unshallow --no-progress 2>$null | Out-Null
            }
        }
        catch {
            $global:LASTEXITCODE = 0
        }
        try {
            $commitCount = git -C $RepositoryPath rev-list --count HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $commitCount) {
                $Build = [int]$commitCount
                Write-Information ("Using commit count for build number: {0}" -f $Build) -InformationAction Continue
            }
        }
        catch {
            Write-Verbose "Commit count unavailable; using provided build number." -Verbose
            $global:LASTEXITCODE = 0
        }
    }

    # Derive LabVIEW version from VIPB as the first consumer step
    $lvVersion = Get-LabVIEWVersionOrFail -RepoPath $RepositoryPath
    Write-Information ("Using LabVIEW version from VIPB: {0}" -f $lvVersion) -InformationAction Continue

    # Host sanity checks
    if ($vipmAvailable) {
        $expectedVipm = if ($PSBoundParameters.ContainsKey('ExpectedVipmVersion')) { $ExpectedVipmVersion } else { $env:EXPECTED_VIPM_VERSION }
        Assert-VipmVersion -Expected $expectedVipm
    }
    $lvPath32 = if ($PSBoundParameters.ContainsKey('ExpectedLabVIEWPath32')) { $ExpectedLabVIEWPath32 } else { $env:EXPECTED_LABVIEW_PATH_32 }
    $lvPath64 = if ($PSBoundParameters.ContainsKey('ExpectedLabVIEWPath64')) { $ExpectedLabVIEWPath64 } else { $env:EXPECTED_LABVIEW_PATH_64 }
    $shouldAssertPaths = $AssertLabVIEWPaths -or $lvPath32 -or $lvPath64
    if ($shouldAssertPaths) {
        if ($LvlibpBitness -eq 'both') {
            Assert-LabVIEWPath -LvVersion $lvVersion -Bitness '32' -PathOverride $lvPath32
            Assert-LabVIEWPath -LvVersion $lvVersion -Bitness '64' -PathOverride $lvPath64
        }
        elseif ($LvlibpBitness -eq '64') {
            Assert-LabVIEWPath -LvVersion $lvVersion -Bitness '64' -PathOverride $lvPath64
        }
        else {
            Assert-LabVIEWPath -LvVersion $lvVersion -Bitness '32' -PathOverride $lvPath32
        }
    }

    if ($vipmAvailable) {
        if ($LvlibpBitness -eq 'both') {
            Assert-VipmAccess -LvMajor $lvVersion -Bitness '32'
        }
        Assert-VipmAccess -LvMajor $lvVersion -Bitness '64'
    }

    $companyResolved = Resolve-CompanyName -CompanyName $CompanyName -RepoPath $RepositoryPath
    Write-Information ("Using Company Name: {0}" -f $companyResolved) -InformationAction Continue
    $authorResolved = Resolve-AuthorName -AuthorName $AuthorName -RepoPath $RepositoryPath
    Write-Information ("Using Author Name: {0}" -f $authorResolved) -InformationAction Continue
    $homepageResolved = Resolve-ProductHomepageUrl -ProductHomepageUrl $ProductHomepageUrl -RepoPath $RepositoryPath -DefaultOwner 'ni'
    Write-Information ("Using Product Homepage (URL): {0}" -f $homepageResolved) -InformationAction Continue

    # Validate needed folders after version is known
    Test-PathExistence $RepositoryPath "RepositoryPath"
    Test-PathExistence "$RepositoryPath\resource\plugins" "Plugins folder"
    Test-PathExistence "$RepositoryPath\lv_icon_editor.lvproj" "LabVIEW project"

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Test-PathExistence $ActionsPath "Actions folder"
    $commitKey = Resolve-CommitKey -RepoPath $RepositoryPath -CommitParam $Commit
    $pplStashRootNew    = Join-Path $RepositoryPath 'builds\lvlibp-stash'
    $pplStashRootLegacy = Join-Path $RepositoryPath 'builds\ppl-stash'
    $pplStashDirNew     = Join-Path $pplStashRootNew $commitKey
    $pplStashDirLegacy  = Join-Path $pplStashRootLegacy $commitKey

    # Log canonical VIPC location; dependency apply is handled by a separate task.
    $vipcPath = $null
    try {
        $vipcPath = Get-CanonicalVipcPath -RepoPath $RepositoryPath
        Write-Verbose ("Found canonical VIPC (not auto-applied by build): {0}" -f $vipcPath)
    }
    catch {
        Write-Warning ("runner_dependencies.vipc not found; run the '01 Verify / Apply dependencies' task before building. Details: {0}" -f $_.Exception.Message)
    }
    $SetDevMode = Join-Path $RepositoryPath "scripts/set-development-mode/Set_Development_Mode.ps1"
    $BindDevMode = Join-Path $RepositoryPath "scripts/bind-development-mode/BindDevelopmentMode.ps1"
    $RunUnitTestsSingle = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"
    $ApplyVIPC = Join-Path $RepositoryPath "scripts/apply-vipc/ApplyVIPC.ps1"
    $MissingHelper = Join-Path $RepositoryPath "scripts/missing-in-project/Invoke-MissingInProjectCLI.ps1"
    $BuildLvlibp = Join-Path $ActionsPath "build-lvlibp/Build_lvlibp.ps1"
    $CloseLabVIEW = Join-Path $RepositoryPath "scripts/close-labview/Close_LabVIEW.ps1"
    $RenameFile = Join-Path $ActionsPath "rename-file/Rename-file.ps1"

    $do32 = ($LvlibpBitness -eq 'both' -or $LvlibpBitness -eq '32')
    $do64 = ($LvlibpBitness -eq 'both' -or $LvlibpBitness -eq '64')

    Write-Stage -Label "Stage 1: Bind development mode" -StageKey 'devmode'
    if ($do64) {
        Write-Step -Step "1.0" -Message "Bind development mode (64-bit)" -Color "Cyan"
        $bind64WithXcli = $false
        $bind64Result = Invoke-DevModeBindWithXcli -RepoPath $RepositoryPath -LvVersion $lvVersion -Bitness '64'
        if ($bind64Result) {
            if ($bind64Result.Output) { $bind64Result.Output | ForEach-Object { Write-Host "[x-cli][devmode][64] $_" } }
            if ($bind64Result.ExitCode -eq 0) {
                $bind64WithXcli = $true
            }
            else {
                Write-Warning ("x-cli labview-devmode-enable (64-bit) failed with exit {0}; falling back to BindDevelopmentMode.ps1" -f $bind64Result.ExitCode)
            }
        }
        if (-not $bind64WithXcli) {
            Invoke-ScriptSafe -ScriptPath $BindDevMode -ArgumentMap @{
                RepositoryPath = $RepositoryPath
                Mode           = 'bind'
                Bitness        = '64'
                Force          = $true
            } -DisplayName "Dev mode bind (64-bit)"
        }
    }
    if ($do32) {
        Write-Step -Step "1.1" -Message "Bind development mode (32-bit)" -Color "Cyan"
        $bind32WithXcli = $false
        $bind32Result = Invoke-DevModeBindWithXcli -RepoPath $RepositoryPath -LvVersion $lvVersion -Bitness '32'
        if ($bind32Result) {
            if ($bind32Result.Output) { $bind32Result.Output | ForEach-Object { Write-Host "[x-cli][devmode][32] $_" } }
            if ($bind32Result.ExitCode -eq 0) {
                $bind32WithXcli = $true
            }
            else {
                Write-Warning ("x-cli labview-devmode-enable (32-bit) failed with exit {0}; falling back to BindDevelopmentMode.ps1" -f $bind32Result.ExitCode)
            }
        }
        if (-not $bind32WithXcli) {
            Invoke-ScriptSafe -ScriptPath $BindDevMode -ArgumentMap @{
                RepositoryPath = $RepositoryPath
                Mode           = 'bind'
                Bitness        = '32'
                Force          = $true
            } -DisplayName "Dev mode bind (32-bit)"
        }
    }

    $recapDevModeOk = $true

    Write-Stage -Label "Stage 2: Close LabVIEW (clean slate)" -StageKey 'close'
    function Stop-LabVIEWForBitness {
        param([string]$Bitness,[string]$LvVer)
        try {
            $programFilesPattern = if ($Bitness -eq '64') { '*Program Files*' } else { '*Program Files (x86)*' }
            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
                $path = $null
                try { $path = $_.MainModule.FileName } catch { $path = $null }
                if (-not $path) { return $false }
                $_.ProcessName -like 'LabVIEW*' -and
                $path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $LvVer) -and
                $path -like $programFilesPattern
            }
            if ($procs) { $procs | Stop-Process -Force -ErrorAction SilentlyContinue }
        }
        catch { }
    }

    if ($do64) {
        Write-Step -Step "2.0" -Message "Close LabVIEW (64-bit)" -Color "Magenta"
        $lv64Closed = $false
        try {
            Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
                Package_LabVIEW_Version = $lvVersion
                SupportedBitness        = '64'
            } -TimeoutSec 45 -DisplayName "Close LabVIEW (stage 2 - 64-bit)"
            $lv64Closed = $true
        }
        catch {
            Write-Warning ("Close LabVIEW (64-bit) timed out; force-terminating LabVIEW {0} (64-bit) processes." -f $lvVersion)
            Stop-LabVIEWForBitness -Bitness '64' -LvVer $lvVersion
        }
        if ($lv64Closed) {
            Write-Step -Step "2.1" -Message ("LabVIEW {0} (64-bit) closed or not running" -f $lvVersion) -Color "Green" -Symbol "✓"
        }
        else {
            Write-Step -Step "2.1" -Message ("LabVIEW {0} (64-bit) force-terminated after timeout" -f $lvVersion) -Color "Yellow" -Symbol "!"
        }
    }
    if ($do32) {
        Write-Step -Step "2.2" -Message "Close LabVIEW (32-bit)" -Color "Magenta"
        $lv32Closed = $false
        try {
            Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
                Package_LabVIEW_Version = $lvVersion
                SupportedBitness        = '32'
            } -TimeoutSec 45 -DisplayName "Close LabVIEW (stage 2 - 32-bit)"
            $lv32Closed = $true
        }
        catch {
            Write-Warning ("Close LabVIEW (32-bit) timed out; force-terminating LabVIEW {0} (32-bit) processes." -f $lvVersion)
            Stop-LabVIEWForBitness -Bitness '32' -LvVer $lvVersion
        }
        if ($lv32Closed) {
            Write-Step -Step "2.3" -Message ("LabVIEW {0} (32-bit) closed or not running" -f $lvVersion) -Color "Green" -Symbol "✓"
        }
        else {
            Write-Step -Step "2.3" -Message ("LabVIEW {0} (32-bit) force-terminated after timeout" -f $lvVersion) -Color "Yellow" -Symbol "!"
        }
    }

    # Verify no LabVIEW instances are running before proceeding; force-kill if needed
    try {
        $preProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' }
    }
    catch {
        $preProcs = @()
    }
    if ($preProcs) {
        Write-Step -Step "2.4" -Message ("LabVIEW still running after close stage; waiting for exit (PIDs: {0})" -f ($preProcs.Id -join ', ')) -Color "Yellow"
        $deadline = (Get-Date).AddSeconds(6)
        do {
            Start-Sleep -Seconds 2
            try {
                $preProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' }
            } catch { $preProcs = @() }
        } while ($preProcs -and (Get-Date) -lt $deadline)
        if ($preProcs) {
            Write-Step -Step "2.5" -Message ("Force-terminating remaining LabVIEW process(es): {0}" -f ($preProcs.Id -join ', ')) -Color "Yellow" -Symbol "!"
            try {
                $preProcs | Stop-Process -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to force-terminate LabVIEW processes: {0}" -f $_.Exception.Message)
            }
            Start-Sleep -Seconds 2
            try {
                $preProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' }
            } catch { $preProcs = @() }
            if ($preProcs) {
                throw ("LabVIEW process(es) remain after force-terminate: {0}. Please close LabVIEW and retry." -f ($preProcs.Id -join ', '))
            }
            Write-Step -Step "2.6" -Message "LabVIEW not running after force-terminate" -Color "Green" -Symbol "✓"
        }
        else {
            Write-Step -Step "2.5" -Message "LabVIEW not running after close stage" -Color "Green" -Symbol "✓"
        }
    }
    else {
        Write-Step -Step "2.4" -Message "LabVIEW not running after close stage" -Color "Green" -Symbol "✓"
    }

    Write-Stage -Label "Stage 3: Build & package" -StageKey 'build'

    # 1) Clean up old .lvlibp in the plugins folder
    Write-Step -Step "3.0" -Message "Clean plugins folder" -Color "Cyan"
    Write-Information "Cleaning up old .lvlibp files in plugins folder..." -InformationAction Continue
    Write-Verbose "Looking for .lvlibp files in $($RepositoryPath)\resource\plugins..."
    try {
        $PluginFiles = @(Get-ChildItem -Path "$RepositoryPath\resource\plugins" -Filter '*.lvlibp' -ErrorAction Stop)
        if ($PluginFiles) {
            $pluginNames = $PluginFiles | ForEach-Object { $_.Name }
            Write-Verbose "Found $($PluginFiles.Count) file(s): $($pluginNames -join ', ')"
            $PluginFiles | Remove-Item -Force -Recurse -Confirm:$false
            Write-Information "Deleted .lvlibp files from plugins folder." -InformationAction Continue
        }
        else {
            Write-Information "No .lvlibp files found to delete." -InformationAction Continue
        }
    }
    catch {
        Write-Error "Error occurred while retrieving .lvlibp files: $($_.Exception.Message)"
        Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    }

    if ($do32) {
        # Ensure 64-bit LabVIEW is down before entering any 32-bit work
        try {
            $lv64pre = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' -and $_.Path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $lvVersion) -and $_.MainModule.FileName -like '*Program Files*' }
        }
        catch {
            $lv64pre = @()
        }
        if ($lv64pre) {
            Write-Step -Step "3.1" -Message ("64-bit LabVIEW {0} running before 32-bit phase; requesting exit and waiting (PIDs: {1})" -f $lvVersion, ($lv64pre.Id -join ', ')) -Color "Yellow"
            Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
                Package_LabVIEW_Version = $lvVersion
                SupportedBitness        = '64'
            } -TimeoutSec 2 -DisplayName "Close LabVIEW (pre-32-bit entry)"
            $deadline = (Get-Date).AddSeconds(2)
            do {
                Start-Sleep -Seconds 2
                try {
                    $lv64pre = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' -and $_.Path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $lvVersion) -and $_.MainModule.FileName -like '*Program Files*' }
                } catch { $lv64pre = @() }
            } while ($lv64pre -and (Get-Date) -lt $deadline)
            if ($lv64pre) {
                throw ("64-bit LabVIEW {0} process(es) remain before 32-bit phase after waiting 2s: {1}." -f $lvVersion, ($lv64pre.Id -join ', '))
            }
        }

        Show-BitnessBanner -Arch '32'
        Write-Information "Dependencies are expected to be applied beforehand (use the '01 Verify / Apply dependencies' task) before running the build." -InformationAction Continue
        Show-GCliLabVIEWTree -Label "pre PPL (32-bit)"

        # Build 32-bit PPL immediately after tests
        Write-Host ('-' * 80)
        Write-Host "-- 32-bit build"
        Write-Host ('-' * 80)
        Write-Step -Step "3.2" -Message "Build PPL (32-bit)" -Color "Green"
        $argsLvlibp32 = @{
            Package_LabVIEW_Version   = $lvVersion
            SupportedBitness          = '32'
            RepositoryPath            = $RepositoryPath
            Major                     = $Major
            Minor                     = $Minor
            Patch                     = $Patch
            Build                     = $Build
            Commit                    = $Commit
        }
        $ppl32WithXcli = $false
        $ppl32Result = Invoke-PplBuildWithXcli -RepoPath $RepositoryPath -LvVersion $lvVersion -Bitness '32' -Major $Major -Minor $Minor -Patch $Patch -Build $Build -Commit $Commit
        if ($ppl32Result) {
            if ($ppl32Result.Output) {
                $ppl32Result.Output | ForEach-Object { Write-Host "[x-cli][ppl-build][32] $_" }
            }
            if ($ppl32Result.ExitCode -eq 0) {
                $ppl32WithXcli = $true
            }
            else {
                Write-Warning ("x-cli ppl-build (32-bit) failed with exit {0}; falling back to PowerShell Build_lvlibp.ps1" -f $ppl32Result.ExitCode)
            }
        }
        if (-not $ppl32WithXcli) {
            Invoke-ScriptSafe -ScriptPath $BuildLvlibp -ArgumentMap $argsLvlibp32 -TimeoutSec 180 -DisplayName "Build icon PPL (32-bit)"
        }
        Show-GCliLabVIEWTree -Label "post PPL (32-bit)"

        Write-Verbose "Renaming .lvlibp file to lv_icon_x86.lvlibp..."
        Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
            CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
            NewFilename     = 'lv_icon_x86.lvlibp'
        }
        try {
            $pplStashDir = $pplStashDirNew
            if (-not (Test-Path -LiteralPath $pplStashDir)) {
                New-Item -ItemType Directory -Path $pplStashDir -Force | Out-Null
            }
            $pplStashPath = Join-Path $pplStashDir 'lv_icon_x86.lvlibp'
            Copy-Item -LiteralPath (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x86.lvlibp') -Destination $pplStashPath -Force
            Write-Information "Stashed lv_icon_x86.lvlibp to $pplStashDir" -InformationAction Continue
            Sync-PplStashManifest -StashDir $pplStashDir -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build

            if ($pplStashDirLegacy -and ($pplStashDirLegacy -ne $pplStashDir)) {
                if (-not (Test-Path -LiteralPath $pplStashDirLegacy)) {
                    New-Item -ItemType Directory -Path $pplStashDirLegacy -Force | Out-Null
                }
                Copy-Item -LiteralPath $pplStashPath -Destination (Join-Path $pplStashDirLegacy 'lv_icon_x86.lvlibp') -Force
                Sync-PplStashManifest -StashDir $pplStashDirLegacy -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build
                Write-Verbose ("Updated legacy ppl-stash at {0}" -f $pplStashDirLegacy)
            }
        }
        catch {
            Write-Warning ("Failed to stash lv_icon_x86.lvlibp: {0}" -f $_.Exception.Message)
        }
        Show-BitnessDone -Arch '32'
        Write-Information "[recap][build-x86] 32-bit phase complete (PPL built; tests skipped)" -InformationAction Continue
        if ($pplStashDir -and (Test-Path -LiteralPath (Join-Path $pplStashDir 'lv_icon_x86.lvlibp'))) {
            Write-Information ("[artifact] x86 PPL stash: {0}" -f (Join-Path $pplStashDir 'lv_icon_x86.lvlibp')) -InformationAction Continue
        }

        # Ensure 32-bit LabVIEW is closed before starting the 64-bit phase
        Write-Step -Step "3.3" -Message "Close LabVIEW (32-bit before 64-bit phase)" -Color "Magenta"
        Close-LabVIEWSafe -LvVer $lvVersion -Bitness '32' -TimeoutSec 10 | Out-Null
    }
    else {
        Write-Information "Skipping 32-bit build steps (LvlibpBitness=$LvlibpBitness)." -InformationAction Continue
    }

    if ($do64) {
        # Ensure 32-bit LabVIEW is down before running 64-bit build phase
        try {
            $lv32pre = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' -and $_.Path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $lvVersion) -and $_.MainModule.FileName -like '*Program Files (x86)*' }
        }
        catch {
            $lv32pre = @()
        }
        if ($lv32pre) {
            Write-Step -Step "3.4" -Message ("32-bit LabVIEW running before 64-bit phase; requesting exit and waiting (PIDs: {0})" -f ($lv32pre.Id -join ', ')) -Color "Yellow"
            Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
                Package_LabVIEW_Version = $lvVersion
                SupportedBitness        = '32'
            } -TimeoutSec 2 -DisplayName "Close LabVIEW (pre-64-bit build)"
            $deadline = (Get-Date).AddSeconds(2)
            do {
                Start-Sleep -Seconds 2
                try {
                    $lv32pre = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' -and $_.Path -like ("*LabVIEW {0}\\LabVIEW.exe*" -f $lvVersion) -and $_.MainModule.FileName -like '*Program Files (x86)*' }
                } catch { $lv32pre = @() }
            } while ($lv32pre -and (Get-Date) -lt $deadline)
            if ($lv32pre) {
                throw ("32-bit LabVIEW {0} process(es) remain before 64-bit phase after waiting 2s: {1}." -f $lvVersion, ($lv32pre.Id -join ', '))
            }
        }
        Write-Host ('-' * 80)
        Write-Host "-- 64-bit phase"
        Write-Host ('-' * 80)
        Show-BitnessBanner -Arch '64'
        Write-Information "Dependencies are expected to be applied beforehand (use the '01 Verify / Apply dependencies' task) before running the build." -InformationAction Continue

        # Build 64-bit PPL immediately after 64-bit tests
        Write-Host ('-' * 80)
        Write-Host "-- 64-bit build"
        Write-Host ('-' * 80)
        Show-GCliLabVIEWTree -Label "pre PPL (64-bit)"
        Write-Step -Step "3.5" -Message "Build PPL (64-bit)" -Color "Green"
        $argsLvlibp64 = @{
            Package_LabVIEW_Version   = $lvVersion
            SupportedBitness          = '64'
            RepositoryPath            = $RepositoryPath
            Major                     = $Major
            Minor                     = $Minor
            Patch                     = $Patch
            Build                     = $Build
            Commit                    = $Commit
        }
        $ppl64WithXcli = $false
        $ppl64Result = Invoke-PplBuildWithXcli -RepoPath $RepositoryPath -LvVersion $lvVersion -Bitness '64' -Major $Major -Minor $Minor -Patch $Patch -Build $Build -Commit $Commit
        if ($ppl64Result) {
            if ($ppl64Result.Output) {
                $ppl64Result.Output | ForEach-Object { Write-Host "[x-cli][ppl-build][64] $_" }
            }
            if ($ppl64Result.ExitCode -eq 0) {
                $ppl64WithXcli = $true
            }
            else {
                Write-Warning ("x-cli ppl-build (64-bit) failed with exit {0}; falling back to PowerShell Build_lvlibp.ps1" -f $ppl64Result.ExitCode)
            }
        }
        if (-not $ppl64WithXcli) {
            try {
                Invoke-ScriptSafe -ScriptPath $BuildLvlibp -ArgumentMap $argsLvlibp64 -TimeoutSec 180 -DisplayName "Build icon PPL (64-bit)"
            }
            catch {
                Write-Step -Step "3.6" -Message "Build icon PPL (64-bit) failed; retrying after forcing LabVIEW close..." -Color "Yellow"
                Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
                    Package_LabVIEW_Version = $lvVersion
                    SupportedBitness        = '64'
                } -TimeoutSec 2 -DisplayName "Close LabVIEW (retry 64-bit build)"
                Start-Sleep -Seconds 3
                Invoke-ScriptSafe -ScriptPath $BuildLvlibp -ArgumentMap $argsLvlibp64 -TimeoutSec 180 -DisplayName "Build icon PPL (64-bit retry)"
            }
        }
        Show-GCliLabVIEWTree -Label "post PPL (64-bit)"

        Write-Verbose "Renaming .lvlibp file to lv_icon_x64.lvlibp..."
        Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
            CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
            NewFilename     = 'lv_icon_x64.lvlibp'
        }
        try {
            $pplStashDir = $pplStashDirNew
            if (-not (Test-Path -LiteralPath $pplStashDir)) {
                New-Item -ItemType Directory -Path $pplStashDir -Force | Out-Null
            }
            $pplStashPath = Join-Path $pplStashDir 'lv_icon_x64.lvlibp'
            Copy-Item -LiteralPath (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x64.lvlibp') -Destination $pplStashPath -Force
            Write-Information "Stashed lv_icon_x64.lvlibp to $pplStashDir" -InformationAction Continue
            Sync-PplStashManifest -StashDir $pplStashDir -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build

            if ($pplStashDirLegacy -and ($pplStashDirLegacy -ne $pplStashDir)) {
                if (-not (Test-Path -LiteralPath $pplStashDirLegacy)) {
                    New-Item -ItemType Directory -Path $pplStashDirLegacy -Force | Out-Null
                }
                Copy-Item -LiteralPath $pplStashPath -Destination (Join-Path $pplStashDirLegacy 'lv_icon_x64.lvlibp') -Force
                Sync-PplStashManifest -StashDir $pplStashDirLegacy -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build
                Write-Verbose ("Updated legacy ppl-stash at {0}" -f $pplStashDirLegacy)
            }
        }
        catch {
            Write-Warning ("Failed to stash lv_icon_x64.lvlibp: {0}" -f $_.Exception.Message)
        }
        Show-BitnessDone -Arch '64'
        Write-Information "[recap][build-x64] 64-bit phase complete (PPL built; tests skipped)" -InformationAction Continue
        if ($pplStashDir -and (Test-Path -LiteralPath (Join-Path $pplStashDir 'lv_icon_x64.lvlibp'))) {
            Write-Information ("[artifact] x64 PPL stash: {0}" -f (Join-Path $pplStashDir 'lv_icon_x64.lvlibp')) -InformationAction Continue
        }
    }

    # 9) Final staging of neutral and suffixed PPLs after both builds
    try {
        $pplDir    = Join-Path $RepositoryPath 'resource\plugins'
        $pplX64    = Join-Path $pplDir 'lv_icon_x64.lvlibp'
        $pplX86    = Join-Path $pplDir 'lv_icon_x86.lvlibp'
        $neutral   = Join-Path $pplDir 'lv_icon.lvlibp'
        $win64Copy = Join-Path $pplDir 'lv_icon.lvlibp.windows_x64'
        $win86Copy = Join-Path $pplDir 'lv_icon.lvlibp.windows_x86'
        $pplStashDir  = $pplStashDirNew
        $pplManifest  = Get-StashManifest -StashDir $pplStashDir -Type 'ppl'
        if (-not $pplManifest -and (Test-Path -LiteralPath $pplStashDirLegacy)) {
            $legacyManifest = Get-StashManifest -StashDir $pplStashDirLegacy -Type 'ppl'
            if ($legacyManifest) {
                $pplManifest = $legacyManifest
                $pplStashDir = $pplStashDirLegacy
                Write-Verbose ("Using legacy ppl-stash at {0}" -f $pplStashDir)
            }
        }
        $pplX64Stash  = Join-Path $pplStashDir 'lv_icon_x64.lvlibp'
        $pplX86Stash  = Join-Path $pplStashDir 'lv_icon_x86.lvlibp'
        $canUsePplStash = Test-PplStashCompatibility -Manifest $pplManifest -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build
        if (-not $canUsePplStash -and (Test-Path -LiteralPath $pplStashDir)) {
            Write-Verbose ("PPL stash at {0} is not compatible with current build inputs; skipping restore." -f $pplStashDir)
        }

        if ($canUsePplStash -and -not (Test-Path -LiteralPath $pplX64) -and (Test-Path -LiteralPath $pplX64Stash)) {
            Copy-Item -LiteralPath $pplX64Stash -Destination $pplX64 -Force
            Write-Warning "Restored lv_icon_x64.lvlibp from stash before staging."
        }
        if ($canUsePplStash -and -not (Test-Path -LiteralPath $pplX86) -and (Test-Path -LiteralPath $pplX86Stash)) {
            Copy-Item -LiteralPath $pplX86Stash -Destination $pplX86 -Force
            Write-Warning "Restored lv_icon_x86.lvlibp from stash before staging."
        }

        Write-Step -Step "3.7" -Message "Stage neutral/windows PPLs" -Color "Green"
        if (Test-Path -LiteralPath $pplX64) {
            Copy-Item -LiteralPath $pplX64 -Destination $neutral -Force
            Copy-Item -LiteralPath $pplX64 -Destination $win64Copy -Force
            Write-Information "Staged neutral and windows_x64 PPLs at $pplDir" -InformationAction Continue
        }
        else {
            Write-Warning "x64 PPL not found at $pplX64; skipping neutral/windows_x64 staging."
        }

        if (Test-Path -LiteralPath $pplX86) {
            if (-not (Test-Path -LiteralPath $neutral)) {
                Copy-Item -LiteralPath $pplX86 -Destination $neutral -Force
                Write-Information "Staged neutral PPL from x86 build at $pplDir" -InformationAction Continue
            }
            Copy-Item -LiteralPath $pplX86 -Destination $win86Copy -Force
            Write-Information "Staged windows_x86 PPL at $pplDir" -InformationAction Continue
        }
        else {
            Write-Warning "x86 PPL not found at $pplX86; skipping windows_x86 staging."
        }
        $recapPplOk = $true
    }
    catch {
        Write-Warning "Failed to stage neutral/suffixed PPL copies: $($_.Exception.Message)"
    }

    # Remove temporary x86/x64-specific PPL files to keep the plugins folder idempotent for downstream checks
    try {
        $tempCopies = @()
        if (Test-Path -LiteralPath (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x64.lvlibp')) {
            $tempCopies += (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x64.lvlibp')
        }
        if ($do32 -and (Test-Path -LiteralPath (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x86.lvlibp'))) {
            $tempCopies += (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x86.lvlibp')
        }
        $removed = @()
        foreach ($tmp in $tempCopies) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction Stop
            $removed += (Split-Path $tmp -Leaf)
        }
        if ($removed.Count -gt 0) {
            $removedList = [string]::Join(', ', $removed)
            Write-Information ("Cleaned temporary PPL copies: {0}" -f $removedList) -InformationAction Continue
        }
    }
    catch {
        Write-Warning ("Failed to remove temporary PPL copies: {0}" -f $_.Exception.Message)
    }
    # Idempotency guard: validate expected PPL set and log hashes
    $expectedPpls = @('lv_icon.lvlibp')
    if ($do64) { $expectedPpls += 'lv_icon.lvlibp.windows_x64' }
    if ($do32) { $expectedPpls += 'lv_icon.lvlibp.windows_x86' }
    Assert-ExpectedPPLSet -PluginsDir (Join-Path $RepositoryPath 'resource\plugins') -ExpectedNames $expectedPpls

    # -------------------------------------------------------------------------
    # 8) Construct the JSON for "Company Name" & "Author Name", plus version
    # -------------------------------------------------------------------------
    # We include "Package Version" with your script parameters.
    # The rest of the fields remain empty or default as needed.
    Write-Verbose "Generating release notes from git..."
    if ($SkipReleaseNotes) {
        Set-Content -Path $ReleaseNotesFile -Value "Release notes generation skipped (SkipReleaseNotes flag)." -Encoding utf8
        Write-Information "Release notes generation skipped by flag." -InformationAction Continue
    }
    else {
        Write-Step -Step "3.8" -Message "Generate release notes" -Color "Cyan"
        Write-ReleaseNotesFromGit -RepoPath $RepositoryPath -DestinationPath $ReleaseNotesFile -RefSpec $ReleaseNotesRef
    }

    $jsonObject = @{
        "Package Version" = @{
            "major" = $Major
            "minor" = $Minor
            "patch" = $Patch
            "build" = $Build
        }
        "Product Name"                    = "LabVIEW Icon Editor"
        "Company Name"                    = $companyResolved
        "Author Name (Person or Company)" = $authorResolved
        "Product Homepage (URL)"          = $homepageResolved
        "Legal Copyright"                 = "LabVIEW-Community-CI-CD"
        "License Agreement Name"          = ""
        "Product Description Summary"     = "Community integration engine for LabVIEW"
        "Product Description"             = "Community-driven integration engine for LabVIEW."
        "Release Notes - Change Log"      = ""
    }

    $DisplayInformationJSON = $jsonObject | ConvertTo-Json -Depth 3
    $vipbBuildPath = $VIPBPath
    try {
        $vipbSourcePath = Resolve-VipbPath -RepoPath $RepositoryPath -VipbPath $VIPBPath
        Write-Information ("Using VIPB source: {0}" -f $vipbSourcePath) -InformationAction Continue

        $vipbStampedDir  = Join-Path $RepositoryPath (Join-Path 'builds\vipb-stash' $commitKey)
        if (-not (Test-Path -LiteralPath $vipbStampedDir)) {
            New-Item -ItemType Directory -Path $vipbStampedDir -Force | Out-Null
        }
        $vipbStampedPath = Join-Path $vipbStampedDir (Split-Path -Leaf $vipbSourcePath)
        Copy-Item -LiteralPath $vipbSourcePath -Destination $vipbStampedPath -Force
        $vipbBuildPath = $vipbStampedPath

        $vipbSourceDir = Split-Path -Parent $vipbSourcePath
        $customActionsSource = Join-Path $vipbSourceDir 'custom-actions'
        $customActionsDest   = Join-Path $vipbStampedDir 'custom-actions'
        if (-not (Test-Path -LiteralPath $customActionsSource -PathType Container)) {
            throw ("custom-actions folder not found next to VIPB source: {0}" -f $customActionsSource)
        }
        Copy-Item -LiteralPath $customActionsSource -Destination $customActionsDest -Recurse -Force
        $actionFiles = Get-ChildItem -LiteralPath $customActionsDest -Filter '*.vi' -File -ErrorAction SilentlyContinue
        Write-Information ("Copied custom-actions into stamped VIPB folder: {0} ({1} files)" -f $customActionsDest, ($actionFiles | Measure-Object).Count) -InformationAction Continue

        $repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
        $relOrAbs = {
            param([string]$Root,[string]$Path)
            try { return [System.IO.Path]::GetRelativePath($Root, $Path) } catch { return $Path }
        }
        $expectedPpls = @()
        if ($do64) { $expectedPpls += 'lv_icon_x64.lvlibp' }
        if ($do32) { $expectedPpls += 'lv_icon_x86.lvlibp' }
        $pplHashes = @()
        foreach ($pplName in @('lv_icon_x64.lvlibp','lv_icon_x86.lvlibp')) {
            $pplPath = Join-Path $RepositoryPath (Join-Path 'resource\plugins' $pplName)
            if (-not (Test-Path -LiteralPath $pplPath -PathType Leaf)) { continue }
            try {
                $hash = Get-FileHash -LiteralPath $pplPath -Algorithm SHA256
                $pplHashes += [pscustomobject]@{
                    file      = $pplName
                    bitness   = if ($pplName -like '*x64*') { '64' } else { '32' }
                    hash      = $hash.Hash
                    location  = 'resource/plugins'
                }
            }
            catch {
                Write-Verbose ("Failed to hash {0}: {1}" -f $pplPath, $_.Exception.Message)
            }
        }
        $missingPpls = @($expectedPpls | Where-Object { $_ -notin ($pplHashes | ForEach-Object { $_.file }) })
        if ($missingPpls.Count -gt 0) {
            Write-Verbose ("VIPB stamp manifest missing expected PPL hashes: {0}" -f ($missingPpls -join ', '))
        }

        $vipbManifest = [pscustomobject]@{
            type            = 'vipb'
            commit          = $commitKey
            labviewVersion  = "$lvVersion"
            version         = [pscustomobject]@{
                major = $Major
                minor = $Minor
                patch = $Patch
                build = $Build
            }
            sourceVipb      = & $relOrAbs -Root $repoRoot -Path $vipbSourcePath
            stampedVipb     = & $relOrAbs -Root $repoRoot -Path $vipbStampedPath
            pplStashDir     = & $relOrAbs -Root $repoRoot -Path $pplStashDirNew
            pplExpected     = $expectedPpls
            pplHashes       = $pplHashes
            pplMissing      = $missingPpls
            pplHashesComplete = ($missingPpls.Count -eq 0)
            timestampUtc    = (Get-Date).ToUniversalTime().ToString("o")
        }
        Write-StashManifest -ManifestPath (Join-Path $vipbStampedDir 'manifest.json') -Content $vipbManifest
        Write-Information ("VIPB stamp manifest written: {0}" -f (Join-Path $vipbStampedDir 'manifest.json')) -InformationAction Continue
    }
    catch {
        Write-Warning ("Failed to stamp VIPB copy; proceeding with original VIPBPath. {0}" -f $_.Exception.Message)
        $vipbBuildPath = $VIPBPath
    }

    $vipStashDir = Join-Path $RepositoryPath (Join-Path 'builds\vip-stash' $commitKey)
    $vipStashManifest = Get-StashManifest -StashDir $vipStashDir -Type 'vip'
    $canUseVipStash = Test-VipStashCompatibility -Manifest $vipStashManifest -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build
    if (-not $canUseVipStash -and (Test-Path -LiteralPath $vipStashDir)) {
        Write-Verbose ("VIP stash at {0} is not compatible with current build inputs; skipping restore." -f $vipStashDir)
    }

    # 9) Modify VIPB Display Information
    Write-Verbose "Modify VIPB Display Information (64-bit)..."
    Write-Step -Step "3.9" -Message "Update VIPB display info" -Color "Cyan"
    $ModifyVIPB = Join-Path $ActionsPath "modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
    Invoke-ScriptSafe -ScriptPath $ModifyVIPB -ArgumentMap @{
        SupportedBitness         = '64'
        RepositoryPath           = $RepositoryPath
        VIPBPath                 = $vipbBuildPath
        Package_LabVIEW_Version  = $lvVersion
        LabVIEWMinorRevision     = $LabVIEWMinorRevision
        Major                    = $Major
        Minor                    = $Minor
        Patch                    = $Patch
        Build                    = $Build
        Commit                   = $Commit
        ReleaseNotesFile         = $ReleaseNotesFile
        DisplayInformationJSON   = $DisplayInformationJSON
        Verbose                  = $true
    }

    # Guard: ensure required PPLs exist before invoking VIPM packaging; only build VIP when both bitnesses were built
    $vipOutputDir = Join-Path $RepositoryPath (Join-Path 'builds\vip-stash' $commitKey)
    if ($vipmAvailable -and $do64 -and $do32) {
        Write-Step -Step "3.10" -Message "Build VI Package (64-bit)" -Color "Green"
        Show-GCliLabVIEWTree -Label "pre VIPM packaging"

        Write-Verbose "Building VI Package (64-bit)..."
        if (-not (Test-Path -LiteralPath $vipOutputDir)) {
            New-Item -ItemType Directory -Path $vipOutputDir -Force | Out-Null
        }
        else {
            $staleVips = Get-ChildItem -LiteralPath $vipOutputDir -Filter '*.vip' -File -ErrorAction SilentlyContinue
            if ($staleVips) {
                $staleList = ($staleVips | ForEach-Object { $_.Name }) -join ', '
                Write-Information ("Cleaning stale VIP(s) from output dir {0}: {1}" -f $vipOutputDir, $staleList) -InformationAction Continue
                $staleVips | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Information ("VIP output dir ready (no existing .vip): {0}" -f $vipOutputDir) -InformationAction Continue
            }
        }
        $BuildVip = Join-Path $ActionsPath "build-vip/build_vip.ps1"
        $vipmLogPath = Join-Path $RepositoryPath 'builds\logs\vipm-build-attempt-1.log'
        Invoke-ScriptSafe -ScriptPath $BuildVip -ArgumentMap @{
            SupportedBitness         = '64'
            RepositoryPath           = $RepositoryPath
            VIPBPath                 = $vipbBuildPath
            Package_LabVIEW_Version  = $lvVersion
            LabVIEWMinorRevision     = $LabVIEWMinorRevision
            Major                    = $Major
            Minor                    = $Minor
            Patch                    = $Patch
            Build                    = $Build
            Commit                   = $Commit
            ReleaseNotesFile         = $ReleaseNotesFile
            DisplayInformationJSON   = $DisplayInformationJSON
            Verbose                  = $true
        } -TimeoutSec 180 -DisplayName "Build VI Package (64-bit)"
        Show-GCliLabVIEWTree -Label "post VIPM packaging"
        Write-Information ("[recap][vipm] VIP build complete (output dir: {0}, commit={1})" -f $vipOutputDir, $commitKey) -InformationAction Continue
        try {
            $latestVip = Get-ChildItem -Path $vipOutputDir -Filter *.vip -File -ErrorAction Stop | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        catch {
            throw ("Unable to enumerate VIP output directory {0}: {1}" -f $vipOutputDir, $_.Exception.Message)
        }
        if (-not $latestVip) {
            $logHint = if (Test-Path -LiteralPath $vipmLogPath) { $vipmLogPath } else { "$vipmLogPath (missing)" }
            throw ("VIPM build reported success but no .vip was found under {0}. Check VIPM log: {1}" -f $vipOutputDir, $logHint)
        }
        try {
            if (-not (Test-Path -LiteralPath $vipStashDir)) {
                New-Item -ItemType Directory -Path $vipStashDir -Force | Out-Null
            }
            $vipStashPath = Join-Path $vipStashDir $latestVip.Name
            Copy-Item -LiteralPath $latestVip.FullName -Destination $vipStashPath -Force
            Sync-VipStashManifest -StashDir $vipStashDir -CommitKey $commitKey -LvVersion $lvVersion -Major $Major -Minor $Minor -Patch $Patch -Build $Build -VipFileName $latestVip.Name
            Write-Information ("[artifact][vip-output] {0}" -f $latestVip.FullName) -InformationAction Continue
            Write-Information ("[artifact][vip-stash] Stored VIP at {0}" -f $vipStashPath) -InformationAction Continue
            $recapVipmOk = $true
            $recapVipPath = $latestVip.FullName
        }
        catch {
            Write-Warning ("Failed to stash VIP artifact: {0}" -f $_.Exception.Message)
        }
    }
    else {
        Write-Warning "Skipping VI Package build because prerequisites are missing (vipm available: $vipmAvailable; built 64-bit: $do64; built 32-bit: $do32)."
        $recapVipReason = "skipped (vipm unavailable or missing bitness)"
        try {
            if (-not (Test-Path -LiteralPath $vipOutputDir)) {
                New-Item -ItemType Directory -Path $vipOutputDir -Force | Out-Null
            } else {
                # Clear stale artifacts so downstream checks don't pick up an old VIP
                Get-ChildItem -LiteralPath $vipOutputDir -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            $vipRestored = $false
            if ($canUseVipStash -and $vipStashManifest.vipFile) {
                $stashVipPath = Join-Path $vipStashDir $vipStashManifest.vipFile
                if (Test-Path -LiteralPath $stashVipPath) {
                    Copy-Item -LiteralPath $stashVipPath -Destination (Join-Path $vipOutputDir (Split-Path -Leaf $stashVipPath)) -Force
                    $vipRestored = $true
                    Write-Information ("Restored VIP from stash to {0}" -f $vipOutputDir) -InformationAction Continue
                }
            }

            if (-not $vipRestored) {
                $placeholderVip = Join-Path $vipOutputDir 'vipm-skipped-placeholder.vip'
                "VIPM build skipped because prerequisites were not met (requires both x64/x86 PPLs)." | Set-Content -LiteralPath $placeholderVip -Encoding UTF8
                Write-Information ("Created placeholder VIP artifact at {0} (prereqs missing)" -f $placeholderVip) -InformationAction Continue
            }
        }
        catch {
            Write-Warning ("Failed to create placeholder VIP output: {0}" -f $_.Exception.Message)
        }
    }

    # Final safety: ensure no LabVIEW instances remain running
    Show-GCliLabVIEWTree -Label "pre final LabVIEW close"
    Write-Step -Step "3.11" -Message "Close LabVIEW (final 64-bit)" -Color "Cyan"
    $finalClose64Succeeded = Close-LabVIEWSafe -LvVer $lvVersion -Bitness '64' -TimeoutSec 20
    if (-not $finalClose64Succeeded) {
        Write-Warning "Final close (64-bit) required force termination or LabVIEW remains running after retries."
    }
    Write-Step -Step "3.12" -Message "Close LabVIEW (final 32-bit)" -Color "Cyan"
    $finalClose32Succeeded = Close-LabVIEWSafe -LvVer $lvVersion -Bitness '32' -TimeoutSec 20
    if (-not $finalClose32Succeeded) {
        Write-Warning "Final close (32-bit) required force termination or LabVIEW remains running after retries."
    }

    # Verify both bitnesses are gone; force-kill lingering LabVIEW if needed
    try {
        $lvProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' }
    }
    catch {
        $lvProcs = @()
    }
    if ($lvProcs) {
        Write-Step -Step "3.13" -Message ("LabVIEW still running after final close; terminating {0}" -f ($lvProcs.Id -join ', ')) -Color "Yellow"
        $lvProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $lvProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' }
        if ($lvProcs) {
            throw ("LabVIEW process(es) remain after forced termination: {0}" -f ($lvProcs.Id -join ', '))
        }
    }

    $devStatus = if ($recapDevModeOk) { "OK" } else { "failed/partial" }
    $pplStatus = if ($recapPplOk) { "OK" } else { "failed/partial" }
    $vipStatus = if ($recapVipmOk) {
        if ($recapVipPath) { "OK ($recapVipPath)" } else { "OK" }
    }
    elseif ($recapVipReason) {
        $recapVipReason
    }
    else {
        "missing (see VIPM log)"
    }
    Write-Information ("[summary] Dev mode: {0}; PPLs: {1}; VIPM: {2}" -f $devStatus, $pplStatus, $vipStatus) -InformationAction Continue

    Write-Information "All scripts executed successfully!" -InformationAction Continue
    Write-Verbose "Script: Build.ps1 completed without errors."
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { Write-Warning ("Failed to stop transcript: {0}" -f $_.Exception.Message) }
    }

    $logStashScript = Join-Path $RepositoryPath 'scripts/log-stash/Write-LogStashEntry.ps1'
    if (Test-Path -LiteralPath $logStashScript) {
        try {
            $logs = @()
            if ($logFile -and (Test-Path -LiteralPath $logFile)) { $logs += $logFile }
            if ($vipmLogPath -and (Test-Path -LiteralPath $vipmLogPath)) { $logs += $vipmLogPath }
            $attachments = @()
            $durationMs = [int][Math]::Round(((Get-Date) - $script:BuildStart).TotalMilliseconds,0)
            $label = if ($env:GITHUB_JOB) { $env:GITHUB_JOB } elseif ($env:CI -or $env:GITHUB_ACTIONS) { 'ci-build' } else { 'local-build' }

            & $logStashScript `
                -RepositoryPath $RepositoryPath `
                -Category 'build' `
                -Label $label `
                -LogPaths $logs `
                -AttachmentPaths $attachments `
                -Status $script:BuildStatus `
                -LabVIEWVersion $lvVersion `
                -ProducerScript $PSCommandPath `
                -ProducerTask 'Build.ps1' `
                -ProducerArgs @{
                    LvlibpBitness = $LvlibpBitness;
                    BuildVersion  = "{0}.{1}.{2}.{3}" -f $Major,$Minor,$Patch,$Build
                } `
                -StartedAtUtc $script:BuildStart.ToUniversalTime() `
                -DurationMs $durationMs
        }
        catch {
            Write-Warning ("Failed to write build log-stash bundle: {0}" -f $_.Exception.Message)
        }
    }
}
catch {
    $script:BuildStatus = 'failed'
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    if ($_.InvocationInfo) {
        Write-Warning ("Invocation info: {0}" -f $_.InvocationInfo.PositionMessage)
    }
    Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { Write-Warning ("Failed to stop transcript after error: {0}" -f $_.Exception.Message) }
    }

    $logStashScript = Join-Path $RepositoryPath 'scripts/log-stash/Write-LogStashEntry.ps1'
    if (Test-Path -LiteralPath $logStashScript) {
        try {
            $logs = @()
            if ($logFile -and (Test-Path -LiteralPath $logFile)) { $logs += $logFile }
            if ($vipmLogPath -and (Test-Path -LiteralPath $vipmLogPath)) { $logs += $vipmLogPath }
            $durationMs = if ($script:BuildStart) { [int][Math]::Round(((Get-Date) - $script:BuildStart).TotalMilliseconds,0) } else { $null }
            $label = if ($env:GITHUB_JOB) { $env:GITHUB_JOB } elseif ($env:CI -or $env:GITHUB_ACTIONS) { 'ci-build' } else { 'local-build' }

            & $logStashScript `
                -RepositoryPath $RepositoryPath `
                -Category 'build' `
                -Label $label `
                -LogPaths $logs `
                -Status $script:BuildStatus `
                -LabVIEWVersion $lvVersion `
                -ProducerScript $PSCommandPath `
                -ProducerTask 'Build.ps1' `
                -ProducerArgs @{
                    LvlibpBitness = $LvlibpBitness;
                    BuildVersion  = "{0}.{1}.{2}.{3}" -f $Major,$Minor,$Patch,$Build
                } `
                -StartedAtUtc $(if ($script:BuildStart) { $script:BuildStart.ToUniversalTime() }) `
                -DurationMs $durationMs
        }
        catch {
            Write-Warning ("Failed to write build log-stash bundle (error path): {0}" -f $_.Exception.Message)
        }
    }
    exit 1
}
