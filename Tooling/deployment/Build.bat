REM  Run this batch file in admin mode since C:\Program Files\NI\LVAddon requires admin rights
@echo on
REM DO NOT CHANGE LVVersion, since we need the PPL to be built on LabVIEW 2021
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
REM Change the variable below to build VI Packages in other versions, or add additional lines to the batch file the build other versions to avoid having to build multiple times the PPL.
set "VIPackageLabVIEWVersion=2024"

REM Delete any previously built LV Addons
cd /d C:\Program Files\NI\LVAddons
rmdir /s /q %AddonName%
REM Add Localhost.LibraryPaths token to LabVIEW INI
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\NIPackage\CreateLVINILocalHostKey.vi" -- %RelativePath%
IF %ERRORLEVEL% NEQ 0 goto end
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end
REM Zips and moves lv_icon.lvlibp as well as LabVIEW Icon API from VI Lib to a different location
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\PrepareIESource.vi" -- "%Project%" "Editor Packed Library"
IF %ERRORLEVEL% NEQ 0 goto end
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end
REM Run Unit tests
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\Run all tests CLI.vi" -- "
IF %ERRORLEVEL% NEQ 0 goto end
REM Build the PPL
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% lvbuildspec -- -v %PackedProjectLibraryVersion% -p "%Project%" -b "%BuildSpec%"
IF %ERRORLEVEL% NEQ 0 goto end
REM Build VI Package
call g-cli --lv-ver %VIPackageLabVIEWVersion% --arch %SupportedBitness% -v vipb -- -av -b "%RelativePath%\Tooling\deployment\VIPackage\NI Icon editor.vipb"
IF %ERRORLEVEL% NEQ 0 goto
REM Quit LabVIEW
IF %LVVersion% NEQ %VIPackageLabVIEWVersion% call g-cli --lv-ver %VIPackageLabVIEWVersion% --arch %SupportedBitness% QuitLabVIEW 
REM Build NI Package
REM cd /d C:\Program Files\National Instruments\Package Builder
REM call nipbcli -o="%NIPB_Path%" -b=packages -save
REM IF %ERRORLEVEL% NEQ 0 goto end
REM Removes token LocalHost.LibraryPaths from LabVIEW.ini
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\NIPackage\DestroyLVINILocalHostKey.vi"
IF %ERRORLEVEL% NEQ 0 goto end
REM Quit LabVIEW
call g-cli --lv-ver %LVVersion% --arch %SupportedBitness% QuitLabVIEW
:end 
IF %ERRORLEVEL% NEQ 0 pause


