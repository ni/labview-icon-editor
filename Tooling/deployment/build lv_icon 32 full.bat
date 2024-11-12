@echo off
REM Batch file to run multiple LabVIEW CLI commands in series
LabVIEWCLI -OperationName ExecuteBuildSpec -ProjectPath "C:\labview-icon-editor\lv_icon_editor.lvproj" -LabVIEWPath "C:\Program Files (x86)\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3363 -LogFilePath "C:\Users\Public\CLIlog.txt" -Verbosity Detailed -LogToConsole true -TargetName "My Computer" -BuildSpecName "Editor Packed Library x86"
cd /d C:\Program Files\National Instruments\Package Builder
nipbcli -o="C:\labview-icon-editor\Tooling\deployment\LVAddonIE_x86.pbs" -b=packages
LabVIEWCLI -OperationName CloseLabVIEW
REM Build 32 bit windows variant

echo "All LabVIEW CLI commands completed successfully."