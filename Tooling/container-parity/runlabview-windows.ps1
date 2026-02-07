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

$excludeRaw = $env:CONTAINER_PARITY_EXCLUDE_FILES
if ([string]::IsNullOrWhiteSpace($excludeRaw)) {
    $excludeRaw = 'Polymorphic Template.vi'
}
$excludeFiles = @($excludeRaw.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-parity-{0}" -f [Guid]::NewGuid().ToString('N'))
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

Copy-Item -Path (Join-Path $TargetDir '*') -Destination $stagingDir -Recurse -Force
foreach ($relativePath in $excludeFiles) {
    $candidate = Join-Path $stagingDir $relativePath
    if (Test-Path -LiteralPath $candidate) {
        Write-Host "Excluding template from parity compile: $relativePath"
        Remove-Item -LiteralPath $candidate -Recurse -Force
    }
}

Write-Host "Running LabVIEWCLI MassCompile in headless mode."
Write-Host "Target directory: $TargetDir"
Write-Host "LabVIEW path: $LabVIEWPath"
Write-Host ("Excluded templates: {0}" -f ($excludeFiles -join '; '))
Write-Host "Staging directory: $stagingDir"

& LabVIEWCLI `
    -LogToConsole TRUE `
    -OperationName MassCompile `
    -DirectoryToCompile $stagingDir `
    -LabVIEWPath $LabVIEWPath `
    -Headless

if ($LASTEXITCODE -ne 0) {
    throw "LabVIEWCLI MassCompile failed with exit code $LASTEXITCODE."
}

Write-Host "MassCompile completed successfully."
