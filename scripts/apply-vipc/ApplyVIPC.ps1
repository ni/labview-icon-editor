<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.
    This version includes additional debug/verbose output.

.EXAMPLE
    .\applyvipc.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\release\labview-icon-editor-fork" -VIPCPath "Tooling\deployment\runner_dependencies.vipc" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    # Use Package_LabVIEW_Version as the canonical LabVIEW version (alias accepts VIP_LVVersion for compatibility)
    [Parameter(Mandatory)][Alias('VIP_LVVersion')][string]$Package_LabVIEW_Version,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$SupportedBitness,
[Parameter(Mandatory)][string]$RepositoryPath,
[Parameter(Mandatory)][string]$VIPCPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - Package_LabVIEW_Version:   $Package_LabVIEW_Version"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RepositoryPath:            $RepositoryPath"
Write-Verbose " - VIPCPath:                  $VIPCPath"

# Resolve LabVIEW version from VIPB to ensure determinism (ignore inbound override)
try {
    $lvVersionScript = Join-Path $RepositoryPath 'scripts\get-package-lv-version.ps1'
    if (-not (Test-Path $lvVersionScript)) {
        # Fallback to .github/scripts in case the repository layout differs
        $lvVersionScript = Join-Path $RepositoryPath '.github\scripts\get-package-lv-version.ps1'
    }
    if (-not (Test-Path $lvVersionScript)) {
        throw "Unable to locate get-package-lv-version.ps1 under '$RepositoryPath/scripts' or '$RepositoryPath/.github/scripts'."
    }

    $resolvedVersion = & $lvVersionScript -RepositoryPath $RepositoryPath
    if ($Package_LabVIEW_Version -ne $resolvedVersion) {
        Write-Warning ("Overriding inbound LabVIEW version '{0}' with VIPB-derived '{1}'" -f $Package_LabVIEW_Version, $resolvedVersion)
    }
    $Package_LabVIEW_Version = $resolvedVersion
}
catch {
    Write-Error "Failed to resolve LabVIEW version from VIPB: $($_.Exception.Message)"
    exit 1
}

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the repository path..."
    $ResolvedRepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).Path
    Write-Verbose "ResolvedRepositoryPath: $ResolvedRepositoryPath"

    Write-Verbose "Building full path for the .vipc file..."
    if ([System.IO.Path]::IsPathRooted($VIPCPath)) {
        $ResolvedVIPCPath = [System.IO.Path]::GetFullPath($VIPCPath)
    }
    else {
        $ResolvedVIPCPath = Join-Path -Path $ResolvedRepositoryPath -ChildPath $VIPCPath -ErrorAction Stop
    }
    Write-Verbose "ResolvedVIPCPath:     $ResolvedVIPCPath"

    # Verify that the .vipc file actually exists
    Write-Verbose "Checking if the .vipc file exists at the resolved path..."
    if (-not (Test-Path $ResolvedVIPCPath)) {
        Write-Error "The .vipc file does not exist at '$ResolvedVIPCPath'."
        exit 1
    }
    Write-Verbose "The .vipc file was found successfully."

    # Ensure parent directory exists (idempotent if already present)
    $vipcDir = Split-Path -Parent $ResolvedVIPCPath
    if (-not (Test-Path $vipcDir)) {
        Write-Verbose "Creating VIPC parent directory: $vipcDir"
        New-Item -ItemType Directory -Path $vipcDir -Force | Out-Null
    }
}
catch {
    Write-Error "Error resolving paths. Ensure RepositoryPath and VIPCPath are valid. Details: $($_.Exception.Message)"
    exit 1
}

