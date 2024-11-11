@echo off
REM Batch file to run multiple LabVIEW CLI commands in series

REM Build 64 bit windows variant
REM LabVIEWCLI -OperationName RunVI -VIPath "C:\labview-icon-editor\Tooling\deployment\Build the ppl.vi" -LabVIEWPath "C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3366 -LogFilePath "C:\temp\log.txt" -Verbosity Detailed -LogToConsole true
LabVIEWCLI -OperationName ExecuteBuildSpec -ProjectPath "C:\labview-icon-editor\lv_icon_editor.lvproj" -LabVIEWPath "C:\Program Files (x86)\National Instruments\LabVIEW 2021\LabVIEW.exe" -PortNumber 3363 -LogFilePath "C:\Users\Public\CLIlog.txt" -Verbosity Detailed -LogToConsole TRUE -TargetName "My Computer" -BuildSpecName "Editor Packed Library"
LabVIEWCLI -OperationName CloseLabVIEW
REM Build 32 bit windows variant

echo "All LabVIEW CLI commands completed successfully."