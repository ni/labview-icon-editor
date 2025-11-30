[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [ValidateSet('bind','unbind')]
    [string]$Mode = 'bind',

    [ValidateSet('auto','both','32','64')]
    [string]$Bitness = 'auto',

[switch]$Preclear,

[switch]$UseWorktree
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$localHostHelper = Join-Path $PSScriptRoot 'add-token-to-labview/LocalhostLibraryPaths.ps1'
if (-not (Test-Path -LiteralPath $localHostHelper -PathType Leaf)) {
    throw "Missing LocalHost helper: $localHostHelper"
}
. $localHostHelper

$sourceRepo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$repo = $sourceRepo
$createdWorktree = $false
$worktreePath = $null

# Centralized worktree root outside the repo, plus stash/report root (reports stay in-source).
$worktreeRoot = $null
try {
    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = $env:TEMP }
    if ([string]::IsNullOrWhiteSpace($base)) { $base = [System.IO.Path]::GetTempPath() }
    $worktreeRoot = Join-Path $base 'labview-icon-editor\devmode-worktrees'
}
catch {
    $worktreeRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'labview-icon-editor\devmode-worktrees'
}
$summaryRoot = $sourceRepo

# Default to using an isolated worktree so bind/unbind happens away from the main repo.
if (-not $PSBoundParameters.ContainsKey('UseWorktree')) {
    $UseWorktree = $true
}

# Helper: pick the latest existing devmode worktree (if any).
function Get-LatestDevModeWorktree {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $null }
    $dirs = Get-ChildItem -LiteralPath $Root -Directory -Filter 'devmode-*' -ErrorAction SilentlyContinue |
        Sort-Object CreationTime -Descending
    return ($dirs | Select-Object -First 1)
}

# Optional: create an isolated worktree first so binding targets that path.
if ($Mode -eq 'bind' -and $UseWorktree) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "git is required to create a worktree for binding."
    }
    $ref = (git -C $sourceRepo rev-parse HEAD).Trim()
    if (-not $ref) { throw "Unable to resolve HEAD in $sourceRepo" }
    if (-not (Test-Path -LiteralPath $worktreeRoot)) {
        New-Item -ItemType Directory -Path $worktreeRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $short = $ref.Substring(0, [Math]::Min(7, $ref.Length))
    $worktreeName = "devmode-$stamp-$short"
    $worktreePath = Join-Path $worktreeRoot $worktreeName
    git -C $sourceRepo worktree add --detach --no-checkout "$worktreePath" $ref | Out-Null
    git -C $worktreePath checkout $ref | Out-Null
    $repo = (Resolve-Path -LiteralPath $worktreePath).Path
    $createdWorktree = $true
    $summaryRoot = $repo
}
elseif ($Mode -eq 'unbind' -and $UseWorktree) {
    $latest = Get-LatestDevModeWorktree -Root $worktreeRoot
    if ($latest) {
        $latestPath = (Resolve-Path -LiteralPath $latest.FullName).Path
        $requiredScripts = @(
            'scripts/get-package-lv-version.ps1',
            'scripts/get-package-lv-bitness.ps1'
        )
        # Ensure we always get an array so Count works even when only one item matches.
        $missing = @($requiredScripts | Where-Object { -not (Test-Path -LiteralPath (Join-Path $latestPath $_)) })
        if ($missing.Count -gt 0) {
            Write-Warning ("Worktree {0} missing expected scripts ({1}); removing stale worktree." -f $latestPath, ($missing -join ', '))
            try {
                git -C $sourceRepo worktree remove $latestPath -f 2>$null
            }
            catch { }
            Remove-Item -LiteralPath $latestPath -Force -Recurse -ErrorAction SilentlyContinue
            $latest = $null
        }
        else {
            $repo = $latestPath
            $worktreePath = $repo
            $summaryRoot = $repo
            $createdWorktree = $true
        }
    }
    if (-not $latest) {
        Write-Warning ("No devmode worktree found under {0}; proceeding with source repo." -f $worktreeRoot)
    }
}

$repo = (Resolve-Path -LiteralPath $repo).Path
$versionScript = Join-Path $repo 'scripts/get-package-lv-version.ps1'
if (-not (Test-Path -LiteralPath $versionScript)) {
    throw "Unable to locate get-package-lv-version.ps1 under $repo"
}

# Locate the VIPB we'll derive metadata from (prefer the canonical seed.vipb).
$preferredVipb = Join-Path $repo 'Tooling/deployment/seed.vipb'
if (Test-Path -LiteralPath $preferredVipb) {
    $vipbPath = (Resolve-Path -LiteralPath $preferredVipb).Path
}
else {
    $vipbPath = Get-ChildItem -Path $repo -Filter *.vipb -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\\.tmp-tests\\' -and
            $_.FullName -notmatch '\\builds(-isolated(-tests)?)?\\' -and
            $_.FullName -notmatch '\\temp_telemetry\\' -and
            $_.FullName -notmatch '\\artifacts\\'
        } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $vipbPath) {
    throw "No .vipb file found under $repo"
}

# Locate a VIPC to surface (for dependency/apply context).
$vipcPath = $null
$vipcCandidates = @(
    (Join-Path $repo 'runner_dependencies.vipc'),
    (Join-Path $repo 'Tooling/deployment/runner_dependencies.vipc'),
    (Join-Path $repo 'icon-editor-developer.vipc')
) | Where-Object { Test-Path -LiteralPath $_ }

$vipcCandidates = @($vipcCandidates)
if ($vipcCandidates.Count -gt 0) {
    $vipcPath = (Resolve-Path -LiteralPath ($vipcCandidates | Select-Object -First 1)).Path
}
else {
    $vipcPath = Get-ChildItem -Path $repo -Filter *.vipc -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\\.tmp-tests\\' -and
            $_.FullName -notmatch '\\builds(-isolated(-tests)?)?\\' -and
            $_.FullName -notmatch '\\temp_telemetry\\' -and
            $_.FullName -notmatch '\\artifacts\\'
        } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1 -ExpandProperty FullName
}

$lvVersion = & $versionScript -RepositoryPath $repo
if (-not $lvVersion) {
    throw "Failed to resolve LabVIEW version from VIPB under $repo"
}

$bitness = $Bitness
if ($Bitness -eq 'auto' -or -not $Bitness) {
    $bitnessScript = Join-Path $repo 'scripts/get-package-lv-bitness.ps1'
    if (-not (Test-Path -LiteralPath $bitnessScript)) {
        throw "Unable to locate get-package-lv-bitness.ps1 under $repo"
    }
    $bitness = & $bitnessScript -RepositoryPath $repo
    if (-not $bitness) {
        throw "Failed to resolve LabVIEW bitness from VIPB under $repo"
    }
    # Single-bitness flow: if VIPB reports 'both', default to 64-bit.
    if ($bitness -eq 'both') { $bitness = '64' }
}
 $programFiles64 = ${env:ProgramFiles}
 $programFiles32 = ${env:ProgramFiles(x86)}

function Get-LabVIEWIniCandidates {
    param(
        [int]$StartYear = 2018,
        [int]$EndYear = 2030
    )
    $paths = New-Object System.Collections.Generic.List[string]
    for ($year = $StartYear; $year -le $EndYear; $year++) {
        $candidates = @()
        if ($programFiles64) {
            $candidates += Join-Path $programFiles64 "National Instruments\LabVIEW $year\LabVIEW.ini"
            $candidates += Join-Path $programFiles64 "National Instruments\LabVIEW $year (32-bit)\LabVIEW.ini"
        }
        if ($programFiles32) {
            $candidates += Join-Path $programFiles32 "National Instruments\LabVIEW $year\LabVIEW.ini"
        }
        foreach ($candidate in $candidates) {
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                if (-not ($paths.Contains($candidate))) {
                    $paths.Add($candidate)
                }
            }
        }
    }
    return [array]$paths
}