$vipcItem = Get-Item -LiteralPath $ResolvedVIPCPath -ErrorAction Stop
$vipcHash = (Get-FileHash -LiteralPath $ResolvedVIPCPath -Algorithm SHA256 -ErrorAction Stop).Hash
$vipcGitCommit = $null
$vipcGitAuthor = $null
try {
    $gitCmd = Get-Command git -ErrorAction Stop

    $repoPrefix = $ResolvedRepositoryPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $vipcMetadataPaths = @($VIPCPath)

    Push-Location -LiteralPath $ResolvedRepositoryPath
    try {
        foreach ($p in ($vipcMetadataPaths | Select-Object -Unique)) {
            try {
                $full = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
            }
            catch {
                continue
            }

            $relative = $full
            if ($full.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relative = $full.Substring($repoPrefix.Length)
            }

            $commit = & $gitCmd.Path log -1 --format=%H -- $relative 2>$null
            if (-not [string]::IsNullOrWhiteSpace($commit)) {
                $vipcGitCommit = $commit.Trim()
                $author = & $gitCmd.Path log -1 --format=%an -- $relative 2>$null
                if (-not [string]::IsNullOrWhiteSpace($author)) {
                    $vipcGitAuthor = $author.Trim()
                }
                Write-Verbose ("Resolved VIPC git metadata from '{0}'" -f $relative)
                break
            }
        }

        if (-not $vipcGitCommit) {
            Write-Warning "Unable to determine git commit for VIPC path(s): $($vipcMetadataPaths -join ', ')"
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Warning "Could not resolve git commit for VIPC path '$VIPCPath': $($_.Exception.Message)"
}
Write-Information ("Using VIPC '{0}' (size: {1} bytes, last write UTC: {2:o}, sha256: {3}, git commit: {4})" -f $vipcItem.FullName, $vipcItem.Length, $vipcItem.LastWriteTimeUtc, $vipcHash, ($vipcGitCommit ?? 'unknown')) -InformationAction Continue

$ReportPath = Join-Path $PSScriptRoot 'apply_vipc_report.json'
Remove-Item -LiteralPath $ReportPath -ErrorAction SilentlyContinue
$script:Reports = @()

function Write-ReportAndOutputs {
    param([string]$StatusMessage)

    $json = ConvertTo-Json -InputObject $script:Reports -Depth 6
    Set-Content -Path $ReportPath -Value $json -Encoding UTF8
    if (-not (Test-Path -LiteralPath $ReportPath)) {
        throw "Expected to write apply-vipc report, but file was not found at '$ReportPath'."
    }
    Write-Information ("Wrote apply-vipc report to {0}" -f $ReportPath) -InformationAction Continue

    if ($env:GITHUB_OUTPUT) {
        @(
            "summary-json=$ReportPath"
            ("vipc_path={0}" -f $ResolvedVIPCPath)
            ("vipc_sha256={0}" -f $vipcHash)
            ("vipc_size_bytes={0}" -f $vipcItem.Length)
            ("vipc_last_write_utc={0:o}" -f $vipcItem.LastWriteTimeUtc)
            ("vipc_git_commit={0}" -f ($vipcGitCommit ?? 'unknown'))
            ("vipc_git_author={0}" -f ($vipcGitAuthor ?? 'unknown'))
        ) | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }

    if ($env:GITHUB_STEP_SUMMARY) {
        $vipcLeaf = Split-Path -Leaf $ResolvedVIPCPath
        $bitLabel = "x$SupportedBitness"
        $summary = @()
        $summary += ("### {0} ({1})" -f $vipcLeaf, $bitLabel)
        $summary += ""
        $summary += "| Field | Value |"
        $summary += "| --- | --- |"
        if (-not [string]::IsNullOrWhiteSpace($StatusMessage)) {
            $summary += ("| Status | {0} |" -f $StatusMessage)
        }
        $summary += ("| Path | `{0}` |" -f $ResolvedVIPCPath)
        $summary += ("| SHA256 | `{0}` |" -f $vipcHash)
        $summary += ("| Size (bytes) | `{0}` |" -f $vipcItem.Length)
        $summary += ("| Last write (UTC) | `{0}` |" -f $vipcItem.LastWriteTimeUtc.ToString("o"))
        $summary += ("| Git commit | `{0}` |" -f ($vipcGitCommit ?? 'unknown'))
        $summary += ("| Git author | `{0}` |" -f ($vipcGitAuthor ?? 'unknown'))
        $summary += ""
        $summary -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
    }
}

# -------------------------
# 2) Build LabVIEW Version Strings
# -------------------------
Write-Verbose "Determining LabVIEW version strings..."
function Get-LvLabel {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Bitness
    )
    switch ("$Version-$Bitness") {
        "2021-64" { "21.0 (64-bit)" }
        "2021-32" { "21.0" }
        "2022-64" { "22.3 (64-bit)" }
        "2022-32" { "22.3" }
        "2023-64" { "23.3 (64-bit)" }
        "2023-32" { "23.3" }
        "2024-64" { "24.3 (64-bit)" }
        "2024-32" { "24.3" }
        "2025-64" { "25.3 (64-bit)" }
        "2025-32" { "25.3" }
        default {
            Write-Error "Unsupported LabVIEW version/bitness combination: $Version-$Bitness."
            exit 1
        }
    }
}

$VersionLabel = Get-LvLabel -Version $Package_LabVIEW_Version -Bitness $SupportedBitness
Write-Information "Applying dependencies for LabVIEW $VersionLabel..." -InformationAction Continue
Write-Verbose ("Target LabVIEW version: {0}" -f $Package_LabVIEW_Version)

# Sanity check VIPM CLI exists; skip apply if unavailable
$vipmCli = Get-Command vipm -ErrorAction SilentlyContinue
if (-not $vipmCli) {
    Write-Warning "vipm CLI is not available on PATH; skipping VIPC application."
    $script:Reports += [ordered]@{
        target            = $VersionLabel
        lvMajor           = $Package_LabVIEW_Version
        bitness           = $SupportedBitness
        vipcPath          = $ResolvedVIPCPath
        installAttempted  = $false
        skippedReason     = "vipm CLI not available on PATH"
        preMissing        = @()
        preMismatch       = @()
        preExtra          = @()
        postMissing       = @()
        postMismatch      = @()
        postExtra         = @()
    }
    Write-ReportAndOutputs -StatusMessage "Skipped (vipm CLI not available)"
    Write-Information "Skipping dependency application because vipm CLI was not found." -InformationAction Continue
    exit 0
}

# -------------------------
# 3) Construct and execute vipm commands
# -------------------------
Write-Verbose "Constructing the vipm command arguments..."

function Invoke-VipmCommand {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Description,
        [int]$TimeoutSeconds = 600
    )

    $timeoutMs = [Math]::Max(1000, $TimeoutSeconds * 1000)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "vipm"
    $psi.Arguments = ($Arguments -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    Write-Information ("Executing: vipm {0} ({1})" -f ($Arguments -join ' '), $Description) -InformationAction Continue

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    if (-not $proc.Start()) {
        throw "Failed to start vipm for $Description."
    }

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $completed = $proc.WaitForExit($timeoutMs)
    if (-not $completed) {
        try { $proc.Kill($true) } catch { $proc.Kill() }
        throw "vipm $Description timed out after $TimeoutSeconds seconds."
    }
    $proc.WaitForExit()

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    $outLines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        $outLines += $stdout -split "`r?`n"
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $outLines += $stderr -split "`r?`n"
    }

    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
        Output   = $outLines
    }
}

