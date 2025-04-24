<#
.SYNOPSIS
  This script automates the build process for the LabVIEW Icon Editor project.
  It performs the following tasks:
    1. Cleans up old .lvlibp files in the plugins folder.
    2. Applies VIPC (32-bit and 64-bit).
    3. Builds the LabVIEW library (32-bit and 64-bit).
    4. Closes LabVIEW (32-bit and 64-bit).
    5. Renames the built files.
    6. Builds the VI package (64-bit) with DisplayInformationJSON fields.
    7. Closes LabVIEW (64-bit).

  Example usage:
    .\Build.ps1 `
      -RelativePath "C:\labview-icon-editor-fork" `
      -AbsolutePathScripts "C:\labview-icon-editor-fork\pipeline\scripts" `
      -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder" `
      -CompanyName "Acme Corporation" `
      -AuthorName "John Doe (Acme Corp)" `
      -Verbose
#>

[CmdletBinding()]  # Enables -Verbose, -Debug, etc.
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$AbsolutePathScripts,

    [Parameter(Mandatory = $true)]
    [int]$Major = 1,

    [Parameter(Mandatory = $true)]
    [int]$Minor,

    [Parameter(Mandatory = $true)]
    [int]$Patch,

    [Parameter(Mandatory = $true)]
    [int]$Build,

    [Parameter(Mandatory = $true)]
    [string]$Commit,

    # LabVIEW "minor" revision (0 or 3)
    [Parameter(Mandatory = $false)]
    [int]$LabVIEWMinorRevision = 3,

    # New parameters that will populate the JSON fields
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $true)]
    [string]$AuthorName
)

# Helper function to verify a file/folder path exists
function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    Write-Verbose "Checking if '$Description' exists at path: $Path"
    if (-not (Test-Path -Path $Path)) {
        Write-Host "The '$Description' does not exist: $Path" -ForegroundColor Red
        exit 1
    }
    Write-Verbose "Confirmed '$Description' exists at path: $Path"
}

# Helper function to run another script with arguments
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string]$Arguments
    )
    Write-Host "Executing: $ScriptPath $Arguments" -ForegroundColor Cyan
    Write-Verbose "Constructing command line..."
    
    # The & symbol explicitly invokes the script file
    $command = "& `"$ScriptPath`" $Arguments"
    Write-Verbose "Command: $command"

    try {
        Invoke-Expression $command
        Write-Verbose "Command completed. Checking exit code..."
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error occurred while executing: `"$ScriptPath`" with arguments: `"$Arguments`". Exit code: $LASTEXITCODE" -ForegroundColor Red
            exit $LASTEXITCODE
        }
        Write-Verbose "Exit code is 0; no errors detected."
    }
    catch {
        Write-Host "Error occurred while executing: `"$ScriptPath`" with arguments: `"$Arguments`". Exiting." -ForegroundColor Red
        Write-Verbose "Exception details: $($_.Exception.Message)"
        exit 1
    }
}

