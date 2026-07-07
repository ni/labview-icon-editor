<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.
    This version includes additional debug/verbose output.

.EXAMPLE
    .\applyvipc.ps1 -LabVIEWVersion "2021" -SupportedBitness "64" -RepoRoot "C:\release\labview-icon-editor-fork" -VIPCPath "Tooling\deployment\runner_dependencies.vipc" -VIP_LVVersion "2021" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    [AllowNull()]
    [AllowEmptyString()]
    [Alias('MinimumSupportedLVVersion')]
    [string]$LabVIEWVersion = '2021',
    [AllowNull()]
    [AllowEmptyString()]
    [string]$VIP_LVVersion = '2021',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPCPath,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck
)

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - LabVIEWVersion:            $LabVIEWVersion"
Write-Verbose " - VIP_LVVersion:             $VIP_LVVersion"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RepoRoot:              $RepoRoot"
Write-Verbose " - VIPCPath:                  $VIPCPath"

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the 'RepoRoot'..."
    $ResolvedRepoRoot = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    Write-Verbose "ResolvedRepoRoot: $ResolvedRepoRoot"

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

$minInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
$vipInfo = Get-LabVIEWVersionInfo -VersionInput $VIP_LVVersion -RepoRoot $ResolvedRepoRoot

$VIP_LVVersion_B = Get-VipmVersionString -NumericVersion $minInfo.NumericVersion -Bitness $SupportedBitness
$VIP_LVVersion_A = Get-VipmVersionString -NumericVersion $vipInfo.NumericVersion -Bitness $SupportedBitness

Write-Output "Applying dependencies for LabVIEW $VIP_LVVersion_B..."
Write-Verbose "VIP_LVVersion_A (for primary LVVersion): $VIP_LVVersion_A"
Write-Verbose "VIP_LVVersion_B (for minimum LVVersion): $VIP_LVVersion_B"

# -------------------------
# 3) Construct the Commands to Execute
# -------------------------
Write-Verbose "Constructing g-cli vipc command list..."
$vipVersions = @($VIP_LVVersion_B)
if ($vipInfo.NumericVersion -ne $minInfo.NumericVersion -or $vipInfo.Year -ne $minInfo.Year) {
    Write-Verbose "VIP_LVVersion and LabVIEWVersion differ; adding commands for $VIP_LVVersion_A..."
    $vipVersions += $VIP_LVVersion_A
}

# -------------------------
# 4) Execute the Commands & Handle Errors
# -------------------------
try {
    foreach ($vipVersion in $vipVersions) {
        $targetLvVer = if ($vipVersion -eq $VIP_LVVersion_A) { $vipInfo.Year } else { $minInfo.Year }
        $vipcArgs = @(
            '--lv-ver', $targetLvVer,
            '--arch', $SupportedBitness,
            'vipc', '--',
            '-t', '3000',
            '-v', $vipVersion,
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
    }

    $global:LASTEXITCODE = 0
    Write-Host "Successfully applied dependencies to LabVIEW: $VIP_LVVersion_B" `
        " (and potentially $VIP_LVVersion_A if switched)."
}
catch {
    Write-Error "An error occurred while applying the .vipc dependencies. Details: $($_.Exception.Message)"
    exit 1
}