function Is-TransientVipmFailure {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [string[]]$OutputLines
    )

    if ($ExitCode -eq 0) { return $false }
    $joined = if ($OutputLines) { $OutputLines -join ' ' } else { '' }

    if ($joined -match 'VIPM command .*timed out' -or $joined -match 'timed out after') {
        return $true
    }
    if ($joined -match 'library_list' -and $joined -match 'timed out') {
        return $true
    }

    return $false
}

function Invoke-VipmCommandWithRetry {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Description,
        [int]$TimeoutSeconds = 600,
        [int]$MaxAttempts = 3,
        [int]$RetryDelaySeconds = 15
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $attemptLabel = if ($MaxAttempts -gt 1) { " (attempt $attempt/$MaxAttempts)" } else { "" }
        $result = Invoke-VipmCommand -Arguments $Arguments -Description ("{0}{1}" -f $Description, $attemptLabel) -TimeoutSeconds $TimeoutSeconds
        if ($result.ExitCode -eq 0) {
            return $result
        }

        $joined = ($result.Output -join ' ')
        $transient = Is-TransientVipmFailure -ExitCode $result.ExitCode -OutputLines $result.Output
        if ($attempt -lt $MaxAttempts -and $transient) {
            Write-Warning ("vipm {0} failed (attempt {1}/{2}); retrying in {3}s. Output: {4}" -f $Description, $attempt, $MaxAttempts, $RetryDelaySeconds, $joined)
            if ($RetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            continue
        }

        return $result
    }
}

