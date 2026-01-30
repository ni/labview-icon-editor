<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.
    This version includes additional debug/verbose output.

.EXAMPLE
    .\applyvipc.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RepoRoot "C:\release\labview-icon-editor-fork" -VIPCPath "Tooling\deployment\runner_dependencies.vipc" -VIP_LVVersion "2021" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',
    [ValidateSet('2021')]
    [string]$VIP_LVVersion = '2021',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPCPath
)

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - MinimumSupportedLVVersion: $MinimumSupportedLVVersion"
Write-Verbose " - VIP_LVVersion:             $VIP_LVVersion"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RepoRoot:              $RepoRoot"
Write-Verbose " - VIPCPath:                  $VIPCPath"

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the 'RepoRoot'..."
    $ResolvedRepoRoot = Resolve-Path -Path $RepoRoot -ErrorAction Stop
    Write-Verbose "ResolvedRepoRoot: $ResolvedRepoRoot"

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
switch ("$VIP_LVVersion-$SupportedBitness") {
    "2021-64" { $VIP_LVVersion_A = "21.0 (64-bit)" }
    "2021-32" { $VIP_LVVersion_A = "21.0" }
    default {
        Write-Error "Only LabVIEW 2021 (21.0) is supported for VIPC application."
        exit 1
    }
}

switch ("$MinimumSupportedLVVersion-$SupportedBitness") {
    "2021-64" { $VIP_LVVersion_B = "21.0 (64-bit)" }
    "2021-32" { $VIP_LVVersion_B = "21.0" }
    default {
        Write-Error "Only LabVIEW 2021 (21.0) is supported for VIPC application."
        exit 1
    }
}

Write-Output "Applying dependencies for LabVIEW $VIP_LVVersion_B..."
Write-Verbose "VIP_LVVersion_A (for primary LVVersion): $VIP_LVVersion_A"
Write-Verbose "VIP_LVVersion_B (for minimum LVVersion): $VIP_LVVersion_B"

# -------------------------
# 3) Construct the Commands to Execute
# -------------------------
Write-Verbose "Constructing g-cli vipc command list..."
$vipVersions = @($VIP_LVVersion_B)
if ($VIP_LVVersion -ne $MinimumSupportedLVVersion) {
    Write-Verbose "VIP_LVVersion and MinimumSupportedLVVersion differ; adding commands for $VIP_LVVersion_A..."
    $vipVersions += $VIP_LVVersion_A
}

# -------------------------
# 4) Execute the Commands & Handle Errors
# -------------------------
try {
    foreach ($vipVersion in $vipVersions) {
        $targetLvVer = if ($vipVersion -eq $VIP_LVVersion_A) { $VIP_LVVersion } else { $MinimumSupportedLVVersion }
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
