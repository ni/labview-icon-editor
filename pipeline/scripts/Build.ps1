param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    
    [Parameter(Mandatory = $true)]
    [string]$RelativePathScripts
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

# Main script logic
try {
    # Validate required paths
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists "$RelativePath\resource\plugins" "Plugins folder"
    Assert-PathExists $RelativePathScripts "Scripts folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    $PluginFiles = Get-ChildItem -Path "`"$RelativePath\resource\plugins`"" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        $PluginFiles | Remove-Item -Force
        Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
    } else {
        Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
    }

    # Apply dependencies for LV 2021
    Write-Host "Applying dependencies for LabVIEW 2021..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Applyvipc.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -VIPCPath `"Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion 2021" -NoNewWindow -Wait

    # Add token to LabVIEW
    Write-Host "Adding token to LabVIEW..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\AddTokenToLabVIEW.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`"" -NoNewWindow -Wait

    # Close LabVIEW
    Write-Host "Closing LabVIEW..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Close_LabVIEW.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32" -NoNewWindow -Wait

    # Prepare LabVIEW source
    Write-Host "Preparing LabVIEW source..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Prepare_LabVIEW_source.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" -NoNewWindow -Wait

    # Close LabVIEW again
    Write-Host "Closing LabVIEW again..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Close_LabVIEW.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32" -NoNewWindow -Wait

    # Run Unit Tests
    Write-Host "Running unit tests..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\RunUnitTests.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`"" -NoNewWindow -Wait

    # Build LV Library
    Write-Host "Building LabVIEW library (.lvlibp)..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Build_lvlibp.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`"" -NoNewWindow -Wait

    # Restore LabVIEW source setup
    Write-Host "Restoring LabVIEW source setup..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\RestoreSetupLVSource.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" -NoNewWindow -Wait

    # Close LabVIEW
    Write-Host "Finalizing by closing LabVIEW..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Close_LabVIEW.ps1`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32" -NoNewWindow -Wait

    # Rename the file after build
    Write-Host "Renaming built library file..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$RelativePathScripts\Rename-File.ps1`" -CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'" -NoNewWindow -Wait

    # Success message
    Write-Host "All scripts executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