function New-PackageDiff {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Installed
    )

    $missing = @()
    $mismatch = @()
    $extra = @()

    foreach ($pkg in $Expected.Keys) {
        if (-not $Installed.ContainsKey($pkg)) {
            $missing += $pkg
        }
        elseif ($Installed[$pkg] -ne $Expected[$pkg]) {
            $mismatch += ("{0} (expected {1}, installed {2})" -f $pkg, $Expected[$pkg], $Installed[$pkg])
        }
    }

    foreach ($pkg in $Installed.Keys) {
        if (-not $Expected.ContainsKey($pkg)) {
            $extra += ("{0} ({1})" -f $pkg, $Installed[$pkg])
        }
    }

    return @{
        Missing  = $missing
        Mismatch = $mismatch
        Extra    = $extra
    }
}

function Parse-VipmListOutput {
    param([string[]]$Lines)
    $packages = @{}
    foreach ($line in $Lines) {
        # Example: "  Git API (hse_lib_git_api v2.3.4.176)"
        $m = [regex]::Match($line, '\((?<id>[^ )]+)\s+v(?<ver>[^\)]+)\)')
        if ($m.Success) {
            $packages[$m.Groups['id'].Value] = $m.Groups['ver'].Value
        }
    }
    return $packages
}

function Get-VipcPackages {
    param([Parameter(Mandatory)][string]$VipcPath)
    $result = Invoke-VipmCommandWithRetry -Arguments @("list", $VipcPath) -Description "list expected packages from VIPC '$VipcPath'" -MaxAttempts 3 -RetryDelaySeconds 15
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join '; ')
        Write-Error "vipm list failed for VIPC '$VipcPath' (exit $($result.ExitCode)). Output: $joined"
        exit $result.ExitCode
    }
    return Parse-VipmListOutput -Lines $result.Output
}

function Get-InstalledPackages {
    param(
        [Parameter(Mandatory)][string]$LvMajor,
        [Parameter(Mandatory)][string]$Bitness
    )
    $args = @(
        "--labview-version", $LvMajor,
        "--labview-bitness", $Bitness,
        "list",
        "--installed"
    )
    $result = Invoke-VipmCommandWithRetry -Arguments $args -Description "list installed packages for LabVIEW $LvMajor ($Bitness-bit)" -MaxAttempts 3 -RetryDelaySeconds 20
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join '; ')
        Write-Error ("vipm --labview-version {0} --labview-bitness {1} list --installed failed (exit {2}). Output: {3}" -f $LvMajor, $Bitness, $result.ExitCode, $joined)
        exit $result.ExitCode
    }
    return Parse-VipmListOutput -Lines $result.Output
}

function Write-PackageDiff {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Installed,
        [Parameter(Mandatory)][string]$Label
    )

    $diff = New-PackageDiff -Expected $Expected -Installed $Installed
    $missing = $diff.Missing
    $mismatch = $diff.Mismatch
    $extra = $diff.Extra

    if ($missing.Count -eq 0 -and $mismatch.Count -eq 0 -and $extra.Count -eq 0) {
        Write-Information ("Pre-check for {0}: all expected packages present with matching versions." -f $Label) -InformationAction Continue
    }
    else {
        if ($missing.Count -gt 0) {
            Write-Warning ("Pre-check for {0}: missing packages -> {1}" -f $Label, ($missing -join ', '))
        }
        if ($mismatch.Count -gt 0) {
            Write-Warning ("Pre-check for {0}: version mismatches -> {1}" -f $Label, ($mismatch -join '; '))
        }
        if ($extra.Count -gt 0) {
            Write-Information ("Pre-check for {0}: extra installed packages not in VIPC -> {1}" -f $Label, ($extra -join '; ')) -InformationAction Continue
        }
    }

    return $diff
}

function Invoke-VipmInstall {
    param(
        [Parameter(Mandatory)][string]$LvMajor,
        [Parameter(Mandatory)][string]$Bitness,
        [Parameter(Mandatory)][string]$VipcPath,
        [Parameter(Mandatory)][string]$DisplayVersion
    )

    $vipmArgs = @(
        "install",
        "--labview-version", $LvMajor,
        "--labview-bitness", $Bitness,
        $VipcPath
    )

    $result = Invoke-VipmCommandWithRetry -Arguments $vipmArgs -Description "install VIPC for $DisplayVersion" -MaxAttempts 2 -RetryDelaySeconds 20
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join '; ')
        Write-Error "vipm install failed for LabVIEW $DisplayVersion (exit $($result.ExitCode)). Output: $joined"
        exit $result.ExitCode
    }
}

Write-Information "Parsing expected packages from VIPC..." -InformationAction Continue
$expectedPackages = Get-VipcPackages -VipcPath $ResolvedVIPCPath

# Fail fast on required G CLI version before attempting any installs
$gcliId = 'wiresmith_technology_lib_g_cli'
if (-not $expectedPackages.ContainsKey($gcliId)) {
    throw "VIPC does not specify required package '$gcliId' (G CLI); cannot continue."
}
$expectedGcliVersion = $expectedPackages[$gcliId]
$installedSnapshot = Get-InstalledPackages -LvMajor $Package_LabVIEW_Version -Bitness $SupportedBitness
if (-not $installedSnapshot.ContainsKey($gcliId)) {
    throw ("Fail-fast: G CLI package '{0}' is not installed for LabVIEW {1} ({2}-bit); expected version {3}." -f $gcliId, $Package_LabVIEW_Version, $SupportedBitness, $expectedGcliVersion)
}
$installedGcliVersion = $installedSnapshot[$gcliId]
if ($installedGcliVersion -ne $expectedGcliVersion) {
    throw ("Fail-fast: G CLI package '{0}' version mismatch. Expected {1}, found {2}." -f $gcliId, $expectedGcliVersion, $installedGcliVersion)
}
Write-Information ("Validated G CLI ({0}) version {1} is already present; proceeding." -f $gcliId, $installedGcliVersion) -InformationAction Continue

function Apply-ForTarget {
    param(
        [Parameter(Mandatory)][string]$LvMajor,
        [Parameter(Mandatory)][string]$DisplayVersion
    )

    $label = "$DisplayVersion"
    Write-Information "Preflight package diff for $label..." -InformationAction Continue
    $installedBefore = Get-InstalledPackages -LvMajor $LvMajor -Bitness $SupportedBitness
    $pre = Write-PackageDiff -Expected $expectedPackages -Installed $installedBefore -Label $label

    $installAttempted = $true
    if ($pre.Missing.Count -eq 0 -and $pre.Mismatch.Count -eq 0) {
        Write-Information ("No missing/mismatched packages detected for {0}; skipping vipm install (pre-check clean)." -f $label) -InformationAction Continue
        $installAttempted = $false
    }
    else {
        Invoke-VipmInstall -LvMajor $LvMajor -Bitness $SupportedBitness -VipcPath $ResolvedVIPCPath -DisplayVersion $DisplayVersion
    }

    Write-Information "Post-apply verification for $label..." -InformationAction Continue
    $installedAfter = Get-InstalledPackages -LvMajor $LvMajor -Bitness $SupportedBitness
    $post = Write-PackageDiff -Expected $expectedPackages -Installed $installedAfter -Label "$label (post)"

    $script:Reports += [ordered]@{
        target            = $label
        lvMajor           = $LvMajor
        bitness           = $SupportedBitness
        vipcPath          = $ResolvedVIPCPath
        installAttempted  = $installAttempted
        preMissing        = $pre.Missing
        preMismatch       = $pre.Mismatch
        preExtra          = $pre.Extra
        postMissing       = $post.Missing
        postMismatch      = $post.Mismatch
        postExtra         = $post.Extra
    }

    if ($post.Missing.Count -gt 0 -or $post.Mismatch.Count -gt 0) {
        if (-not $installAttempted) {
            Write-Warning ("Post-check found missing/mismatched packages for {0} despite clean pre-check; forcing vipm install and re-verifying." -f $label)
            Invoke-VipmInstall -LvMajor $LvMajor -Bitness $SupportedBitness -VipcPath $ResolvedVIPCPath -DisplayVersion $DisplayVersion
            $installedAfter = Get-InstalledPackages -LvMajor $LvMajor -Bitness $SupportedBitness
            $post = Write-PackageDiff -Expected $expectedPackages -Installed $installedAfter -Label "$label (post-retry)"
        }

        if ($post.Missing.Count -gt 0 -or $post.Mismatch.Count -gt 0) {
            Write-Error ("After vipm install, packages are still missing or mismatched for {0}. Missing: {1}; Mismatched: {2}" -f $label, ($post.Missing -join ', '), ($post.Mismatch -join '; '))
            exit 1
        }
    }
}

Apply-ForTarget -LvMajor $Package_LabVIEW_Version -DisplayVersion $VersionLabel

Write-ReportAndOutputs
Write-Information "Successfully applied dependencies to LabVIEW." -InformationAction Continue