function Get-LabVIEWIniLocalHostEntries {
    param([string]$IniPath)

    if (-not (Test-Path -LiteralPath $IniPath -PathType Leaf)) {
        return ''
    }

    $entries = Get-Content -LiteralPath $IniPath -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*LocalHost\.LibraryPaths' } |
        ForEach-Object { $_.Trim() }
    return ($entries -join ';')
}

function Get-LabVIEWIniStates {
    param(
        [int]$StartYear = 2018,
        [int]$EndYear = 2030
    )

    $states = @{}
    foreach ($iniPath in Get-LabVIEWIniCandidates -StartYear $StartYear -EndYear $EndYear) {
        $states[$iniPath] = Get-LabVIEWIniLocalHostEntries -IniPath $iniPath
    }
    return $states
}

function Get-LocalHostLibraryPaths {
    param(
        [string]$LvVersion,
        [string]$Bitness
    )
    $iniCandidates = @()
    if ($Bitness -eq '32') {
        if ($programFiles32) { $iniCandidates += (Join-Path $programFiles32 "National Instruments\LabVIEW $LvVersion\LabVIEW.ini") }
        if ($programFiles64) { $iniCandidates += (Join-Path $programFiles64 "National Instruments\LabVIEW $LvVersion (32-bit)\LabVIEW.ini") }
    }
    else {
        if ($programFiles64) { $iniCandidates += (Join-Path $programFiles64 "National Instruments\LabVIEW $LvVersion\LabVIEW.ini") }
    }
    $paths = @()
    foreach ($ini in $iniCandidates) {
        if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { continue }
        try {
            $line = Get-Content -LiteralPath $ini -ErrorAction Stop | Where-Object { $_ -match '^\s*LocalHost\.LibraryPaths\s*=' } | Select-Object -First 1
            if (-not $line) { continue }
            $val = ($line -split '=',2)[1].Trim().Trim('"')
            $paths += ($val -split ';' | ForEach-Object { $_.Trim().Trim('"') }) | Where-Object { $_ -ne '' }
        }
        catch { }
    }
    return $paths
}

function Compare-PathSets {
    param(
        [string[]]$Before,
        [string[]]$After
    )

    $beforeSet = $Before | Select-Object -Unique | Sort-Object
    $afterSet = $After | Select-Object -Unique | Sort-Object
    return ($beforeSet -join ';') -eq ($afterSet -join ';')
}

function Print-LocalHostState {
    param(
        [string]$LvVersion,
        [string]$Bitness
    )
    $iniPaths = Get-LocalHostLibraryPaths -LvVersion $LvVersion -Bitness $Bitness
    $iniPaths = @($iniPaths)
    if (-not $iniPaths -or $iniPaths.Count -eq 0) {
        Write-Host ("LocalHost.LibraryPaths ({0}-bit {1}): NONE" -f $Bitness, $LvVersion) -ForegroundColor Cyan
    }
    else {
        Write-Host ("LocalHost.LibraryPaths ({0}-bit {1}):" -f $Bitness, $LvVersion) -ForegroundColor Yellow
        foreach ($p in $iniPaths | Select-Object -Unique) {
            Write-Host ("  - {0}" -f $p) -ForegroundColor DarkGray
        }
    }
}

$otherBitness = if ($bitness -eq '64') { '32' } else { '64' }
$otherPathsBefore = Get-LocalHostLibraryPaths -LvVersion $lvVersion -Bitness $otherBitness
try {
    $targetedIniPath = Resolve-LVIniPath -LvVersion $lvVersion -Arch $bitness
}
catch {
    $targetedIniPath = $null
}

$labviewIniStatesBefore = Get-LabVIEWIniStates

# If unbinding, prefer to target the exact path currently in LabVIEW.ini for this version/bitness,
# but only if it looks like a real repo (binder script exists). Otherwise fall back to source.
function Test-BinderPresence {
    param([string]$BasePath)
    if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) { return $false }
    $candidates = @(
        Join-Path $BasePath 'scripts/bind-development-mode/BindDevelopmentMode.ps1',
        Join-Path $BasePath '.github/actions/bind-development-mode/BindDevelopmentMode.ps1'
    )
    return $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

$tokenPathsForUnbind = @()
if ($Mode -eq 'unbind') {
    $tokenPathsForUnbind = Get-LocalHostLibraryPaths -LvVersion $lvVersion -Bitness $bitness
    $tokenPathsForUnbind = @($tokenPathsForUnbind)
    if ($tokenPathsForUnbind.Count -gt 0) {
        $chosen = $tokenPathsForUnbind | Select-Object -First 1
        $resolved = $null
        try {
            $resolved = (Resolve-Path -LiteralPath $chosen -ErrorAction Stop).Path
        }
        catch {
            $resolved = $chosen
        }

        if (Test-BinderPresence -BasePath $resolved) {
            $repo = $resolved
            $summaryRoot = $repo
            $worktreePath = $repo
        }
        else {
            Write-Warning ("Token path {0} does not contain bind-development-mode scripts; falling back to source repo {1} for unbind." -f $resolved, $sourceRepo)
        }
    }
}

$phrase = "/devmode $Mode $lvVersion $bitness force"
$summaryPath = Join-Path $summaryRoot 'reports/dev-mode-bind.json'
$summaryDir = Split-Path -Parent $summaryPath
if (-not (Test-Path -LiteralPath $summaryDir)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

# Refresh the summary entry for the target bitness with the current INI token state so DevModeAgentCli
# does not skip work based on stale data.
if ($Mode -eq 'unbind' -and $tokenPathsForUnbind.Count -gt 0) {
    $currentToken = $tokenPathsForUnbind | Select-Object -First 1
    try {
        $currentToken = (Resolve-Path -LiteralPath $currentToken -ErrorAction Stop).Path
    }
    catch { }

    $existingSummary = @()
    try {
        if (Test-Path -LiteralPath $summaryPath) {
            $raw = Get-Content -LiteralPath $summaryPath -Raw -ErrorAction Stop
            $existingSummary = $raw | ConvertFrom-Json
        }
    }
    catch { $existingSummary = @() }
    if ($existingSummary -isnot [System.Array]) { $existingSummary = @($existingSummary) }

    $entry = $existingSummary | Where-Object { $_.bitness -eq $bitness } | Select-Object -First 1
    if (-not $entry) {
        $entry = [pscustomobject]@{
            bitness       = $bitness
            available     = $true
            expected_path = ''
            current_path  = ''
            post_path     = ''
            action        = 'status'
            status        = 'status'
            message       = ''
        }
        $existingSummary += $entry
    }
    $entry.expected_path = $repo
    $entry.current_path = $currentToken
    $entry.post_path = ''
    $entry.action = 'unbind'
    $entry.status = 'status'
    $entry.message = 'Refreshed from LabVIEW.ini before unbind'

    try {
        $json = ConvertTo-Json -InputObject $existingSummary -Depth 5
        Set-Content -LiteralPath $summaryPath -Value $json -Encoding utf8
    }
    catch {
        Write-Warning ("Failed to refresh summary at {0}: {1}" -f $summaryPath, $_.Exception.Message)
    }
}

$cliArgs = @(
    '--phrase', $phrase,
    '--repo', $repo,
    '--summary', $summaryPath,
    '--allow-stale-summary',
    '--expected-version', $lvVersion,
    '--ack-version-mismatch',
    '--execute'
)

function Resolve-DevModeAgentCli {
    $resolver = Join-Path $PSScriptRoot 'common\resolve-repo-cli.ps1'
    if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
        throw "CLI resolver not found at $resolver"
    }
    & $resolver -CliName 'DevModeAgentCli' -RepoPath $repo -SourceRepoPath $sourceRepo -PrintProvenance:$false
}

try {
    $commit = (git -C $repo rev-parse HEAD 2>$null)
}
catch { $commit = $null }

