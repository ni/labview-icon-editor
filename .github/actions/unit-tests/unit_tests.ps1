<#
.SYNOPSIS
    Runs a suite of PowerShell test scripts for the repository.

.DESCRIPTION
    Validates that required paths exist and sequentially executes supporting
    scripts to prepare and test the LabVIEW icon editor project.

.PARAMETER RepoRoot
    Path to the repository root.

.EXAMPLE
    .\unit_tests.ps1 -RepoRoot "C:\labview-icon-editor"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
)

# Helper function to check for file or directory existence
function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Host "The $Description does not exist: $Path" -ForegroundColor Red
        exit 1
    }
}

# Helper function to execute scripts sequentially
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string]$Arguments
    )
    Write-Host "Executing: $ScriptPath $Arguments" -ForegroundColor Cyan
    try {
        # Build and execute the command
        $command = "& `"$ScriptPath`" $Arguments"
        Invoke-Expression $command

        # Check for errors in the script execution
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error occurred while executing: $ScriptPath with arguments: $Arguments. Exit code: $LASTEXITCODE" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } catch {
        Write-Host "Error occurred while executing: $ScriptPath with arguments: $Arguments. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Main script logic
try {
    # Validate required paths
    Assert-PathExists $RepoRoot "RepoRoot"
    if (-not (Test-Path "$RepoRoot\resource\plugins")) {
        Write-Host "Plugins folder missing; creating $RepoRoot\resource\plugins" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "$RepoRoot\resource\plugins" -Force | Out-Null
    }

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Assert-PathExists $ActionsPath "Actions folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    $PluginFiles = Get-ChildItem -Path "$RepoRoot\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        foreach ($file in $PluginFiles) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to delete {0}: {1}" -f $file.FullName, $_.Exception.Message)
            }
        }
        Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
    } else {
        Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
    }
    
    # Run Unit Tests
    $RunUnitTests = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"
    $ProjectPath = Join-Path $RepoRoot 'lv_icon_editor.lvproj'
    Execute-Script $RunUnitTests `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -ProjectPath `"$ProjectPath`""

    # Close LabVIEW
    $CloseLabVIEW = Join-Path $ActionsPath "close-labview/Close_LabVIEW.ps1"
    Execute-Script $CloseLabVIEW `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"

    # Run Unit Tests
    Execute-Script $RunUnitTests `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64 -ProjectPath `"$ProjectPath`""

	# Close LabVIEW
    Execute-Script $CloseLabVIEW `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64"
		
    Write-Host "All scripts executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

