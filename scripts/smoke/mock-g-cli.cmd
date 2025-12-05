@echo off
setlocal
set SCRIPT_PATH=%~dp0mock-g-cli.ps1
pwsh -NoProfile -File "%SCRIPT_PATH%" %*
exit /b %ERRORLEVEL%
