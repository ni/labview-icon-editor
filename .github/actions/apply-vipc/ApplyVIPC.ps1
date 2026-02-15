<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.
    This version includes additional debug/verbose output.

.EXAMPLE
    .\applyvipc.ps1 -LabVIEWVersion "2021" -SupportedBitness "64" -RepoRoot "C:\release\labview-icon-editor-fork" -VIPCPath "Tooling\deployment\runner_dependencies.vipc" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPCPath,
    [switch]$AllowVipcTargetMismatch,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck
)

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - LabVIEWVersion:            $LabVIEWVersion"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RepoRoot:              $RepoRoot"
Write-Verbose " - VIPCPath:                  $VIPCPath"
Write-Verbose " - AllowVipcTargetMismatch:   $AllowVipcTargetMismatch"

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the 'RepoRoot'..."
    $ResolvedRepoRoot = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    Write-Verbose "ResolvedRepoRoot: $ResolvedRepoRoot"

    if ([string]::IsNullOrWhiteSpace($LabVIEWVersion)) {
        $versionHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
        if (-not (Test-Path -Path $versionHelper)) {
            throw "LabVIEW version helper not found at $versionHelper"
        }
        . $versionHelper

        $lvInfoFallback = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
        $LabVIEWVersion = $lvInfoFallback.Raw
        if ($PSBoundParameters -ne $null) {
            $PSBoundParameters['LabVIEWVersion'] = $LabVIEWVersion
        }
        Write-Warning "LabVIEWVersion was not provided; defaulting to .lvversion ($LabVIEWVersion)."
    } else {
        $versionHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
        if (-not (Test-Path -Path $versionHelper)) {
            throw "LabVIEW version helper not found at $versionHelper"
        }
        . $versionHelper
        $repoInfo = Get-LabVIEWVersionInfo -RepoRoot $ResolvedRepoRoot
        $inputInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
        if ($repoInfo.Year -ne $inputInfo.Year -or $repoInfo.MinorRevision -ne $inputInfo.MinorRevision) {
            throw "LabVIEWVersion '$($inputInfo.Raw)' does not match .lvversion '$($repoInfo.Raw)'."
        }
    }

    $preflightScript = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\Invoke-Preflight.ps1'
    if (Test-Path -Path $preflightScript) {
        . $preflightScript
        $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
        $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $ResolvedRepoRoot -Path $PSCommandPath } else { $null }
        $preflight = Invoke-Preflight `
            -RepoRoot $ResolvedRepoRoot `
            -WorktreeRoot $WorktreeRoot `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $SupportedBitness `
            -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
            -AutoWorktree:$false `
            -ScriptPath $relativeScript `
            -ScriptArguments $scriptArgs
        if ($preflight.Reinvoked) {
            return
        }
        $ResolvedRepoRoot = $preflight.RepoRoot
    }

    Write-Verbose "Building full path for the .vipc file..."
    $ResolvedVIPCPath = Join-Path -Path $ResolvedRepoRoot -ChildPath $VIPCPath -ErrorAction Stop
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
    Write-Error "Error resolving paths. Ensure RepoRoot and VIPCPath are valid. Details: $($_.Exception.Message)"
    exit 1
}

# -------------------------
# 2) Build LabVIEW Version Strings
# -------------------------
Write-Verbose "Determining LabVIEW version strings..."

function Get-VipmVersionString {
    param(
        [string]$NumericVersion,
        [string]$Bitness
    )

    if ($Bitness -eq '64') {
        return "$NumericVersion (64-bit)"
    }
    return $NumericVersion
}

$versionHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
if (-not (Test-Path -Path $versionHelper)) {
    throw "LabVIEW version helper not found at $versionHelper"
}
. $versionHelper

$lvInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
$vipmVersion = Get-VipmVersionString -NumericVersion $lvInfo.NumericVersion -Bitness $SupportedBitness
$targetLvVer = $lvInfo.Year

# -------------------------
# 3) VIPC target version guard
# -------------------------
try {
    $vipcConfigHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\VipcConfig.ps1'
    if (-not (Test-Path -Path $vipcConfigHelper)) {
        throw "VIPC config helper not found at $vipcConfigHelper"
    }
    . $vipcConfigHelper

    $vipcConfig = Get-VipcConfigInfo -VipcPath $ResolvedVIPCPath
    Write-Verbose ("VIPC target name: {0}" -f $vipcConfig.TargetName)
    Write-Verbose ("VIPC target version (raw): {0}" -f $vipcConfig.TargetVersionRaw)
    Write-Verbose ("VIPC target version (numeric): {0}" -f $vipcConfig.TargetVersionNumeric)
    Write-Verbose ("VIPC package count: {0}" -f $vipcConfig.PackageCount)

    if (-not $AllowVipcTargetMismatch -and $vipcConfig.TargetVersionNumeric -ne $lvInfo.NumericVersion) {
        throw ("VIPC target version mismatch. Requested LabVIEW numeric version: {0}. VIPC target version: {1} (raw: {2}). Command not executed. To bypass this guard for diagnostics only, pass -AllowVipcTargetMismatch." -f $lvInfo.NumericVersion, $vipcConfig.TargetVersionNumeric, $vipcConfig.TargetVersionRaw)
    }

    if ($AllowVipcTargetMismatch -and $vipcConfig.TargetVersionNumeric -ne $lvInfo.NumericVersion) {
        Write-Warning ("Proceeding despite VIPC target/version mismatch due to -AllowVipcTargetMismatch. Requested={0}; VIPC target={1} (raw: {2})." -f $lvInfo.NumericVersion, $vipcConfig.TargetVersionNumeric, $vipcConfig.TargetVersionRaw)
    }
}
catch {
    Write-Error "An error occurred while validating VIPC target metadata. Details: $($_.Exception.Message)"
    exit 1
}

Write-Output "Applying dependencies for LabVIEW $vipmVersion..."
Write-Verbose "VIPM version string: $vipmVersion"

# -------------------------
# 4) Execute the Commands & Handle Errors
# -------------------------
try {
    $vipcArgs = @(
        '--lv-ver', $targetLvVer,
        '--arch', $SupportedBitness,
        'vipc', '--',
        '-t', '3000',
        '-v', $vipmVersion,
        $ResolvedVIPCPath
    )

    Write-Output ("Executing: g-cli {0}" -f ($vipcArgs -join ' '))
    $output = & g-cli @vipcArgs 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }

    if ($exitCode -ne 0) {
        throw "g-cli vipc failed with exit code $exitCode."
    }

    try {
        Write-Output ("Closing LabVIEW {0} ({1}-bit) after VIPC apply..." -f $targetLvVer, $SupportedBitness)
        & g-cli --lv-ver $targetLvVer --arch $SupportedBitness QuitLabVIEW | Out-Null
    }
    catch {
        Write-Warning ("Failed to close LabVIEW {0} ({1}-bit): {2}" -f $targetLvVer, $SupportedBitness, $_.Exception.Message)
    }

    $global:LASTEXITCODE = 0
    Write-Host "Successfully applied dependencies to LabVIEW: $vipmVersion"
}
catch {
    Write-Error "An error occurred while applying the .vipc dependencies. Details: $($_.Exception.Message)"
    exit 1
}