function Write-Field {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Color = 'Gray'
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $padded = $Label.PadRight(27)
    Write-Host ("{0}: {1}" -f $padded, $Value) -ForegroundColor $Color
}

Write-Host "== DevMode context ==" -ForegroundColor DarkCyan
Write-Field -Label 'LabVIEW version (from VIPB)' -Value $lvVersion -Color Cyan
Write-Field -Label 'LabVIEW bitness (from VIPB)' -Value $bitness -Color Cyan
Write-Field -Label 'DevModeAgentCli phrase' -Value $phrase -Color Green
Write-Field -Label 'VIPB path' -Value $vipbPath -Color DarkYellow
Write-Field -Label 'VIPC path' -Value $vipcPath -Color DarkYellow
 $commitValue = if ($commit) { $commit.Trim() } else { '' }
Write-Field -Label 'Commit' -Value $commitValue -Color DarkGray
$worktreeLabel = if ($Mode -eq 'unbind' -and $worktreePath) { $worktreePath } elseif ($createdWorktree -and $worktreePath) { $worktreePath } else { '(none; using source repo)' }
Write-Field -Label 'Worktree' -Value $worktreeLabel -Color DarkCyan
$tokenPathsForUnbind | Select-Object -Unique | ForEach-Object {
    Write-Field -Label 'Token path (ini)' -Value $_ -Color DarkGray
}
$stashHint = Join-Path $repo 'builds/logs'
Write-Field -Label 'Logs/Stash folder' -Value $stashHint -Color DarkYellow

# Optional preclear: force-unbind the VIPB version for both bitnesses to remove stale tokens before bind.
if ($Mode -eq 'bind') {
    $binderPath = Join-Path $repo 'scripts/bind-development-mode/BindDevelopmentMode.ps1'
    if (-not (Test-Path -LiteralPath $binderPath)) {
        $binderPath = Join-Path $repo '.github/actions/bind-development-mode/BindDevelopmentMode.ps1'
    }
    if ($binderPath -and (Test-Path -LiteralPath $binderPath)) {
        Write-Host ("Pre-clearing dev-mode tokens for LabVIEW {0} ({1}-bit)..." -f $lvVersion, $bitness) -ForegroundColor Yellow
        try {
            $preArgs = @(
                '-RepositoryPath', $repo,
                '-Mode', 'unbind',
                '-Bitness', $bitness,
                '-Force',
                '-LabVIEWVersion', $lvVersion
            )
            if (-not $Preclear.IsPresent) {
                # Default is on; only skip when explicitly disabled.
                $preArgs = $null
            }
            if ($preArgs) {
                & pwsh -NoProfile -File $binderPath @preArgs | Out-Null
            }
        }
        catch {
            Write-Warning ("Pre-clear (unbind both) failed: {0}" -f $_.Exception.Message)
        }
    }
}

