param(
    [string]$Package_LabVIEW_Version,
    [string]$SupportedBitness,
    [switch]$KillLabVIEW,
    [int]$KillTimeoutSeconds = 5,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Placeholder close script to satisfy Test.ps1; no-op but exits success.
Write-Host "[close-labview] No-op close for LabVIEW $Package_LabVIEW_Version ($SupportedBitness-bit)"
Write-Host "[close-labview] KillLabVIEW=$($KillLabVIEW.IsPresent) KillTimeoutSeconds=$KillTimeoutSeconds TimeoutSeconds=$TimeoutSeconds"
exit 0
