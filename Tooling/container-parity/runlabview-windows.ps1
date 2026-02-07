param(
    [string]$WorkspaceRoot = "C:\workspace",
    [string]$TargetDir = "",
    [string]$LabVIEWPath = "C:\Program Files\National Instruments\LabVIEW 2026\LabVIEW.exe"
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $WorkspaceRoot 'Test\Templates'
}

if (-not (Get-Command LabVIEWCLI -ErrorAction SilentlyContinue)) {
    Write-Error "LabVIEWCLI is not available on PATH inside the container."
}

if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    Write-Error "Target directory does not exist: $TargetDir"
}

Write-Host "Running LabVIEWCLI MassCompile in headless mode."
Write-Host "Target directory: $TargetDir"
Write-Host "LabVIEW path: $LabVIEWPath"

& LabVIEWCLI `
    -LogToConsole TRUE `
    -OperationName MassCompile `
    -DirectoryToCompile $TargetDir `
    -LabVIEWPath $LabVIEWPath `
    -Headless

if ($LASTEXITCODE -ne 0) {
    throw "LabVIEWCLI MassCompile failed with exit code $LASTEXITCODE."
}

Write-Host "MassCompile completed successfully."
