<#
.SYNOPSIS
  This script automates the build process for the LabVIEW Icon Editor project.
  It performs the following tasks:
    1. Cleans up old .lvlibp files in the plugins folder.
    2. Applies VIPC (32-bit and 64-bit).
    3. Builds the LabVIEW library (32-bit and 64-bit).
    4. Closes LabVIEW (32-bit and 64-bit).
    5. Renames the built files.
    6. Builds the VI package (64-bit) with DisplayInformationJSON fields.
    7. Closes LabVIEW (64-bit).

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

    [ValidateSet('both','64')]
    [string]$LvlibpBitness = 'both',

[string]$VIPBPath = 'Tooling\deployment\seed.vipb',

    # New parameters that will populate the JSON fields
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

[Parameter(Mandatory = $true)]
    [string]$AuthorName,

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

$hasStyle = ($PSStyle -ne $null)
$bitnessPalette = @{
    '32' = if ($hasStyle) { $PSStyle.Foreground.BrightCyan } else { '' }
    '64' = if ($hasStyle) { $PSStyle.Foreground.BrightMagenta } else { '' }
}
$resetColor = if ($hasStyle) { $PSStyle.Reset } else { '' }
function Show-BitnessBanner {
    param([string]$Arch)
    $color = $bitnessPalette[$Arch]
    Write-Host ("{0}==== {1}-bit build phase ===={2}" -f $color, $Arch, $resetColor)
}

function Show-BitnessDone {
    param([string]$Arch)
    $color = $bitnessPalette[$Arch]
    Write-Host ("{0}---- {1}-bit phase complete ----{2}" -f $color, $Arch, $resetColor)
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

    $label = if ([string]::IsNullOrWhiteSpace($DisplayName)) { Split-Path -Leaf $ScriptPath } else { $DisplayName }
    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        if ($TimeoutSec -gt 0) {
            $job = Start-Job -ScriptBlock {
                param($p,$argMap,$argList,$useMap)
                if ($useMap) { & $p @argMap } elseif ($argList) { & $p @argList } else { & $p }
                [pscustomobject]@{ ExitCode = $LASTEXITCODE }
            } -ArgumentList @($ScriptPath,$ArgumentMap,$ArgumentList, [bool]$ArgumentMap)
            if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
                Stop-Job $job -Force | Out-Null
                Receive-Job $job -Keep | ForEach-Object { Write-Host $_ }
                throw ("{0} timed out after {1} seconds (possible UI prompt or hang)." -f $label, $TimeoutSec)
            }
            $output = Receive-Job $job -Wait -AutoRemoveJob
            $exitObj = $output | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties['ExitCode'] }
            ($output | Where-Object { -not ($_ -is [pscustomobject]) }) | ForEach-Object { Write-Host $_ }
            $exitCode = if ($exitObj) { $exitObj.ExitCode } else { 0 }
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

    $defaultPath = if ($Bitness -eq '32') {
        "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.exe"
    }
    else {
        "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.exe"
    }

    $candidate = if ($PathOverride) { $PathOverride } else { $defaultPath }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw ("LabVIEW {0}-bit executable not found at '{1}'. Set ExpectedLabVIEWPath{0} or install LabVIEW {2} for {0}-bit." -f $Bitness, $candidate, $LvVersion)
    }
    Write-Information ("Validated LabVIEW {0}-bit at {1}" -f $Bitness, $candidate) -InformationAction Continue
}

