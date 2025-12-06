@echo off
setlocal
rem Windows-friendly prepare-commit-msg hook wrapper

if not "%SKIP_GIT_HOOKS%"=="" exit /b 0

set "HOOK_DIR=%~dp0"
set "REPO_ROOT=%HOOK_DIR%..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

where python >NUL 2>&1 || exit /b 0
python "%REPO_ROOT%\scripts\prepare-commit-msg.py" "%1"
exit /b 0

