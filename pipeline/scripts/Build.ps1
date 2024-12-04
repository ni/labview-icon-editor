param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    
    [Parameter(Mandatory = $true)]
    [string]$RelativePathScripts
)

# Helper function to execute scripts with PowerShell Execution Policy Bypass
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string]$Arguments
    )
    Write-Host "Executing: $ScriptPath $Arguments" -ForegroundColor Cyan
    try {
        $Command = "powershell -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"
        Invoke-Expression "`"$Command`"" -ErrorAction Stop
    } catch {
        Write-Host "Error occurred while executing: $ScriptPath with arguments: $Arguments. Exiting." -ForegroundColor Red
        exit 1
    }
}

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

# Main script logic
try {
    # Validate required paths
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists "$RelativePath\resource\plugins" "Plugins folder"
    Assert-PathExists $RelativePathScripts "Scripts folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    $PluginFiles = Get-ChildItem -Path "$RelativePath\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        $PluginFiles | Remove-Item -Force
        Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
    } else {
        Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
    }

    # Apply dependencies for LV 2021
    Write-Host "Applying dependencies for LabVIEW 2021..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Applyvipc.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -VIPCPath `"$($RelativePath)\Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion 2021"
    
    # Add token to LabVIEW
    Write-Host "Adding token to LabVIEW..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\AddTokenToLabVIEW.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    
    # Close LabVIEW
    Write-Host "Closing LabVIEW..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    
    # Prepare LabVIEW source
    Write-Host "Preparing LabVIEW source..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Prepare_LabVIEW_source.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    
    # Close LabVIEW again
    Write-Host "Closing LabVIEW again..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    
    # Run Unit Tests
    Write-Host "Running unit tests..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\RunUnitTests.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    
    # Build LV Library
    Write-Host "Building LabVIEW library (.lvlibp)..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Build_lvlibp.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    
    # Restore LabVIEW source setup
    Write-Host "Restoring LabVIEW source setup..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\RestoreSetupLVSource.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    
    # Close LabVIEW
    Write-Host "Finalizing by closing LabVIEW..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    
    # Rename the file after build
    Write-Host "Renaming built library file..." -ForegroundColor Yellow
    Execute-Script "$($RelativePathScripts)\Rename-File.ps1" "-CurrentFilename `"$($RelativePath)\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'"
    
    # Success message
    Write-Host "All scripts executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