function Assert-VipmAccess {
    param(
        [Parameter(Mandatory)][string]$LvMajor,
        [Parameter(Mandatory)][string]$Bitness
    )

    $args = @("--labview-version", $LvMajor, "--labview-bitness", $Bitness, "list", "--installed")
    Write-Information ("Sanity: vipm {0}" -f ($args -join ' ')) -InformationAction Continue
    $result = & vipm @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        $joined = ($result -join '; ')
        throw ("vipm list --installed failed for LabVIEW {0} ({1}-bit). Output: {2}" -f $LvMajor, $Bitness, $joined)
    }
}

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
    if ($entries.Count -eq 0) {
        # None present; fine to proceed
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
    if ($entries.Count -gt 0) {
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

    # Ensure the repo root exists before reading the VIPB version
    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        Write-Error "RepositoryPath does not exist: $RepositoryPath"
        exit 1
    }

    $vipmCommand = Get-Command vipm -ErrorAction SilentlyContinue
    $vipmAvailable = [bool]$vipmCommand
    if (-not $vipmAvailable) {
        Write-Warning "vipm CLI not found on PATH; will skip VIPC application and VI Package build, but continue with missing-in-project checks and lvlibp build steps."
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
            git -C $RepositoryPath fetch --unshallow 2>$null | Out-Null
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

    # Validate needed folders after version is known
    Test-PathExistence $RepositoryPath "RepositoryPath"
    Test-PathExistence "$RepositoryPath\resource\plugins" "Plugins folder"
    Test-PathExistence "$RepositoryPath\lv_icon_editor.lvproj" "LabVIEW project"

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Test-PathExistence $ActionsPath "Actions folder"

    # Ensure VIPC dependencies exist (mirrors CI prep). Only use the canonical VIPC under scripts/apply-vipc.
    $vipcPath = Get-CanonicalVipcPath -RepoPath $RepositoryPath
    $SetDevMode = Join-Path $RepositoryPath "scripts/set-development-mode/Set_Development_Mode.ps1"
    $BindDevMode = Join-Path $RepositoryPath "scripts/bind-development-mode/BindDevelopmentMode.ps1"
    $RunUnitTestsSingle = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"

    # 1) Clean up old .lvlibp in the plugins folder
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

    $ApplyVIPC = Join-Path $RepositoryPath "scripts/apply-vipc/ApplyVIPC.ps1"
    $MissingHelper = Join-Path $RepositoryPath "scripts/missing-in-project/Invoke-MissingInProjectCLI.ps1"
    $BuildLvlibp = Join-Path $ActionsPath "build-lvlibp/Build_lvlibp.ps1"
    $CloseLabVIEW = Join-Path $RepositoryPath "scripts/close-labview/Close_LabVIEW.ps1"
    $RenameFile = Join-Path $ActionsPath "rename-file/Rename-file.ps1"

    $do32 = ($LvlibpBitness -eq 'both' -or $LvlibpBitness -eq '32')
    $do64 = ($LvlibpBitness -eq 'both' -or $LvlibpBitness -eq '64')

    if ($do32 -and -not $do64) {
        Show-BitnessBanner -Arch '32'
        # 2) Apply VIPC (32-bit)
        if ($vipmAvailable) {
            Write-Information "Applying VIPC (dependencies) for 32-bit..." -InformationAction Continue
            # Ensure LocalHost.LibraryPaths does not exist before applying dependencies
            Ensure-LibraryPathsAbsent -RepoPath $RepositoryPath -Bitness '32' -BindScript $BindDevMode -LvVersion $lvVersion
            Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentMap @{
                Package_LabVIEW_Version   = $lvVersion
                SupportedBitness          = '32'
                RepositoryPath            = $RepositoryPath
                VIPCPath                  = $vipcPath
            } -TimeoutSec 600 -DisplayName "Apply VIPC (32-bit)"

            # Rebind dev mode for this repo so downstream checks (missing-in-project/tests) have tokens set
            Invoke-ScriptSafe -ScriptPath $BindDevMode -ArgumentMap @{
                RepositoryPath = $RepositoryPath
                Mode           = 'bind'
                Bitness        = '32'
                Force          = $true
            } -DisplayName "Dev mode bind (32-bit)"
        }
        else {
            Write-Warning "Skipping VIPC application for 32-bit because vipm CLI is not available."
        }

        # Ensure LabVIEW is closed before running missing-in-project to avoid UI prompts/locks
        Write-Verbose "Pre-missing-in-project: closing LabVIEW (32-bit) to ensure a clean session..."
        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '32'
        } -TimeoutSec 180 -DisplayName "Close LabVIEW (pre-missing 32-bit)"

        # Ensure LocalHost.LibraryPaths exist before missing-in-project
        Ensure-LibraryPathsReady -RepoPath $RepositoryPath -Bitness '32' -DevModeScript $SetDevMode

        # 2.1) Preflight missing items using existing missing-in-project helper (32-bit)
        Write-Information "Preflight: checking for missing project items via missing-in-project..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $MissingHelper -ArgumentMap @{
            LVVersion   = $lvVersion
            Arch        = '32'
            ProjectFile = (Join-Path $RepositoryPath 'lv_icon_editor.lvproj')
        } -TimeoutSec 300 -DisplayName "Missing in project (32-bit)"

        # 2.2) Run unit tests for 32-bit immediately after missing-in-project
        Write-Information "Running unit tests (32-bit)..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $RunUnitTestsSingle -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '32'
            AbsoluteProjectPath     = (Join-Path $RepositoryPath 'lv_icon_editor.lvproj')
        } -TimeoutSec 1200 -DisplayName "Unit tests (32-bit)"

        # Close LabVIEW (32-bit) post-tests
        Write-Verbose "Closing LabVIEW (32-bit) after tests..." -Verbose
        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '32'
        } -TimeoutSec 180 -DisplayName "Close LabVIEW (post-tests 32-bit)"
    }
    else {
        Write-Information "Skipping 32-bit dependency/apply/build steps (LvlibpBitness=$LvlibpBitness)." -InformationAction Continue
    }

    if ($do64) {
        # 6) Apply VIPC (64-bit)
        Show-BitnessBanner -Arch '64'
        if ($vipmAvailable) {
            Write-Information "Applying VIPC (dependencies) for 64-bit..." -InformationAction Continue
            # Ensure LocalHost.LibraryPaths does not exist before applying dependencies
            Ensure-LibraryPathsAbsent -RepoPath $RepositoryPath -Bitness '64' -BindScript $BindDevMode -LvVersion $lvVersion
            Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentMap @{
                Package_LabVIEW_Version   = $lvVersion
                SupportedBitness          = '64'
                RepositoryPath            = $RepositoryPath
                VIPCPath                  = $vipcPath
            } -TimeoutSec 600 -DisplayName "Apply VIPC (64-bit)"

            # Rebind dev mode for this repo so downstream checks (missing-in-project/tests) have tokens set
            Invoke-ScriptSafe -ScriptPath $BindDevMode -ArgumentMap @{
                RepositoryPath = $RepositoryPath
                Mode           = 'bind'
                Bitness        = '64'
                Force          = $true
            } -DisplayName "Dev mode bind (64-bit)"
        }
        else {
            Write-Warning "Skipping VIPC application for 64-bit because vipm CLI is not available."
        }

        # Ensure LabVIEW is closed before running missing-in-project to avoid UI prompts/locks
        Write-Verbose "Pre-missing-in-project: closing LabVIEW (64-bit) to ensure a clean session..."
        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '64'
        } -TimeoutSec 180 -DisplayName "Close LabVIEW (pre-missing 64-bit)"

        # Ensure LocalHost.LibraryPaths exist before missing-in-project
        Ensure-LibraryPathsReady -RepoPath $RepositoryPath -Bitness '64' -DevModeScript $SetDevMode

        # 6.1) Preflight missing items using existing missing-in-project helper (64-bit)
        Write-Information "Preflight: checking for missing project items via missing-in-project..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $MissingHelper -ArgumentMap @{
            LVVersion   = $lvVersion
            Arch        = '64'
            ProjectFile = (Join-Path $RepositoryPath 'lv_icon_editor.lvproj')
        } -TimeoutSec 300 -DisplayName "Missing in project (64-bit)"

        # 6.2) Run unit tests (64-bit) immediately after missing-in-project
        Write-Information "Running unit tests (64-bit)..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $RunUnitTestsSingle -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '64'
            AbsoluteProjectPath     = (Join-Path $RepositoryPath 'lv_icon_editor.lvproj')
        } -TimeoutSec 1200 -DisplayName "Unit tests (64-bit)"
    }

    # 7) Build LV Library (64-bit) first
    Write-Verbose "Pre-build: closing LabVIEW (64-bit) to ensure a clean session..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    } -TimeoutSec 180 -DisplayName "Close LabVIEW (pre-build 64-bit)"
    Show-BitnessBanner -Arch '64'
    Write-Verbose "Building LV library (64-bit)..."
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
    Invoke-ScriptSafe -ScriptPath $BuildLvlibp -ArgumentMap $argsLvlibp64 -TimeoutSec 900 -DisplayName "Build icon PPL (64-bit)"

    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    } -TimeoutSec 180 -DisplayName "Close LabVIEW (post-build 64-bit)"

    Write-Verbose "Renaming .lvlibp file to lv_icon_x64.lvlibp..."
    Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
        CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
        NewFilename     = 'lv_icon_x64.lvlibp'
    }
    Show-BitnessDone -Arch '64'

    # 8) Build LV Library (32-bit) after 64-bit succeeds
    if ($LvlibpBitness -eq 'both') {
        Show-BitnessBanner -Arch '32'
        Write-Verbose "Building LV library (32-bit)..."
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
        Invoke-ScriptSafe -ScriptPath $BuildLvlibp -ArgumentMap $argsLvlibp32 -TimeoutSec 900 -DisplayName "Build icon PPL (32-bit)"

        Write-Verbose "Closing LabVIEW (32-bit)..."
        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '32'
        } -TimeoutSec 180 -DisplayName "Close LabVIEW (32-bit)"

        Write-Verbose "Renaming .lvlibp file to lv_icon_x86.lvlibp..."
        Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
            CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
            NewFilename     = 'lv_icon_x86.lvlibp'
        }
        Show-BitnessDone -Arch '32'
    }

    # 9) Final staging of neutral and suffixed PPLs after both builds
    try {
        $pplDir    = Join-Path $RepositoryPath 'resource\plugins'
        $pplX64    = Join-Path $pplDir 'lv_icon_x64.lvlibp'
        $pplX86    = Join-Path $pplDir 'lv_icon_x86.lvlibp'
        $neutral   = Join-Path $pplDir 'lv_icon.lvlibp'
        $win64Copy = Join-Path $pplDir 'lv_icon.lvlibp.windows_x64'
        $win86Copy = Join-Path $pplDir 'lv_icon.lvlibp.windows_x86'

        if (Test-Path -LiteralPath $pplX64) {
            Copy-Item -LiteralPath $pplX64 -Destination $neutral -Force
            Copy-Item -LiteralPath $pplX64 -Destination $win64Copy -Force
            Write-Information "Staged neutral and windows_x64 PPLs at $pplDir" -InformationAction Continue
        }
        else {
            Write-Warning "x64 PPL not found at $pplX64; skipping neutral/windows_x64 staging."
        }

        if (Test-Path -LiteralPath $pplX86) {
            Copy-Item -LiteralPath $pplX86 -Destination $win86Copy -Force
            Write-Information "Staged windows_x86 PPL at $pplDir" -InformationAction Continue
        }
        else {
            Write-Warning "x86 PPL not found at $pplX86; skipping windows_x86 staging."
        }
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
        if (Test-Path -LiteralPath (Join-Path $RepositoryPath 'resource\plugins\lv_icon_x86.lvlibp')) {
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
    $expectedPpls = @('lv_icon.lvlibp','lv_icon.lvlibp.windows_x64','lv_icon.lvlibp.windows_x86')
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
        "Product Homepage (URL)"          = "https://github.com/LabVIEW-Community-CI-CD/labview-icon-editor"
        "Legal Copyright"                 = "LabVIEW-Community-CI-CD"
        "License Agreement Name"          = ""
        "Product Description Summary"     = "Community icon editor for LabVIEW"
        "Product Description"             = "Community-driven icon editor for LabVIEW including custom icon APIs."
        "Release Notes - Change Log"      = ""
    }

    $DisplayInformationJSON = $jsonObject | ConvertTo-Json -Depth 3

    # 9) Modify VIPB Display Information
    Write-Verbose "Modify VIPB Display Information (64-bit)..."
    $ModifyVIPB = Join-Path $ActionsPath "modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
    Invoke-ScriptSafe -ScriptPath $ModifyVIPB -ArgumentMap @{
        SupportedBitness         = '64'
        RepositoryPath           = $RepositoryPath
        VIPBPath                 = $VIPBPath
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

    # Guard: ensure 32-bit LabVIEW is not running before invoking VIPM packaging
    Write-Verbose "Pre-VIPM: closing LabVIEW (32-bit) to avoid cross-bitness interference..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '32'
    } -TimeoutSec 120 -DisplayName "Close LabVIEW (pre-VIPM 32-bit)"

    $vipOutputDir = Join-Path $RepositoryPath 'builds\VI Package'
    # 11) Build VI Package (64-bit) 2023
    if ($vipmAvailable) {
        Write-Verbose "Building VI Package (64-bit)..."
        $BuildVip = Join-Path $ActionsPath "build-vip/build_vip.ps1"
        Invoke-ScriptSafe -ScriptPath $BuildVip -ArgumentMap @{
            SupportedBitness         = '64'
            RepositoryPath           = $RepositoryPath
            VIPBPath                 = $VIPBPath
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
    }
    else {
        Write-Warning "Skipping VI Package build because vipm CLI is not available."
        try {
            if (-not (Test-Path -LiteralPath $vipOutputDir)) {
                New-Item -ItemType Directory -Path $vipOutputDir -Force | Out-Null
            } else {
                # Clear stale artifacts so downstream checks don't pick up an old VIP
                Get-ChildItem -LiteralPath $vipOutputDir -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            $placeholderVip = Join-Path $vipOutputDir 'vipm-skipped-placeholder.vip'
            "VIPM build skipped because vipm CLI is not available on this runner." | Set-Content -LiteralPath $placeholderVip -Encoding UTF8
            Write-Information ("Created placeholder VIP artifact at {0} (vipm missing)" -f $placeholderVip) -InformationAction Continue
        }
        catch {
            Write-Warning ("Failed to create placeholder VIP output: {0}" -f $_.Exception.Message)
        }
    }

    # 12) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    }

    Write-Information "All scripts executed successfully!" -InformationAction Continue
    Write-Verbose "Script: Build.ps1 completed without errors."
}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
}
