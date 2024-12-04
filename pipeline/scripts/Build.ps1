# Build.ps1 -RelativePath "C:\labview-icon-editor" -RelativePathScripts "C:\labview-icon-editor\pipeline\scripts"
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    
    [Parameter(Mandatory = $true)]
    [string]$RelativePathScripts
)

# Display the initial flashy banner
Write-Host "================================================================================" -ForegroundColor Magenta
Write-Host "||                                                                              ||" -ForegroundColor Magenta
Write-Host "||  STARTING THE UNIT TESTS AND BUILD PROCESS LAYER OF THE OPEN SOURCE          ||" -ForegroundColor Magenta
Write-Host "||                                                                              ||" -ForegroundColor Magenta
Write-Host "||                                    " -NoNewline -ForegroundColor Magenta
Write-Host "LabVIEW" -NoNewline -ForegroundColor Yellow
Write-Host "                                   ||" -ForegroundColor Magenta
Write-Host "||                                                                              ||" -ForegroundColor Magenta
Write-Host "||                                  ICON EDITOR.                                ||" -ForegroundColor Magenta
Write-Host "||                                                                              ||" -ForegroundColor Magenta
Write-Host "================================================================================" -ForegroundColor Magenta

# Helper function to check for file or directory existence
function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Host "*************************************************************" -ForegroundColor Red
        Write-Host "ERROR: The $Description does not exist:" -ForegroundColor Red
        Write-Host "       $Path" -ForegroundColor Red
        Write-Host "*************************************************************" -ForegroundColor Red
        exit 1
    }
}

