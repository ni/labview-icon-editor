[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

[ValidateSet('bind','unbind','status','cleanup')]
[string]$Mode = 'bind',

    [ValidateSet('both','32','64')]
    [string]$Bitness = 'both',

[switch]$Force,
[switch]$AutoFixOtherRepo = $true,
[switch]$DryRun,
[switch]$SummaryOnly,
[string]$JsonOutputPath,
[string]$LabVIEWVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Immediate console heartbeat so callers see progress even before transcript/logs.
Write-Host ("[devmode] Starting dev-mode helper: mode={0} bitness={1} repo={2}" -f $Mode, $Bitness, $RepositoryPath)

# Warn on the common misuse "-Force True"/"-Force False" which PowerShell treats as an extra positional arg.
$invocationLine = $MyInvocation.Line
if ($invocationLine -and $invocationLine -match '-Force\s+(?<boolVal>True|False)\b') {
    $val = $Matches.boolVal
    Write-Warning ("Detected '-Force {0}'. Treating as '-Force'." -f $val)
    $Force = $true
}

# Guard against mistakenly passing a boolean after -Force (e.g. "-Force True") which
# PowerShell binds to JsonOutputPath when positional binding is allowed.
if ($PSBoundParameters.ContainsKey('JsonOutputPath') -and $JsonOutputPath -match '^(?i:true|false)$') {
    Write-Warning ("Ignoring unexpected value '{0}' bound to JsonOutputPath. Use '-Force' or '-Force:`$true' without a trailing value." -f $JsonOutputPath)
    $JsonOutputPath = $null
    $PSBoundParameters.Remove('JsonOutputPath') | Out-Null
    $Force = $true
}

$script:DevBindStart = Get-Date
$transcriptStarted = $false
$logFile = $null
try {
    $logDir = Join-Path $RepositoryPath 'builds/logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("devmode-bind-{0:yyyyMMdd-HHmmss}.log" -f $script:DevBindStart)
    Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
    Write-Host ("[devmode] Transcript logging enabled at {0}" -f $logFile)
}
catch {
    Write-Warning ("[devmode] Failed to start transcript logging: {0}" -f $_.Exception.Message)
}

function Normalize-PathLower {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()
}

function Format-TokenPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '(no entries)' }
    $p = $Path.Replace('"','')
    # If multiple drive roots are present, treat as raw to avoid misleading GetFullPath resolution.
    $colonCount = ($p -split ':').Length - 1
    if ($colonCount -gt 1) { return $p }
    try {
        $full = [System.IO.Path]::GetFullPath($p)
        return $full
    }
    catch {
        return $p
    }
}

function Get-ExpectedTokenPath {
    param([string]$Repo)
    $project = Get-ChildItem -Path $Repo -Filter *.lvproj -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($project) {
        return Split-Path -Parent $project.FullName
    }
    return $Repo
}

function Get-WorktreeHash {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        $leaf = Split-Path -LiteralPath $Path -Leaf
        $m = [regex]::Match($leaf, '^lv-ie-worktree-\d{8}-\d{6}-(?<hash>[0-9a-fA-F]{7,8})$')
        if ($m.Success) { return $m.Groups['hash'].Value.ToLowerInvariant() }
    }
    catch {}
    return $null
}

function Get-LibraryPathState {
    param(
        [string]$LvVersion,
        [string]$Arch
    )

    $result = [ordered]@{
        IniPath = $null
        Paths   = @()
    }

    $iniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
    $result.IniPath = $iniPath

    $lines = Get-Content -LiteralPath $iniPath -ErrorAction Stop
    if ($lines -isnot [System.Array]) { $lines = @($lines) }

    $pattern = 'LocalHost\.LibraryPaths\d*\s*=\s*(?<val>.*)'
    foreach ($line in $lines) {
        $m = [regex]::Match($line, $pattern, 'IgnoreCase')
        if (-not $m.Success) { continue }
        $val = $m.Groups['val'].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $full = ([System.IO.Path]::GetFullPath($val))
            $result.Paths += $full
        }
    }

    return $result
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$expectedToken = Get-ExpectedTokenPath -Repo $RepositoryPath
$expectedNorm = Normalize-PathLower $expectedToken
$pluginsPath = Join-Path -Path $RepositoryPath -ChildPath 'resource\plugins'

$actionRoot = Split-Path -Parent $PSScriptRoot
$setDevScript    = Join-Path -Path $actionRoot -ChildPath 'set-development-mode/Set_Development_Mode.ps1'
$revertDevScript = Join-Path -Path $actionRoot -ChildPath 'revert-development-mode/RevertDevelopmentMode.ps1'
$helperScript    = Join-Path -Path $actionRoot -ChildPath 'add-token-to-labview/LocalhostLibraryPaths.ps1'

