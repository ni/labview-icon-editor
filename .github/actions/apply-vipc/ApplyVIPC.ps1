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
    $ResolvedRepositoryPath = Resolve-Path -Path $RepositoryPath -ErrorAction Stop
    Write-Verbose "ResolvedRepositoryPath: $ResolvedRepositoryPath"

    Write-Verbose "Building full path for the .vipc file..."
    $ResolvedVIPCPath = Join-Path -Path $ResolvedRepositoryPath -ChildPath $VIPCPath -ErrorAction Stop
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

# Sanity check VIPM CLI exists
$vipmCli = Get-Command vipm -ErrorAction SilentlyContinue
if (-not $vipmCli) {
    Write-Error "vipm CLI is not available on PATH; cannot apply VIPC."
    exit 1
}

$ReportPath = Join-Path $PSScriptRoot 'apply_vipc_report.json'
Remove-Item -LiteralPath $ReportPath -ErrorAction SilentlyContinue
$Reports = @()

# -------------------------
# 3) Construct and execute vipm commands
# -------------------------
Write-Verbose "Constructing the vipm command arguments..."

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
    $out = & vipm list $VipcPath 2>&1
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        $joined = ($out -join '; ')
        Write-Error "vipm list failed for VIPC '$VipcPath' (exit $exit). Output: $joined"
        exit $exit
    }
    return Parse-VipmListOutput -Lines $out
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
    $out = & vipm @args 2>&1
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        $joined = ($out -join '; ')
        Write-Error "vipm list --installed failed for LabVIEW $LvMajor ($Bitness-bit) (exit $exit). Output: $joined"
        exit $exit
    }
    return Parse-VipmListOutput -Lines $out
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

    Write-Information ("Executing: vipm {0} (display target: {1})" -f ($vipmArgs -join ' '), $DisplayVersion) -InformationAction Continue
    $out = & vipm @vipmArgs 2>&1
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        $joined = ($out -join '; ')
        Write-Error "vipm install failed for LabVIEW $DisplayVersion (exit $exit). Output: $joined"
        exit $exit
    }
}

Write-Information "Parsing expected packages from VIPC..." -InformationAction Continue
$expectedPackages = Get-VipcPackages -VipcPath $ResolvedVIPCPath

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
        Write-Information ("No missing/mismatched packages detected for {0}; skipping vipm install." -f $label) -InformationAction Continue
        $installAttempted = $false
    }
    else {
        Invoke-VipmInstall -LvMajor $LvMajor -Bitness $SupportedBitness -VipcPath $ResolvedVIPCPath -DisplayVersion $DisplayVersion
    }

    Write-Information "Post-apply verification for $label..." -InformationAction Continue
    $installedAfter = Get-InstalledPackages -LvMajor $LvMajor -Bitness $SupportedBitness
    $post = Write-PackageDiff -Expected $expectedPackages -Installed $installedAfter -Label "$label (post)"

    $Reports += [ordered]@{
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
        Write-Error ("After vipm install, packages are still missing or mismatched for {0}. Missing: {1}; Mismatched: {2}" -f $label, ($post.Missing -join ', '), ($post.Mismatch -join '; '))
        exit 1
    }
}

Apply-ForTarget -LvMajor $Package_LabVIEW_Version -DisplayVersion $VersionLabel

$Reports | ConvertTo-Json -Depth 6 | Set-Content -Path $ReportPath -Encoding UTF8
if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "summary-json=$ReportPath"
}

Write-Information "Successfully applied dependencies to LabVIEW." -InformationAction Continue
