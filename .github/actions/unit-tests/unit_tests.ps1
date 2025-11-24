<#
.SYNOPSIS
    Runs a suite of PowerShell test scripts for the repository.

.DESCRIPTION
    Validates that required paths exist and sequentially executes supporting
    scripts to prepare and test the LabVIEW icon editor project.

.PARAMETER RepositoryPath
    Path to the repository root.

.EXAMPLE
    .\unit_tests.ps1 -RepositoryPath "C:\labview-icon-editor"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

# Helper function to check for file or directory existence
function Test-PathExistence {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Error "The $Description does not exist: $Path"
        exit 1
    }
}

# Helper function to execute scripts sequentially
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, ($ArgumentList -join ' ')) -InformationAction Continue
    try {
        & $ScriptPath @ArgumentList

    } catch {
        Write-Error "Error occurred while executing: $ScriptPath with arguments: $($ArgumentList -join ' '). Exiting."
        exit 1
    }
}

# Main script logic
try {
    # Validate required paths
    Test-PathExistence $RepositoryPath "RepositoryPath"
    if (-not (Test-Path "$RepositoryPath\resource\plugins")) {
        Write-Information "Plugins folder missing; creating $RepositoryPath\resource\plugins" -InformationAction Continue
        New-Item -ItemType Directory -Path "$RepositoryPath\resource\plugins" -Force | Out-Null
    }

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Test-PathExistence $ActionsPath "Actions folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Information "Cleaning up old .lvlibp files in plugins folder..." -InformationAction Continue
    $PluginFiles = Get-ChildItem -Path "$RepositoryPath\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        foreach ($file in $PluginFiles) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to delete {0}: {1}" -f $file.FullName, $_.Exception.Message)
            }
        }
        Write-Information "Deleted .lvlibp files from plugins folder." -InformationAction Continue
    } else {
        Write-Information "No .lvlibp files found to delete." -InformationAction Continue
    }

    # Run Unit Tests
    $RunUnitTests = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"
    Invoke-ScriptSafe -ScriptPath $RunUnitTests -ArgumentList @(
        '-Package_LabVIEW_Version','2021',
        '-SupportedBitness','32',
        '-RepositoryPath', $RepositoryPath
    )

    # Close LabVIEW
    $CloseLabVIEW = Join-Path $ActionsPath "close-labview/Close_LabVIEW.ps1"
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentList @('-Package_LabVIEW_Version','2021','-SupportedBitness','32')

    # Run Unit Tests
    Invoke-ScriptSafe -ScriptPath $RunUnitTests -ArgumentList @(
        '-Package_LabVIEW_Version','2021',
        '-SupportedBitness','64',
        '-RepositoryPath', $RepositoryPath
    )

        # Close LabVIEW
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentList @('-Package_LabVIEW_Version','2021','-SupportedBitness','64')

    Write-Information "All scripts executed successfully!" -InformationAction Continue
} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

