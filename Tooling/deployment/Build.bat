REM  Run this batch file in admin mode since C:\Program Files\NI\LVAddon requires admin rights
@echo on
REM DO NOT CHANGE LVVersion, since we need the PPL to be built on LabVIEW 2021
set "PPL_LVVersion=2021" 
set "SupportedBitness=64"
set "ApiVersion=v1"
set "MinimumSupportedLVVersion=23.0"
set "AddonName=niiconeditor%SupportedBitness%"
set "RelativePath=C:\labview-icon-editor"
set "BuildSpec=Editor Packed Library"
set "NIPB_Path=%RelativePath%\Tooling\deployment\IconEditorDeployment_x%SupportedBitness%.pbs"
set "Project=%RelativePath%\lv_icon_editor.lvproj"
set "PackedProjectLibraryVersion=1.0.1.0"
REM Change the variable below to build VI Packages in other versions, or add additional lines to the batch file the build other versions to avoid having to build multiple times the PPL.
REM set "VIP_LVVersion_B="24.3"
set "VIP_LVVersion_B=21.0 (64-bit)"
set "VIP_LVVersion_A=2021"

REM Removes token LocalHost.LibraryPaths from LabVIEW.ini
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\Destroy_LV_INI_Token.vi" -- LabVIEW localhost.LibraryPaths
IF %ERRORLEVEL% NEQ 0 goto end

REM Quit LabVIEW
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end

REM Apply dependencies 1
REM call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v vipc -- %RelativePath%\Tooling\deployment\Dependencies.vipc
REM IF %ERRORLEVEL% NEQ 0 goto end

REM Modify VIPB to have a different labview version
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\Modify_VIPB_LabVIEW_Version.vi" -- "%RelativePath%\Tooling\deployment\NI Icon editor.vipb" %VIP_LVVersion_B%
IF %ERRORLEVEL% NEQ 0 goto end

REM Add Localhost.LibraryPaths token to LabVIEW INI
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\deployment\Create_LV_INI_Token.vi" -- LabVIEW Localhost.LibraryPaths "%RelativePath%"
IF %ERRORLEVEL% NEQ 0 goto end

REM Quit LabVIEW
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end

REM Zips and moves lv_icon.lvlibp as well as LabVIEW Icon API from VI Lib to a different location
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\PrepareIESource.vi" -- "%Project%" "Editor Packed Library"
IF %ERRORLEVEL% NEQ 0 goto end

REM Quit LabVIEW
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end

REM Run Unit tests
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\Run all tests CLI.vi"
IF %ERRORLEVEL% NEQ 0 goto end

REM Build the PPL
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% lvbuildspec -- -v %PackedProjectLibraryVersion% -p "%Project%" -b "%BuildSpec%"
IF %ERRORLEVEL% NEQ 0 goto end

REM Switch VIPM target
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% -v "%RelativePath%\Tooling\Deployment\Switch_VIPM_Target.vi" -- %VIP_LVVersion_B%
IF %ERRORLEVEL% NEQ 0 goto end

REM Quit LabVIEW
call g-cli --lv-ver %PPL_LVVersion% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end

REM Build VI Package
call g-cli --lv-ver %VIP_LVVersion_A% --arch %SupportedBitness% -v vipb -- -av -b "%RelativePath%\Tooling\deployment\NI Icon editor.vipb"
IF %ERRORLEVEL% NEQ 0 goto end

REM Quit LabVIEW
call g-cli --lv-ver %VIP_LVVersion_A% --arch %SupportedBitness% QuitLabVIEW
IF %ERRORLEVEL% NEQ 0 goto end

REM Build NI Package
REM cd /d C:\Program Files\National Instruments\Package Builder
REM call nipbcli -o="%NIPB_Path%" -b=packages -save
REM IF %ERRORLEVEL% NEQ 0 goto end

:end 
IF %ERRORLEVEL% NEQ 0 pause

