# .\Build.ps1 -RelativePath "C:\labview-icon-editor" -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts"
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    
    [Parameter(Mandatory = $true)]
    [string]$AbsolutePathScripts
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
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists "$RelativePath\resource\plugins" "Plugins folder"
    Assert-PathExists $AbsolutePathScripts "Scripts folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    $PluginFiles = Get-ChildItem -Path "$RelativePath\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        $PluginFiles | Remove-Item -Force
        Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
    } else {
        Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
    }
	# Set development mode

    # Apply dependencies for LV 2021
    Execute-Script "$($AbsolutePathScripts)\Applyvipc.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -VIPCPath `"Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion 2021"

    # Run Unit Tests
    Execute-Script "$($AbsolutePathScripts)\RunUnitTests.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""

    # Build LV Library
    Execute-Script "$($AbsolutePathScripts)\Build_lvlibp.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""


    # Close LabVIEW
    Execute-Script "$($AbsolutePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"

    # Rename the file after build
    Execute-Script "$($AbsolutePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'"
	
	# Apply dependencies for LV 2021
    Execute-Script "$($AbsolutePathScripts)\Applyvipc.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -VIPCPath `"Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion 2021"

    # Run Unit Tests
    Execute-Script "$($AbsolutePathScripts)\RunUnitTests.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""

    # Build LV Library
    Execute-Script "$($AbsolutePathScripts)\Build_lvlibp.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""

    # Rename the file after build
    Execute-Script "$($AbsolutePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x64.lvlibp'"

    # Build VI Package
    Execute-Script "$($AbsolutePathScripts)\build_vip.ps1" `
		"-SupportedBitness 64 -RelativePath `"$RelativePath`" -VIPBPath `"Tooling\deployment\NI Icon editor.vipb`" -VIP_LVVersion 2021 -MinimumSupportedLVVersion 2021"

	# Close LabVIEW
    Execute-Script "$($AbsolutePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64"
	
    Write-Host "All scripts executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
