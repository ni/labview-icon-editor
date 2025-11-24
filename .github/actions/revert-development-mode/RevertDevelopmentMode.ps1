<#
.SYNOPSIS
    Reverts the repository from development mode.

.DESCRIPTION
    Restores the packaged LabVIEW sources for both 32-bit and 64-bit
    environments and closes any running LabVIEW instances.

.PARAMETER RepositoryPath
    Path to the repository root.

.EXAMPLE
    .\RevertDevelopmentMode.ps1 -RepositoryPath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RepositoryPath,

    # Optional override; if not provided we read Package_LabVIEW_Version from the repo .vipb
    [Parameter(Mandatory = $false)]
    [string]$Package_LabVIEW_Version,

    # Limit work to a single bitness (default 64-bit)
    [Parameter(Mandatory = $false)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64'
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Information "Script Directory: $ScriptDirectory" -InformationAction Continue

# Normalize repository path early and re-validate
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not (Test-Path -LiteralPath $RepositoryPath)) {
    throw "RepositoryPath '$RepositoryPath' does not exist."
}

# Helper function to execute scripts and stop on error
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [hashtable]$ArgumentMap,
        [string[]]$ArgumentList
    )
    if (-not $ScriptPath) { throw "ScriptPath is required" }
    if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "ScriptPath '$ScriptPath' not found" }

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    try {
        if ($ArgumentMap) {
            & $ScriptPath @ArgumentMap
        } elseif ($ArgumentList) {
            & $ScriptPath @ArgumentList
        } else {
            & $ScriptPath
        }
    } catch {
        $msg = "Error occurred while executing: $ScriptPath $($ArgumentList -join ' '). Exiting."
        if ($_.Exception) { $msg += " Inner: $($_.Exception.Message)" }
        if ($_.InvocationInfo) { $msg += " At: $($_.InvocationInfo.PositionMessage)" }
        Write-Error $msg
        throw
    }
}

# Sequential script execution with error handling
try {
    # Always resolve from VIPB to ensure determinism; ignore inbound overrides
    $Package_LabVIEW_Version = & (Join-Path $PSScriptRoot '..\..\..\scripts\get-package-lv-version.ps1') -RepositoryPath $RepositoryPath
    Write-Information ("Detected LabVIEW version from VIPB: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue

    $targetBitness = $SupportedBitness
    Write-Information ("Targeting bitness: {0}-bit" -f $targetBitness) -InformationAction Continue
    # Build the script paths
    $RestoreScript = Join-Path -Path $ScriptDirectory -ChildPath '..\restore-setup-lv-source\RestoreSetupLVSource.ps1'
    $CloseScript   = Join-Path -Path $ScriptDirectory -ChildPath '..\close-labview\Close_LabVIEW.ps1'

    $arch = $targetBitness

    Invoke-ScriptSafe -ScriptPath $RestoreScript -ArgumentMap @{
        MinimumSupportedLVVersion = $Package_LabVIEW_Version
        SupportedBitness          = $arch
        RepositoryPath            = $RepositoryPath
        LabVIEW_Project           = $LabVIEW_Project
        Build_Spec                = 'Editor Packed Library'
    }

    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentMap @{
        MinimumSupportedLVVersion = $Package_LabVIEW_Version
        SupportedBitness          = $arch
    }

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue

