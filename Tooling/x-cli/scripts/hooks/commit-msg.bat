@echo off
setlocal
rem Windows-friendly commit-msg hook wrapper

if not "%SKIP_GIT_HOOKS%"=="" exit /b 0

set "HOOK_DIR=%~dp0"
set "REPO_ROOT=%HOOK_DIR%..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

rem Best-effort enrichment of the summary line
where python >NUL 2>&1 && python "%REPO_ROOT%\scripts\enrich_commit_summary.py" "%1" 1>NUL 2>&1

rem Prefer pre-commit if available; else run the checker directly
where pre-commit >NUL 2>&1
if %ERRORLEVEL%==0 (
  pre-commit run --hook-stage commit-msg --commit-msg-filename "%1"
) else (
  python "%REPO_ROOT%\scripts\check-commit-msg.py" "%1"
)
exit /b %ERRORLEVEL%

