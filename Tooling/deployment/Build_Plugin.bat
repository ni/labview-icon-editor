REM  Run this batch file in admin mode since C:\Program Files\NI\LVAddon requires admin rights
@echo on
set "LVVersion=2021"
set "SupportedBitness=64"
set "ApiVersion=v1"
set "MinimumSupportedLVVersion=23.0"
set "AddonName=niiconeditor%SupportedBitness%"
set "RelativePath=C:\labview-icon-editor"
set "BuildSpec=Editor Packed Library"
set "NIPB_Path=%RelativePath%\Tooling\deployment\NIPackage\IconEditorDeployment_x%SupportedBitness%.pbs"
set "Project=%RelativePath%\lv_icon_editor.lvproj"
set "PackedProjectLibraryVersion=1.0.1.0"
set "VIPackageLabVIEWVersion=2021"

REM Delete any previously built LV Addons
cd /d C:\Program Files\NI\LVAddons
rmdir /s /q %AddonName%
REM Add Localhost.LibraryPaths token to LabVIEW INI
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\NIPackage\CreateLVINILocalHostKey.vi" -- %RelativePath%
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW
REM Zips and moves lv_icon.lvlibp as well as LabVIEW Icon API from VI Lib to a different location
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\PrepareIESource.vi" -- "%Project%" "Editor Packed Library"
REM Modifies project to deploy to resource/plugins
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\NIPackage\ModifyProjectDeployResources.vi" -- "%Project%" "%BuildSpec%"
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW
REM Build the PPL
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% lvbuildspec -- -v %PackedProjectLibraryVersion% -p "%Project%" -b "%BuildSpec%"
REM Build VI Package
call g-cli --lv-ver %VIPackageLabVIEWVersion% --arch %SupportedBitness% -v vipb -- -av -b "%RelativePath%\Tooling\deployment\VIPackage\NI Icon editorx%SupportedBitness%.vipb"
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW