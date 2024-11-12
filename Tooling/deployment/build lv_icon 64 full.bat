@echo off
REM Batch file to run multiple LabVIEW CLI commands in series
REM LabVIEWCLI -OperationName CloseLabVIEW -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3366
LabVIEWCLI -OperationName ExecuteBuildSpec -ProjectPath "C:\labview-icon-editor\lv_icon_editor.lvproj" -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3366 -LogFilePath "C:\Users\Public\CLIlog.txt" -Verbosity Detailed -LogToConsole true -TargetName "My Computer" -BuildSpecName "Editor Packed Library x64"
cd /d C:\Program Files\National Instruments\Package Builder
nipbcli -o="C:\labview-icon-editor\Tooling\deployment\LVAddonIE_x64.pbs" -b=packages
REMLabVIEWCLI -OperationName CloseLabVIEW -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3366

echo "All LabVIEW CLI commands completed successfully."