if (-not (Test-Path -LiteralPath $helperScript)) {
    throw "Missing helper script: $helperScript"
}
. $helperScript

function Remove-LibraryPathsEntries {
    param(
        [string]$LvVersion,
        [string]$Arch
    )
    try {
        $lvIniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
        $lines = Get-Content -LiteralPath $lvIniPath -ErrorAction Stop
        if ($lines -isnot [System.Array]) { $lines = @($lines) }
        $pattern = 'LocalHost\.LibraryPaths\d*\s*='
        $filtered = $lines | Where-Object { $_ -notmatch $pattern }
        if ($filtered.Count -eq $lines.Count) {
            Write-Information ("No LocalHost.LibraryPaths entries to remove for {0}-bit LabVIEW {1}." -f $Arch, $LvVersion) -InformationAction Continue
        }
        else {
            Set-Content -LiteralPath $lvIniPath -Value ($filtered -join "`r`n")
            Write-Information ("Removed LocalHost.LibraryPaths entries from {0} for {1}-bit LabVIEW {2}." -f $lvIniPath, $Arch, $LvVersion) -InformationAction Continue
        }
        return $true
    }
    catch {
        Write-Warning ("Failed to remove LocalHost.LibraryPaths entries for {0}-bit LabVIEW {1}: {2}" -f $Arch, $LvVersion, $_.Exception.Message)
        return $false
    }
}

$versionScriptCandidates = @(
    (Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1'),
    (Join-Path $RepositoryPath '.github/scripts/get-package-lv-version.ps1'),
    (Join-Path $actionRoot '..' 'scripts/get-package-lv-version.ps1')
) | Where-Object { Test-Path $_ }

if (-not $versionScriptCandidates) {
    throw "Unable to locate get-package-lv-version.ps1"
}
$versionScript = $versionScriptCandidates | Select-Object -First 1

$precheckError = $null
try {
    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        throw "RepositoryPath does not exist: $RepositoryPath"
    }

    foreach ($path in @($setDevScript, $revertDevScript)) {
        if (($Mode -ne 'status') -and -not (Test-Path -LiteralPath $path)) {
            throw "Missing required script: $path"
        }
    }

    if ($Mode -ne 'status') {
        $gcli = Get-Command g-cli -ErrorAction SilentlyContinue
        if (-not $gcli) {
            throw "g-cli is not available on PATH; install g-cli before running bind/unbind."
        }
    }
}
catch {
    $precheckError = $_
}

$lvVersion = $null
try {
    if ($LabVIEWVersion) {
        $lvVersion = $LabVIEWVersion
    }
    else {
        $lvVersion = & $versionScript -RepositoryPath $RepositoryPath
    }
}
catch {
    if (-not $precheckError) { $precheckError = $_ }
}
$vipbFile = Get-ChildItem -Path $RepositoryPath -Filter *.vipb -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
$vipbMsg = if ($vipbFile) { $vipbFile.FullName } else { 'not found' }
Write-Host "=== Context (metadata) ==="
Write-Host ("VIPB path      : {0}" -f $vipbMsg)
Write-Host ("LabVIEW version: {0}" -f $lvVersion)
Write-Host ("Bind request   : mode={0}, bitness={1}" -f $Mode, $Bitness)

# Surface a reminder from the prior run if it recommended Force so users see it before choosing a task/flags.
$previousSummaryPath = Join-Path -Path $RepositoryPath -ChildPath 'reports/dev-mode-bind.json'
if (-not $Force) {
    try {
        $prevContent = Get-Content -LiteralPath $previousSummaryPath -Raw
        $prevData = $prevContent | ConvertFrom-Json
        $forceEntries = @($prevData | Where-Object { $_.message -match 'use -Force' })
        $boundSummary = if ($forceEntries.Count -gt 0) {
            ($forceEntries | ForEach-Object {
                if ($_.bitness -and $_.current_path) { "{0}-bit: {1}" -f $_.bitness, $_.current_path }
            } | Where-Object { $_ } | Select-Object -Unique) -join '; '
        } else {
            'previous dev-mode run'
        }
        Write-Warning ("Reminder: last dev-mode run suggested using Force. LabVIEW.ini currently points to {0}. To bind this repo for LabVIEW {1} you must overwrite that entry. Run the VS Code task 'Dev Mode (interactive bind/unbind)' and choose Force, or rerun this script with -Force." -f $boundSummary, $lvVersion)
    }
    catch {
        Write-Verbose ("Could not read previous bind summary at {0}: {1}" -f $previousSummaryPath, $_.Exception.Message)
    }
}
# Fallback reminder to satisfy task UX even if parsing fails above.
if (-not $Force -and $Mode -eq 'status') {
    Write-Warning "Reminder: last dev-mode run suggested using Force."
}

$installedStates = New-Object System.Collections.Generic.List[object]
$crossVersion = New-Object System.Collections.Generic.List[object]
function Get-LocalHostEntries {
    param([string]$IniPath)
    $entries = @()
    $lines = Get-Content -LiteralPath $IniPath -ErrorAction Stop
    if ($lines -isnot [System.Array]) { $lines = @($lines) }
    $pattern = 'LocalHost\.LibraryPaths\d*\s*=\s*(?<val>.*)'
    foreach ($line in $lines) {
        $m = [regex]::Match($line, $pattern, 'IgnoreCase')
        if (-not $m.Success) { continue }
        $val = $m.Groups['val'].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $entries += ([System.IO.Path]::GetFullPath($val))
        }
    }
    return $entries
}

foreach ($root in @('C:\Program Files\National Instruments','C:\Program Files (x86)\National Instruments')) {
    if (-not (Test-Path $root)) { continue }
    $archHint = if ($root -like '*x86*') { '32' } else { '64' }
    Get-ChildItem -Path $root -Directory -Filter 'LabVIEW *' -ErrorAction SilentlyContinue | ForEach-Object {
        $iniCandidate = Join-Path $_.FullName 'LabVIEW.ini'
        if (-not (Test-Path $iniCandidate)) { return }
        try {
            $entries = @(Get-LocalHostEntries -IniPath $iniCandidate)
            $installedStates.Add([pscustomobject]@{
                arch    = $archHint
                version = $_.Name.TrimStart('LabVIEW ').Trim()
                ini     = $iniCandidate
                entries = $entries
            })
        }
        catch {}
    }
}

if (-not $SummaryOnly) {
    if ($installedStates.Count -gt 0) {
        $targetStates = @($installedStates | Where-Object { $_.version -like "$lvVersion*" })
        $otherStates  = @($installedStates | Where-Object { $_.version -notlike "$lvVersion*" })

        Write-Host "=== Target LabVIEW INI tokens (version $lvVersion) ==="
        foreach ($arch in @('32','64')) {
            $state = $targetStates | Where-Object { $_.arch -eq $arch } | Select-Object -First 1
            if (-not $state) {
                Write-Host ("  [MISS] {0}-bit {1}: (not detected under Program Files)" -f $arch, $lvVersion)
                continue
            }
            $entryList = @($state.entries)
            if (-not $entryList -or $entryList.Count -eq 0) {
                Write-Host ("  [NONE] {0}-bit {1}: (no LocalHost.LibraryPaths entries)" -f $arch, $state.version)
                $crossVersion.Add([pscustomobject]@{
                    version = $state.version
                    arch    = $arch
                    tag     = 'NONE'
                    path    = '(no LocalHost.LibraryPaths entries)'
                })
                continue
            }
            $firstRaw = $entryList[0]
            $first = Format-TokenPath $firstRaw
            $norm = Normalize-PathLower $firstRaw
            # Distinguish bindings to this repo vs other repos.
            $tag = if ($norm -eq $expectedNorm) { 'THIS-REPO' } else { 'OTHER-REPO' }
            $tagColor = ''
            $resetColor = ''
            if ($PSStyle) {
                switch ($tag) {
                    'THIS-REPO'  { $tagColor = $PSStyle.Foreground.BrightGreen }
                    'OTHER-REPO' { $tagColor = $PSStyle.Foreground.BrightYellow }
                    'MISS'  { $tagColor = $PSStyle.Foreground.BrightRed }
                    'NONE'  { $tagColor = $PSStyle.Foreground.BrightBlack }
                }
                $resetColor = $PSStyle.Reset
            }
            $tagRendered = if ($tagColor) { "{0}[{1}]{2}" -f $tagColor, $tag, $resetColor } else { "[{0}]" -f $tag }
            Write-Host ("  {0} {1}-bit {2}: {3}" -f $tagRendered, $arch, $state.version, $first)
            $crossVersion.Add([pscustomobject]@{
                version = $state.version
                arch    = $arch
                tag     = $tag
                path    = $first
            })
        }

        if ($otherStates.Count -gt 0) {
            Write-Host "=== Other installed LabVIEW INI tokens ==="
            foreach ($state in ($otherStates | Sort-Object arch,version)) {
                $entryList = @($state.entries)
                if (-not $entryList -or $entryList.Count -eq 0) {
                    Write-Host ("  [NONE] {0}-bit {1}: (no LocalHost.LibraryPaths entries)" -f $state.arch, $state.version)
                    continue
                }
                $firstRaw = $entryList[0]
                $first = Format-TokenPath $firstRaw
                $norm = Normalize-PathLower $firstRaw
                $tag = if ($norm -eq $expectedNorm) { 'THIS-REPO' } else { 'OTHER-REPO' }
                $tagColor = ''
                $resetColor = ''
                if ($PSStyle) {
                    switch ($tag) {
                        'THIS-REPO'  { $tagColor = $PSStyle.Foreground.BrightGreen }
                        'OTHER-REPO' { $tagColor = $PSStyle.Foreground.BrightYellow }
                        'MISS'  { $tagColor = $PSStyle.Foreground.BrightRed }
                        'NONE'  { $tagColor = $PSStyle.Foreground.BrightBlack }
                    }
                    $resetColor = $PSStyle.Reset
                }
                $tagRendered = if ($tagColor) { "{0}[{1}]{2}" -f $tagColor, $tag, $resetColor } else { "[{0}]" -f $tag }
                Write-Host ("  {0} {1}-bit {2}: {3}" -f $tagRendered, $state.arch, $state.version, $first)
                $crossVersion.Add([pscustomobject]@{
                    version = $state.version
                    arch    = $state.arch
                    tag     = $tag
                    path    = $first
                })
            }
        }
    }
    else {
        Write-Host "=== Target LabVIEW INI tokens (version $lvVersion) ==="
        Write-Host "  none found under Program Files."
    }
}

