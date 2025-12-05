param(
    [string]$Package_LabVIEW_Version,
    [string]$SupportedBitness,
    [string]$AbsoluteProjectPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Placeholder unit-test runner: emits a message and exits success.
Write-Host "[unit-tests] Skipping managed unit tests (stub)." -ForegroundColor Yellow
Write-Host "[unit-tests] Package_LabVIEW_Version=$Package_LabVIEW_Version SupportedBitness=$SupportedBitness Project=$AbsoluteProjectPath"
exit 0