try {
    Write-Verbose "Script: Build.ps1 starting."
    Write-Verbose "Parameters received:"
    Write-Verbose " - RelativePath: $RelativePath"
    Write-Verbose " - AbsolutePathScripts: $AbsolutePathScripts"
    Write-Verbose " - Major: $Major"
    Write-Verbose " - Minor: $Minor"
    Write-Verbose " - Patch: $Patch"
    Write-Verbose " - Build: $Build"
    Write-Verbose " - Commit: $Commit"
    Write-Verbose " - LabVIEWMinorRevision: $LabVIEWMinorRevision"
    Write-Verbose " - CompanyName: $CompanyName"
    Write-Verbose " - AuthorName: $AuthorName"

    # Validate needed folders
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists "$RelativePath\resource\plugins" "Plugins folder"
    Assert-PathExists $AbsolutePathScripts "Scripts folder"

    # 1) Clean up old .lvlibp in the plugins folder
    Write-Host "Cleaning up old .lvlibp files in plugins folder..." -ForegroundColor Yellow
    Write-Verbose "Looking for .lvlibp files in $($RelativePath)\resource\plugins..."
    try {
        $PluginFiles = Get-ChildItem -Path "$RelativePath\resource\plugins" -Filter '*.lvlibp' -ErrorAction Stop
        if ($PluginFiles) {
            Write-Verbose "Found $($PluginFiles.Count) file(s): $($PluginFiles | ForEach-Object { $_.Name } -join ', ')"
            $PluginFiles | Remove-Item -Force
            Write-Host "Deleted .lvlibp files from plugins folder." -ForegroundColor Green
        }
        else {
            Write-Host "No .lvlibp files found to delete." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Error occurred while retrieving .lvlibp files: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    }

    # 2) Apply VIPC (32-bit)
    Write-Verbose "Now applying VIPC for 32-bit..."
    Execute-Script "$($AbsolutePathScripts)\ApplyVIPC.ps1" `
        ("-MinimumSupportedLVVersion 2021 " +
         "-VIP_LVVersion 2021 " +
         "-SupportedBitness 32 " +
         "-RelativePath `"$RelativePath`" " +
         "-VIPCPath `"Tooling\deployment\Dependencies.vipc`"")

    # 3) Build LV Library (32-bit)
    Write-Verbose "Building LV library (32-bit)..."
    Execute-Script "$($AbsolutePathScripts)\Build_lvlibp.ps1" `
        ("-MinimumSupportedLVVersion 2021 " +
         "-SupportedBitness 32 " +
         "-RelativePath `"$RelativePath`" " +
         "-Major $Major -Minor $Minor -Patch $Patch -Build $Build " +
         "-Commit `"$Commit`"")

    # 4) Close LabVIEW (32-bit)
    Write-Verbose "Closing LabVIEW (32-bit)..."
    Execute-Script "$($AbsolutePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 32"

    # 5) Rename .lvlibp -> lv_icon_x86.lvlibp
    Write-Verbose "Renaming .lvlibp file to lv_icon_x86.lvlibp..."
    Execute-Script "$($AbsolutePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'"

    # 6) Apply VIPC (64-bit)
    Write-Verbose "Now applying VIPC for 64-bit..."
    Execute-Script "$($AbsolutePathScripts)\ApplyVIPC.ps1" `
        ("-MinimumSupportedLVVersion 2021 " +
         "-VIP_LVVersion 2021 " +
         "-SupportedBitness 64 " +
         "-RelativePath `"$RelativePath`" " +
         "-VIPCPath `"Tooling\deployment\Dependencies.vipc`"")

    # 7) Build LV Library (64-bit)
    Write-Verbose "Building LV library (64-bit)..."
    Execute-Script "$($AbsolutePathScripts)\Build_lvlibp.ps1" `
        ("-MinimumSupportedLVVersion 2021 " +
         "-SupportedBitness 64 " +
         "-RelativePath `"$RelativePath`" " +
         "-Major $Major -Minor $Minor -Patch $Patch -Build $Build " +
         "-Commit `"$Commit`"")

    # Rename .lvlibp -> lv_icon_x64.lvlibp
    Write-Verbose "Renaming .lvlibp file to lv_icon_x64.lvlibp..."
    Execute-Script "$($AbsolutePathScripts)\Rename-File.ps1" `
        "-CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x64.lvlibp'"

    # -------------------------------------------------------------------------
    # 8) Construct the JSON for "Company Name" & "Author Name", plus version
    # -------------------------------------------------------------------------
    # We include "Package Version" with your script parameters.
    # The rest of the fields remain empty or default as needed.
    $jsonObject = @{
        "Package Version" = @{
            "major" = $Major
            "minor" = $Minor
            "patch" = $Patch
            "build" = $Build
        }
        "Product Name"                  = ""
        "Company Name"                  = $CompanyName
        "Author Name (Person or Company)" = $AuthorName
        "Product Homepage (URL)"        = ""
        "Legal Copyright"               = ""
        "License Agreement Name"        = ""
        "Product Description Summary"   = ""
        "Product Description"           = ""
        "Release Notes - Change Log"    = ""
    }

    $DisplayInformationJSON = $jsonObject | ConvertTo-Json -Depth 3

    # 9) Build VI Package (64-bit) — no double-dash parameters
    Write-Verbose "Building VI Package (64-bit)..."
    Execute-Script "$($AbsolutePathScripts)\build_vip.ps1" `
        (
            # Use single-dash for all recognized parameters
            "-SupportedBitness 64 " +
            "-RelativePath `"$RelativePath`" " +
            "-VIPBPath `"Tooling\deployment\NI Icon editor.vipb`" " +
            "-MinimumSupportedLVVersion 2021 " +
            "-LabVIEWMinorRevision $LabVIEWMinorRevision " +
            "-Major $Major -Minor $Minor -Patch $Patch -Build $Build " +
            "-Commit `"$Commit`" " +
            "-ReleaseNotesFile `"$RelativePath\Tooling\deployment\release_notes.md`" " +
            # Pass our JSON
            "-DisplayInformationJSON '$DisplayInformationJSON' " +
            "-Verbose"
        )

    # 10) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Execute-Script "$($AbsolutePathScripts)\Close_LabVIEW.ps1" `
        "-MinimumSupportedLVVersion 2021 -SupportedBitness 64"

    Write-Host "All scripts executed successfully!" -ForegroundColor Green
    Write-Verbose "Script: Build.ps1 completed without errors."
}
catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
}
