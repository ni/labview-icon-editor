[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "[AgentPatch] No-op patch placeholder; set a real patch command to apply fixes." -ForegroundColor Yellow
Write-Host "Context: REFINE_LOOP=$env:REFINE_LOOP REFINE_EXIT_CODE=$env:REFINE_EXIT_CODE REFINE_SUMMARY_PATH=$env:REFINE_SUMMARY_PATH REFINE_LOG_DIR=$env:REFINE_LOG_DIR" -ForegroundColor DarkGray