function Invoke-AgentCli {
    param([string]$Path, [string[]]$CommandArgs)
    Write-Host ("DevModeAgentCli path       : {0}" -f $Path)
    Write-Host ("Args                        : {0}" -f ($CommandArgs -join ' '))
    $out = & $Path @CommandArgs
    $code = $LASTEXITCODE
    $joined = $out -join "`n"

    # Retry via dotnet run if the published binary failed to see the phrase.
    if ($code -ne 0 -and $joined -match 'Missing required --phrase' -and $Path -ne 'dotnet') {
        Write-Warning "DevModeAgentCli reported missing --phrase; retrying via dotnet run..."
        $dotnetArgs = @('run', '--project', $projectPath, '--') + $cliArgs
        return Invoke-AgentCli -Path 'dotnet' -CommandArgs $dotnetArgs
    }

    # Render a compact summary instead of raw JSON, if we can parse it.
    $parsed = $null
    try { $parsed = $joined | ConvertFrom-Json -ErrorAction Stop } catch { }

    if ($parsed) {
        Write-Host "== DevMode result ==" -ForegroundColor DarkCyan
        foreach ($entry in $parsed) {
            $status = $entry.Action
            $color = switch ($status) {
                'completed' { 'Green' }
                'skip'      { 'Yellow' }
                'pending'   { 'Gray' }
                'blocked'   { 'Magenta' }
                'failed'    { 'Red' }
                default     { 'Gray' }
            }
            $label = "{0} {1} {2}-bit" -f $entry.Mode, $entry.Year, ($entry.Bitness)
            $reason = if ($entry.Reason) { $entry.Reason } else { '' }
            $statusText = if ($status) { $status.ToUpper() } else { 'UNKNOWN' }
            Write-Host (" - {0}: {1}" -f $label, $statusText) -ForegroundColor $color
            if ($reason) {
                Write-Host ("   reason: {0}" -f $reason) -ForegroundColor DarkGray
            }
        }

        if ($Mode -eq 'unbind') {
            Print-LocalHostState -LvVersion $lvVersion -Bitness $bitness
        }

        # Surface a clear unbind hint when bind is skipped because it's already bound.
        if ($Mode -eq 'bind') {
            $skips = @($parsed | Where-Object { $_.Action -eq 'skip' -and ($_.Reason -match 'already bound') })
            if ($skips.Count -gt 0) {
                $bits = ($skips | ForEach-Object { $_.BitnessTargets | ForEach-Object { $_ } }) | Select-Object -Unique
                if ($bits) {
                    $bitLabel = ($bits -join '/')
                    Write-Host ("[HINT] Use task '06b DevMode: Unbind (auto)' to clear {0}-bit entries before rebinding." -f $bitLabel) -ForegroundColor Yellow
                }
            }
        }

        $otherPathsAfter = Get-LocalHostLibraryPaths -LvVersion $lvVersion -Bitness $otherBitness
        if (-not (Compare-PathSets -Before $otherPathsBefore -After $otherPathsAfter)) {
            Write-Warning ("Cross-bitness guard violated: {0}-bit entries changed during this run." -f $otherBitness)
        }
    }
    else {
        if ($out) { $out | Write-Output }
        if ($Mode -eq 'unbind') {
            Print-LocalHostState -LvVersion $lvVersion -Bitness $bitness
        }
    }

    $labviewIniStatesAfter = Get-LabVIEWIniStates
    foreach ($entry in $labviewIniStatesBefore.GetEnumerator()) {
        $iniPath = $entry.Key
        if ($targetedIniPath -and ($iniPath -eq $targetedIniPath)) {
            continue
        }

        $beforeValue = $entry.Value
        if (-not $labviewIniStatesAfter.ContainsKey($iniPath)) {
            Write-Warning ("Cross-LabVIEW guard violated: INI {0} vanished during execution." -f $iniPath)
            continue
        }

        $afterValue = $labviewIniStatesAfter[$iniPath]
        if ($beforeValue -ne $afterValue) {
            Write-Warning ("Cross-LabVIEW guard violated: LocalHost.LibraryPaths entries changed for {0} unexpectedly." -f $iniPath)
        }
    }

    exit $code
}

try {
    $prov = Resolve-DevModeAgentCli
    Write-Host ("DevModeAgentCli tier        : {0}" -f $prov.Tier)
    Write-Host ("DevModeAgentCli cache key   : {0}" -f $prov.CacheKey)
    if ($prov.ProjectPath) { Write-Host ("DevModeAgentCli project     : {0}" -f $prov.ProjectPath) }
    if ($prov.BinaryPath) { Write-Host ("DevModeAgentCli binary      : {0}" -f $prov.BinaryPath) }

    $cmd = $prov.Command + $cliArgs
    Invoke-AgentCli -Path $cmd[0] -CommandArgs ($cmd[1..($cmd.Count-1)])
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ($createdWorktree -and $worktreePath) {
        try {
            git -C $worktreePath worktree remove $worktreePath -f 2>$null
        } catch { }
        Remove-Item -LiteralPath $worktreePath -Force -Recurse -ErrorAction SilentlyContinue
    }
}