$bitnessList = if ($Bitness -eq 'both') { @('32','64') } else { @($Bitness) }
$results = New-Object System.Collections.Generic.List[object]
$hadFailure = $false
$missingIniArchs = New-Object System.Collections.Generic.List[string]
$anomalies = New-Object System.Collections.Generic.List[string]
$forceNeededThisRun = $false

function New-ResultObject {
    param(
        [string]$Arch
    )
    $obj = [ordered]@{
        bitness        = $Arch
        available      = $true
        expected_path  = $expectedToken
        current_path   = ''
        post_path      = ''
        action         = 'status'
        status         = 'skip'
        message        = ''
    }
    return New-Object psobject -Property $obj
}

if ($precheckError) {
    foreach ($arch in $bitnessList) {
        $res = New-ResultObject -Arch $arch
        $res.status = 'fail'
        $res.action = $Mode
        $res.message = $precheckError.Exception.Message
        $res.available = $false
        $res.post_path = ''
        $results.Add($res)
    }
}
else {
    foreach ($arch in $bitnessList) {
        $res = New-ResultObject -Arch $arch
        try {
            $state = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.current_path = if ($state.Paths) { $state.Paths[0] } else { '' }
        }
        catch {
            $res.available = $false
            $res.status = 'fail'
            $res.action = $Mode
            $res.message = ("LabVIEW.ini not found for {0}-bit at the canonical path for LabVIEW {1}: {2}" -f $arch, $lvVersion, $_.Exception.Message)
            $missingIniArchs.Add($arch)
            $hadFailure = $true
            Write-Verbose $res.message
            $results.Add($res)
            continue
        }

        $res.action = $Mode

        $currentNorm = Normalize-PathLower $res.current_path
        $expectedMatch = ($state.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
        $hasAnyPath = $state.Paths.Count -gt 0
        # Detect packed libraries (files or folders) to decide if re-binding is needed even when the token matches.
        $hasPackedLibs = Test-Path -Path (Join-Path $pluginsPath '*.lvlibp')

        if ($Mode -eq 'status') {
            $res.status = 'success'
            $res.post_path = $res.current_path
            $res.message = 'Status only'
            $results.Add($res)
            continue
        }

        $autoForce = (-not [string]::IsNullOrWhiteSpace($currentNorm)) -and ($currentNorm -ne $expectedNorm) -and $AutoFixOtherRepo -and -not $Force
        # Auto-force when the token points to a stale worktree for this repo (same prefix, different hash)
        $staleWorktreeForce = $false
        if (-not $Force) {
            $expectedHash = Get-WorktreeHash -Path $expectedToken
            $currentHash  = Get-WorktreeHash -Path $res.current_path
            if ($expectedHash -and $currentHash -and ($expectedHash -ne $currentHash)) {
                $staleWorktreeForce = $true
            }
        }
        if ($staleWorktreeForce) {
            $autoForce = $true
        }
        $forceApplied = $Force -or $autoForce
        $conflictsOtherRepo = (-not [string]::IsNullOrWhiteSpace($currentNorm)) -and ($currentNorm -ne $expectedNorm) -and -not $forceApplied
        if ($conflictsOtherRepo) {
            $res.status = 'fail'
            $res.message = "LocalHost.LibraryPaths points to another path ($($res.current_path)); use -Force to overwrite."
            $res.post_path = $res.current_path
            $results.Add($res)
            $hadFailure = $true
            $anomalies.Add("Target version $lvVersion ($arch-bit) currently bound to another path: $($res.current_path)")
            $forceNeededThisRun = $true
            continue
        }

        if ($Mode -eq 'cleanup') {
            if ($DryRun) {
                $res.status = 'dry-run'
                $res.message = 'Dry run: would remove LocalHost.LibraryPaths entries'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }
            $ok = Remove-LibraryPathsEntries -LvVersion $lvVersion -Arch $arch
            $res.post_path = ''
            if ($ok) {
                $res.status = 'success'
                $res.message = 'Cleaned LocalHost.LibraryPaths entries'
            }
            else {
                $res.status = 'fail'
                $res.message = 'Cleanup failed (see warnings)'
                $hadFailure = $true
            }
            $results.Add($res)
            continue
        }

        if ($Mode -eq 'bind') {
            if ($expectedMatch -and -not $hasPackedLibs) {
                $res.status = 'success'
                $res.message = 'Already bound'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            # When overwriting another repo or stale worktree, aggressively clear mismatched tokens first.
            if ($forceApplied -or $autoForce) {
                try {
                    Clear-StaleLibraryPaths -LvVersion $lvVersion -Arch $arch -RepositoryRoot $RepositoryPath -Force -TargetPath $expectedToken
                }
                catch {
                    Write-Warning ("Pre-bind token cleanup failed for {0}-bit: {1}" -f $arch, $_.Exception.Message)
                }
            }

            if ($DryRun) {
                $res.status = 'dry-run'
                $res.message = 'Dry run: would bind development mode'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            # Enforce single-token per version/bitness: clear all entries before binding.
            try {
                if (-not (Remove-LibraryPathsEntries -LvVersion $lvVersion -Arch $arch)) {
                    throw "Failed to clear existing LocalHost.LibraryPaths entries for $arch-bit LabVIEW $lvVersion."
                }
            }
            catch {
                $res.status = 'fail'
                $res.message = "Pre-bind cleanup failed: $($_.Exception.Message)"
                $hadFailure = $true
                $results.Add($res)
                continue
            }

            $bindAttempted = $false
            try {
                $bindAttempted = $true
                $setArgs = @{
                    RepositoryPath         = $RepositoryPath
                    SupportedBitness       = $arch
                }
                if ($lvVersion) { $setArgs['Package_LabVIEW_Version'] = $lvVersion }
                & $setDevScript @setArgs | Out-Null
            }
            catch {
                $res.status = 'fail'
                $res.message = "Bind failed: $($_.Exception.Message)"
                if ($bindAttempted) {
                    try {
                        $revertArgs = @{
                            RepositoryPath   = $RepositoryPath
                            SupportedBitness = $arch
                        }
                        if ($lvVersion) { $revertArgs['Package_LabVIEW_Version'] = $lvVersion }
                        & $revertDevScript @revertArgs | Out-Null
                        $res.message += '; attempted revert after failure'
                    }
                    catch {
                        $res.message += "; revert failed: $($_.Exception.Message)"
                    }
                }
                $hadFailure = $true
                try {
                    $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
                    $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
                }
                catch {}
                $results.Add($res)
                continue
            }

            $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
            $postMatch = ($statePost.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
            # Fallback: if token still points elsewhere and auto-fix is enabled, attempt to force-write the token and re-read.
            if (-not $postMatch -and $AutoFixOtherRepo) {
                try {
                    Add-LibraryPathToken -LvVersion $lvVersion -Arch $arch -TokenPath $expectedToken -RepositoryRoot $RepositoryPath
                    $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
                    $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
                    $postMatch = ($statePost.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
                }
                catch {
                    Write-Warning ("Auto-fix write for {0}-bit token failed: {1}" -f $arch, $_.Exception.Message)
                }
            }
            if ($postMatch) {
                $res.status = 'success'
                $res.message = 'Bound development mode (token set and packed libs cleared)'
                if ($autoForce) {
                    $res.message += " (auto-fixed prior binding from $($res.current_path))"
                    if ($staleWorktreeForce) {
                        $res.message += " [stale worktree token auto-forced]"
                    }
                }
            }
            else {
                $res.status = 'fail'
                $res.message = 'Bind completed but expected token not found after verification.'
                $hadFailure = $true
            }
            $results.Add($res)
            continue
        }

        if ($Mode -eq 'unbind') {
            if (-not $hasAnyPath -and -not $Force) {
                $res.status = 'success'
                $res.message = 'No dev-mode token present; nothing to unbind.'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            if (-not $expectedMatch -and $hasAnyPath -and -not $Force) {
                $res.status = 'fail'
                $res.message = 'No matching dev-mode token to remove; use -Force to clear mismatched entry if desired.'
                $res.post_path = $res.current_path
                $results.Add($res)
                $hadFailure = $true
                continue
            }

            if ($DryRun) {
                $res.status = 'dry-run'
                $res.message = 'Dry run: would unbind development mode'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            try {
                # Force removal of stale tokens when requested
                if ($Force) {
                    # Remove all LocalHost.LibraryPaths entries for this version/bitness when forcing unbind
                    Remove-LibraryPathsEntries -LvVersion $lvVersion -Arch $arch | Out-Null
                } else {
                    Clear-StaleLibraryPaths -LvVersion $lvVersion -Arch $arch -RepositoryRoot $RepositoryPath
                }
                & $revertDevScript -RepositoryPath $RepositoryPath -SupportedBitness $arch | Out-Null
            }
            catch {
                $res.status = 'fail'
                $res.message = "Unbind failed: $($_.Exception.Message)"
                $hadFailure = $true
                try {
                    $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
                    $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
                }
                catch {}
                $results.Add($res)
                continue
            }

            $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
            $postMatch = ($statePost.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
            if (-not $postMatch) {
                $res.status = 'success'
                $res.message = 'Unbound development mode (token removed)'
            }
            else {
                $res.status = 'fail'
                $res.message = 'Expected dev-mode token still present after unbind.'
                $hadFailure = $true
            }
            $results.Add($res)
            continue
        }
    }
}

if (-not $JsonOutputPath) {
    $JsonOutputPath = Join-Path -Path $RepositoryPath -ChildPath 'reports/dev-mode-bind.json'
}

$JsonOutputPath = [System.IO.Path]::GetFullPath($JsonOutputPath)
$parent = Split-Path -Parent $JsonOutputPath
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$json = ConvertTo-Json -InputObject $results -Depth 5
Set-Content -LiteralPath $JsonOutputPath -Value $json -Encoding utf8

$hasStyle = $PSStyle -ne $null
$palette = @{
    head  = if ($hasStyle) { $PSStyle.Foreground.Cyan }         else { '' }
    ok    = if ($hasStyle) { $PSStyle.Foreground.BrightGreen }  else { '' }
    warn  = if ($hasStyle) { $PSStyle.Foreground.BrightYellow } else { '' }
    fail  = if ($hasStyle) { $PSStyle.Foreground.BrightRed }    else { '' }
    path  = if ($hasStyle) { $PSStyle.Foreground.BrightBlack }  else { '' }
    reset = if ($hasStyle) { $PSStyle.Reset }                   else { '' }
}

function Get-StatusVisual {
    param([string]$Status)
    switch ($Status) {
        'success' { return @{ color = $palette.ok;   glyph = 'OK ' } }
        'dry-run' { return @{ color = $palette.warn; glyph = 'DRY' } }
        'skip'    { return @{ color = $palette.warn; glyph = 'SKP' } }
        default   { return @{ color = $palette.fail; glyph = 'ERR' } }
    }
}

Write-Host ("{0}==== Dev Mode ({1} {2}) ===={3}" -f $palette.head, $Mode, $Bitness, $palette.reset)
if (-not $SummaryOnly) {
    foreach ($r in $results) {
        $visual = Get-StatusVisual -Status $r.status
        $pathOut = if (-not [string]::IsNullOrWhiteSpace($r.post_path)) { $r.post_path } else { $r.current_path }
        $msg = if (-not [string]::IsNullOrWhiteSpace($r.message)) { "; msg=$($r.message)" } else { '' }
        Write-Host ("{0}[{1}] bitness={2,-2} action={3,-6} status={4,-7}{5} {6}{7}{8}{9}" -f
            $visual.color,
            $visual.glyph,
            $r.bitness,
            $r.action,
            $r.status,
            $palette.reset,
            $palette.path,
            $pathOut,
            $palette.reset,
            $msg)
    }
}
Write-Host ("{0}JSON:{1} {2}{3}{4}" -f $palette.head, $palette.reset, $palette.path, $JsonOutputPath, $palette.reset)

$totals = @{
    success = @($results | Where-Object { $_.status -eq 'success' }).Count
    fail    = @($results | Where-Object { $_.status -eq 'fail' }).Count
    skip    = @($results | Where-Object { $_.status -eq 'skip' }).Count
    dryrun  = @($results | Where-Object { $_.status -eq 'dry-run' }).Count
}
Write-Host ("{0}Totals:{1} success={2} fail={3} skip={4} dry-run={5}" -f $palette.head, $palette.reset, $totals.success, $totals.fail, $totals.skip, $totals.dryrun)

$hintLines = New-Object System.Collections.Generic.List[string]
if (@($results | Where-Object { $_.status -eq 'fail' -and $_.message -match 'use -Force' }).Count -gt 0) {
    $hintLines.Add("Open VS Code > Terminal > Run Task, pick 'Dev Mode (interactive bind/unbind)'.")
    $hintLines.Add("Choose bind + Force to overwrite, or unbind + Force to clear the other token (same as BindDevelopmentMode.ps1 flags).")
    $hintLines.Add("CLI: pwsh scripts/bind-development-mode/BindDevelopmentMode.ps1 -RepositoryPath '$RepositoryPath' -Mode bind -Bitness both -Force")
}
# If a target bitness has no LocalHost.LibraryPaths entry, suggest binding for that bitness.
$resultsByArch = @{}
foreach ($r in $results) { $resultsByArch[$r.bitness] = $r }
function Get-ResultStatus {
    param([string]$Arch)
    $res = $resultsByArch[$Arch]
    if (-not $res) { return $null }
    try { return $res.status } catch { return $null }
}
$missingTokens = @($crossVersion | Where-Object { $_.version -like "$lvVersion*" -and $_.tag -eq 'NONE' -and (Get-ResultStatus $_.arch) -ne 'success' })
if ($missingTokens.Count -gt 0) {
    $archText = ($missingTokens | ForEach-Object { "$($_.arch)-bit" }) -join '/'
    $hintLines.Add("No LocalHost.LibraryPaths entry found for $archText LabVIEW $lvVersion; run dev-mode bind for that bitness to populate the INI token.")
}
# Guardrail: target version tokens should point to this repo for all bitnesses
$wrongRepo = @($crossVersion | Where-Object { $_.version -like "$lvVersion*" -and $_.tag -ne 'THIS-REPO' -and $_.tag -ne 'NONE' -and (Get-ResultStatus $_.arch) -ne 'success' })
if ($wrongRepo.Count -gt 0) {
    $archText = ($wrongRepo | ForEach-Object { "$($_.arch)-bit" }) -join '/'
    $hintLines.Add("LabVIEW $lvVersion ($archText) LocalHost.LibraryPaths points elsewhere; bind those bitnesses so both tokens point to this repo.")
}
if ($missingIniArchs.Count -gt 0) {
    $archText = ($missingIniArchs | ForEach-Object { "$_-bit" }) -join '/'
    $hintLines.Add(("Install LabVIEW {0} ({1}) so the canonical LabVIEW.ini exists, or update the VIPB to a version that is installed, then rerun." -f $lvVersion, $archText))
}

if ($results.Count -gt 0) {
    Write-Host ("{0}Summary:{1}" -f $palette.head, $palette.reset)
    foreach ($arch in @('32','64')) {
        $r = $results | Where-Object { $_.bitness -eq $arch } | Select-Object -First 1
        if (-not $r) { continue }
        $statusText = $r.status
        $reason =
            if ($r.status -eq 'success' -and $r.message -eq 'Already bound') { 'Already bound to this repo' }
            elseif ($r.status -eq 'fail' -and $r.message -like 'LabVIEW.ini not found*') { 'Missing LabVIEW.ini for this version/bitness' }
            else { $r.message }
        Write-Host ("  {0}-bit: {1} - {2}" -f $arch, $statusText, $reason)
    }
}
if ($hintLines.Count -gt 0) {
    Write-Host ("{0}Action required:{1}" -f $palette.head, $palette.reset)
    foreach ($line in $hintLines) {
        Write-Host ("  {0}" -f $line)
    }
}

if ($crossVersion.Count -gt 0) {
    $suspicious = @($crossVersion | Where-Object { $_.path -match 'C:\\.*C:\\' })
    if ($suspicious.Count -gt 0) {
        $suspiciousText = ($suspicious | ForEach-Object { "{0}-bit {1}: {2}" -f $_.arch, $_.version, $_.path } | Select-Object -First 3)
        $anomalies.Add("Suspicious token paths detected (possible double-rooted): " + ($suspiciousText -join '; '))
    }
}

if ($anomalies.Count -gt 0) {
    Write-Host ("{0}Anomalies:{1}" -f $palette.head, $palette.reset)
    foreach ($a in $anomalies | Select-Object -Unique) {
        Write-Host ("  {0}" -f $a)
    }
}

# Emit a markdown summary when Force is needed (current run) to aid troubleshooting.
if ($forceNeededThisRun) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $artifactDir = Join-Path $RepositoryPath "artifacts/dev-mode-bind"
    if (-not (Test-Path $artifactDir)) { New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null }

    $targetLines = @()
    foreach ($arch in @('32','64')) {
        $state = ($installedStates | Where-Object { $_.version -like "$lvVersion*" -and $_.arch -eq $arch } | Select-Object -First 1)
        $val = if ($state -and $state.entries -and $state.entries.Count -gt 0) { Format-TokenPath $state.entries[0] } else { '(no LocalHost.LibraryPaths entries)' }
        $targetLines += ("- {0}-bit {1}: {2}" -f $arch, $lvVersion, $val)
    }

    $summaryLines = @()
    foreach ($arch in @('32','64')) {
        $r = $results | Where-Object { $_.bitness -eq $arch } | Select-Object -First 1
        if (-not $r) { continue }
        $summaryLines += ("- {0}-bit: {1} - {2}" -f $arch, $r.status, $r.message)
    }

    $anomalyLines = if ($anomalies.Count -gt 0) {
        $anomalies | Select-Object -Unique | ForEach-Object { "- $_" }
    } else { @("- None recorded") }

    $md = @"
# Dev Mode Bind – Force Required (LabVIEW $lvVersion)
## Context
- VIPB: $vipbMsg
- Mode/Bitness: $Mode / $Bitness

## Target LabVIEW INI tokens ($lvVersion)
$( $targetLines -join "`n")

## Result summary
$( $summaryLines -join "`n")

## Anomalies
$( $anomalyLines -join "`n")

## Action
- VS Code: Terminal → Run Task → 'Dev Mode (interactive bind/unbind)' → choose bind + Force (or unbind + Force).
- CLI: pwsh scripts/bind-development-mode/BindDevelopmentMode.ps1 -RepositoryPath '$RepositoryPath' -Mode bind -Bitness both -Force

## JSON
- $JsonOutputPath

## Paste to your CODEX Agent
Copy/paste this block to the agent (the console output above is the log to use):

You are the integration agent. Dev-mode bind failed because LabVIEW.ini points to another path. Use the console output above and `reports/dev-mode-bind.json` to diagnose.

What you should do:
1) Diagnose using the log and `reports/dev-mode-bind.json` (paths, statuses, anomalies).
2) Recommend rerunning with Force to bind this repo:
   - VS Code: Terminal → Run Task → “Dev Mode (interactive bind/unbind)” → **bind** + **Force** (bitness as needed).
   - CLI: `pwsh scripts/bind-development-mode/BindDevelopmentMode.ps1 -RepositoryPath . -Mode bind -Bitness both -Force`
3) If other repos might rely on current bindings, warn and ask before overwriting.
4) Flag and suggest cleaning suspicious/double-rooted tokens (unbind + Force for that version/bitness if not needed).
5) Include next steps and the JSON path in your reply.
"@

    Write-Host $md

    try {
        $artifactJson = Join-Path $artifactDir ("dev-mode-bind-{0}.json" -f $timestamp)
        $artifactMd   = Join-Path $artifactDir ("dev-mode-bind-{0}.md" -f $timestamp)
        Copy-Item -LiteralPath $JsonOutputPath -Destination $artifactJson -Force
        Set-Content -LiteralPath $artifactMd -Value $md -Encoding UTF8
        Write-Host ("Artifact saved: {0}" -f $artifactJson)
        Write-Host ("Log saved:      {0}" -f $artifactMd)
    }
    catch {
        Write-Verbose ("Failed to save artifact copy: {0}" -f $_.Exception.Message)
    }

    try {
        $guidePath = Resolve-Path (Join-Path $PSScriptRoot '..\..\docs\troubleshooting\bind-dev-mode-force.md')
        Write-Host ""
        Write-Host "=== Troubleshooting Guide ==="
        Get-Content -LiteralPath $guidePath
    }
    catch {
        Write-Verbose ("Troubleshooting guide not found: {0}" -f $_.Exception.Message)
    }
}

$exitFail = @($results | Where-Object { $_.status -in @('fail','blocked') })
$overallStatus = if ($exitFail.Count -gt 0) { 'failed' } else { 'success' }

if ($transcriptStarted) {
    try { Stop-Transcript | Out-Null } catch { Write-Warning ("[devmode] Failed to stop transcript: {0}" -f $_.Exception.Message) }
}

$logStashScript = Join-Path $RepositoryPath 'scripts/log-stash/Write-LogStashEntry.ps1'
if (Test-Path -LiteralPath $logStashScript) {
    try {
        $logs = @()
        if ($logFile -and (Test-Path -LiteralPath $logFile)) { $logs += $logFile }
        $attachments = @()
        if ($JsonOutputPath -and (Test-Path -LiteralPath $JsonOutputPath)) { $attachments += $JsonOutputPath }
        $durationMs = [int][Math]::Round(((Get-Date) - $script:DevBindStart).TotalMilliseconds,0)
        $label = if ($env:GITHUB_JOB) { $env:GITHUB_JOB } elseif ($env:CI -or $env:GITHUB_ACTIONS) { 'ci-devmode' } else { 'local-devmode' }

        & $logStashScript `
            -RepositoryPath $RepositoryPath `
            -Category 'devmode' `
            -Label $label `
            -LogPaths $logs `
            -AttachmentPaths $attachments `
            -Status $overallStatus `
            -LabVIEWVersion $lvVersion `
            -ProducerScript $PSCommandPath `
            -ProducerTask 'BindDevelopmentMode.ps1' `
            -ProducerArgs @{ Mode = $Mode; Bitness = $Bitness; Force = $Force.IsPresent; DryRun = $DryRun.IsPresent } `
            -StartedAtUtc $script:DevBindStart.ToUniversalTime() `
            -DurationMs $durationMs
    }
    catch {
        Write-Warning ("[devmode] Failed to write log-stash bundle: {0}" -f $_.Exception.Message)
    }
}

if ($exitFail.Count -gt 0) {
    exit 1
}

exit 0