# Helper function to execute scripts sequentially
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string]$Arguments,
        [string]$StepDescription
    )
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "||                                                         ||" -ForegroundColor Cyan
    Write-Host "||  $StepDescription" -ForegroundColor Cyan
    Write-Host "||                                                         ||" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "Executing: $ScriptPath $Arguments" -ForegroundColor Cyan
    try {
        # Build and execute the command
        $command = "& `"$ScriptPath`" $Arguments"
        Invoke-Expression $command

        # Check for errors in the script execution
        if ($LASTEXITCODE -ne 0) {
            Write-Host "*************************************************************" -ForegroundColor Red
            Write-Host "ERROR: An error occurred while executing the script." -ForegroundColor Red
            Write-Host "Script: $ScriptPath" -ForegroundColor Red
            Write-Host "Arguments: $Arguments" -ForegroundColor Red
            Write-Host "Exit Code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "*************************************************************" -ForegroundColor Red
            exit $LASTEXITCODE
        } else {
            Write-Host "SUCCESS: Completed $StepDescription" -ForegroundColor Green
        }
    } catch {
        Write-Host "*************************************************************" -ForegroundColor Red
        Write-Host "EXCEPTION: An exception occurred during script execution." -ForegroundColor Red
        Write-Host "Script: $ScriptPath" -ForegroundColor Red
        Write-Host "Arguments: $Arguments" -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "*************************************************************" -ForegroundColor Red
        exit 1
    }
}

# Main script logic
try {
    # Section: Path Consistency
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "||               VALIDATING PATH CONSISTENCY               ||" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "Ensuring paths are consistent..." -ForegroundColor Yellow
    Write-Host "# Consistently using backslashes" -ForegroundColor DarkGray

    # Validate required paths
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists "$RelativePath\resource\plugins" "Plugins folder"
    Assert-PathExists $RelativePathScripts "Scripts folder"

    # Section: Branch Naming Conventions
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "||             BRANCH NAMING CONVENTIONS                  ||" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "Using forward slashes for branch names" -ForegroundColor Yellow
    Write-Host "# Use forward slashes for branch names" -ForegroundColor DarkGray

    # Section: Clean Up Plugins Folder
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "||               CLEANING UP PLUGINS FOLDER                ||" -ForegroundColor Yellow
    Write-Host "||                                                         ||" -ForegroundColor Yellow
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    $PluginFiles = Get-ChildItem -Path "$RelativePath\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        $PluginFiles | Remove-Item -Force
        Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
    } else {
        Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
    }

    # Inform about starting the build process
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Magenta
    Write-Host "||                                                         ||" -ForegroundColor Magenta
    Write-Host "||               STARTING BUILD PROCESS                    ||" -ForegroundColor Magenta
    Write-Host "||                                                         ||" -ForegroundColor Magenta
    Write-Host "=============================================================" -ForegroundColor Magenta

    # Steps for LabVIEW 2021 (32-bit)
    $labviewVersion = "2021"
    $bitness = "32"
    $lvDescription = "LabVIEW $labviewVersion ($bitness-bit)"

    # Apply dependencies for LabVIEW 2021 (32-bit)
    # Apply dependencies for LabVIEW 2021 (32-bit)
    $commentText = "Apply dependencies for LabVIEW 2021 (32-bit)"
    $stepComment = "APPLY DEPENDENCIES FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Applyvipc.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -VIPCPath `"Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion $labviewVersion" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Add token to LabVIEW 2021 (32-bit)
    # Add token to LabVIEW 2021 (32-bit)
    $commentText = "Add token to LabVIEW 2021 (32-bit)"
    $stepComment = "ADD TOKEN TO $lvDescription"
    Execute-Script "$($RelativePathScripts)\AddTokenToLabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Close LabVIEW 2021 (32-bit)
    # Close LabVIEW 2021 (32-bit)
    $commentText = "Close LabVIEW 2021 (32-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Prepare LabVIEW 2021 (32-bit) source
    # Prepare LabVIEW 2021 (32-bit) source
    $commentText = "Prepare LabVIEW 2021 (32-bit) source"
    $stepComment = "PREPARE SOURCE FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Prepare_LabVIEW_source.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -LabVIEW_Project lv_icon_editor -Build_Spec `"Editor Packed Library`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Close LabVIEW 2021 (32-bit)
    # Close LabVIEW 2021 (32-bit)
    $commentText = "Close LabVIEW 2021 (32-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Run Unit Tests LabVIEW 2021 (32-bit)
    # Run Unit Tests LabVIEW 2021 (32-bit)
    $commentText = "Run Unit Tests LabVIEW 2021 (32-bit)"
    $stepComment = "RUN UNIT TESTS FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\RunUnitTests.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Build packed project library for LabVIEW 2021 (32-bit)
    # Build packed project library for LabVIEW 2021 (32-bit)
    $commentText = "Build packed project library for LabVIEW 2021 (32-bit)"
    $stepComment = "BUILD PACKED PROJECT LIBRARY FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Build_lvlibp.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Restore LabVIEW 2021 (32-bit) source setup
    # Restore LabVIEW 2021 (32-bit) source setup
    $commentText = "Restore LabVIEW 2021 (32-bit) source setup"
    $stepComment = "RESTORE SOURCE SETUP FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\RestoreSetupLVSource.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Close LabVIEW 2021 (32-bit)
    # Close LabVIEW 2021 (32-bit)
    $commentText = "Close LabVIEW 2021 (32-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Rename lv_icon.lvlibp to lv_icon_x86.lvlibp
    # Rename lv_icon.lvlibp to lv_icon_x86.lvlibp
    $commentText = "Rename lv_icon.lvlibp to lv_icon_x86.lvlibp"
    $stepComment = "RENAME lv_icon.lvlibp TO lv_icon_x86.lvlibp"
    Execute-Script "$($RelativePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Steps for LabVIEW 2021 (64-bit)
    $bitness = "64"
    $lvDescription = "LabVIEW $labviewVersion ($bitness-bit)"

    # Apply dependencies for LabVIEW 2021 (64-bit)
    # Apply dependencies for LabVIEW 2021 (64-bit)
    $commentText = "Apply dependencies for LabVIEW 2021 (64-bit)"
    $stepComment = "APPLY DEPENDENCIES FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Applyvipc.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -VIPCPath `"Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion $labviewVersion" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Add token to LabVIEW 2021 (64-bit)
    # Add token to LabVIEW 2021 (64-bit)
    $commentText = "Add token to LabVIEW 2021 (64-bit)"
    $stepComment = "ADD TOKEN TO $lvDescription"
    Execute-Script "$($RelativePathScripts)\AddTokenToLabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Close LabVIEW 2021 (64-bit)
    # Close LabVIEW 2021 (64-bit)
    $commentText = "Close LabVIEW 2021 (64-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Prepare LabVIEW 2021 (64-bit) source
    $commentText = "Prepare LabVIEW 2021 (64-bit) source"
    $stepComment = "PREPARE SOURCE FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Prepare_LabVIEW_source.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -LabVIEW_Project lv_icon_editor -Build_Spec `"Editor Packed Library`"" `
        "$stepComment"

    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Close LabVIEW 2021 (64-bit)
    $commentText = "Close LabVIEW 2021 (64-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Run Unit Tests LabVIEW 2021 (64-bit)
    $commentText = "Run Unit Tests LabVIEW 2021 (64-bit)"
    $stepComment = "RUN UNIT TESTS FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\RunUnitTests.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Build packed project library for LabVIEW 2021 (64-bit)
    $commentText = "Build packed project library for LabVIEW 2021 (64-bit)"
    $stepComment = "BUILD PACKED PROJECT LIBRARY FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\Build_lvlibp.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`"" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Restore LabVIEW 2021 (64-bit) source setup
    # Restore LabVIEW 2021 (64-bit) source setup
    $commentText = "Restore LabVIEW 2021 (64-bit) source setup"
    $stepComment = "RESTORE SOURCE SETUP FOR $lvDescription"
    Execute-Script "$($RelativePathScripts)\RestoreSetupLVSource.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Close LabVIEW 2021 (64-bit)
    $commentText = "Close LabVIEW 2021 (64-bit)"
    $stepComment = "CLOSE $lvDescription"
    Execute-Script "$($RelativePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion $labviewVersion -SupportedBitness $bitness" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Rename lv_icon.lvlibp to lv_icon_x64.lvlibp
    $commentText = "Rename lv_icon.lvlibp to lv_icon_x64.lvlibp"
    $stepComment = "RENAME lv_icon.lvlibp TO lv_icon_x64.lvlibp"
    Execute-Script "$($RelativePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x64.lvlibp'" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan


    # Build VI Package
    $commentText = "Build VI Package"
    $stepComment = "BUILD VI PACKAGE"
    Execute-Script "$($RelativePathScripts)\build_vip.ps1" `
        "-SupportedBitness 64 -RelativePath `"$RelativePath`" -VIPBPath `"Tooling\deployment\NI Icon editor.vipb`" -VIP_LVVersion $labviewVersion -MinimumSupportedLVVersion $labviewVersion" `
        "$stepComment"
    
    # ASCII Art Message
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "|  $commentText" -ForegroundColor DarkCyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    # Success message with ASCII art
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host "||                                                         ||" -ForegroundColor Green
    Write-Host "||            ALL SCRIPTS EXECUTED SUCCESSFULLY!           ||" -ForegroundColor Green
    Write-Host "||                                                         ||" -ForegroundColor Green
    Write-Host "=============================================================" -ForegroundColor Green
} catch {
    Write-Host "*************************************************************" -ForegroundColor Red
    Write-Host "UNEXPECTED ERROR: An unexpected error occurred during script execution." -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "*************************************************************" -ForegroundColor Red
    exit 1
}
