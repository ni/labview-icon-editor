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
        [string[]]$ArgumentList,
        [hashtable]$ArgumentMap
    )

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    try {
        if ($ArgumentMap) {
            & $ScriptPath @ArgumentMap
        }
        else {
            & $ScriptPath @ArgumentList
        }
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Error ("Error occurred while executing: {0} with exit code {1}" -f $ScriptPath, $code)
            exit $code
        }
    } catch {
        $code = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        Write-Error ("Error occurred while executing: {0}. Exiting. Details: {1}" -f $ScriptPath, $_.Exception.Message)
        exit $code
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

    # Resolve LV version and run Unit Tests (32-bit then 64-bit) with explicit splatting
    $RunUnitTests = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"
    $CloseLabVIEW = Join-Path $RepositoryPath "scripts/close-labview/Close_LabVIEW.ps1"
    Test-PathExistence $CloseLabVIEW "Close_LabVIEW script"
    $lvprojPath = Join-Path $RepositoryPath 'lv_icon_editor.lvproj'
    $getLvScript = Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1'
    $lvVersion = '2021'
    if (Test-Path -LiteralPath $getLvScript) {
        try {
            $lvVersion = & $getLvScript -RepositoryPath $RepositoryPath
        }
        catch {
            Write-Warning "Failed to resolve LabVIEW version from VIPB; falling back to $lvVersion. $_"
        }
    }

    foreach ($arch in @('32','64')) {
        $runArgs = @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = $arch
            AbsoluteProjectPath     = $lvprojPath
        }
        Invoke-ScriptSafe -ScriptPath $RunUnitTests -ArgumentMap $runArgs

        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = $arch
        }
    }

    Write-Information "All scripts executed successfully!" -InformationAction Continue
} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

