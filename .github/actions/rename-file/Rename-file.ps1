<#
.SYNOPSIS
    Renames a specified file.

.DESCRIPTION
    Checks whether the source file exists and, if so, renames it to the
    provided target name.

.PARAMETER CurrentFilename
    Full path to the file to rename.

.PARAMETER NewFilename
    New name (including path) for the renamed file.

.EXAMPLE
    .\Rename-file.ps1 -CurrentFilename "C:\path\lv_icon.lvlibp" -NewFilename "lv_icon_x64.lvlibp"
#>
param(
    [string]$CurrentFilename,
    [string]$NewFilename
)

# Function to rename the file
function Rename-File {
    param(
        [string]$CurrentFilename,
        [string]$NewFilename
    )
    
    # Check if the file exists
    if (-Not (Test-Path -Path $CurrentFilename)) {
        Write-Error "File '$CurrentFilename' does not exist."
        exit 1
    }

    # Attempt to rename the file
    try {
        Rename-Item -Path $CurrentFilename -NewName $NewFilename
        Write-Host "Renamed the packed project library to '$NewFilename'."
    } catch {
        Write-Error "Could not rename the file. $_"
        exit 1
    }
}

# Call the function
Rename-File -CurrentFilename $CurrentFilename -NewFilename $NewFilename

