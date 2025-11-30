@echo off
setlocal
rem Windows-friendly pre-commit hook wrapper

if not "%SKIP_GIT_HOOKS%"=="" exit /b 0

set "HOOK_DIR=%~dp0"
set "REPO_ROOT=%HOOK_DIR%..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

rem Run pre-commit via telemetry wrapper if Python is available
where python >NUL 2>&1
if %ERRORLEVEL%==0 (
  python "%REPO_ROOT%\scripts\run_pre_commit.py"
) else (
  rem Fallback: try pre-commit directly or succeed silently
  where pre-commit >NUL 2>&1 && pre-commit run --hook-stage commit
)
exit /b %ERRORLEVEL%

