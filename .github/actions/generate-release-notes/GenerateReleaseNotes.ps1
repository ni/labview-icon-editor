param(
    [string]$OutputPath = "Tooling/deployment/release_notes.md"
)

$repoRoot = (Get-Location).Path
$lvversionPath = Join-Path $repoRoot '.lvversion'
if (-not (Test-Path -Path $lvversionPath -PathType Leaf)) {
    throw ".lvversion not found at $lvversionPath"
}
$minimumSupportedLabVIEWVersion = (Get-Content -Raw -Path $lvversionPath).Trim()
if ([string]::IsNullOrWhiteSpace($minimumSupportedLabVIEWVersion)) {
    throw ".lvversion is empty; cannot generate release notes."
}

# Ensure git history is available
git fetch --tags --unshallow 2>$null | Out-Null

$latestTag = git describe --tags --abbrev=0 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($latestTag)) {
    $log = git log --pretty=format:'- %s (%h)' --no-merges
} else {
    $log = git log "$latestTag..HEAD" --pretty=format:'- %s (%h)' --no-merges
}
if (-not $log) {
    $log = "- Initial release"
} else {
    $log = $log -join "`n"
}
$notes = @(
    '# Release Notes'
    ''
    "Minimum supported LabVIEW version: $minimumSupportedLabVIEWVersion"
    ''
    $log
    ''
) -join "`n"
$fullPath = Join-Path (Get-Location) $OutputPath
$directory = Split-Path $fullPath
if (-not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
Set-Content -Path $fullPath -Value $notes
Write-Host "Release notes written to $fullPath"
