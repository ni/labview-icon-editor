param(
    [string]$OutputPath = "Tooling/deployment/release_notes.md"
)

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
$notes = "# Release Notes`n`n$log`n"
$fullPath = Join-Path (Get-Location) $OutputPath
$directory = Split-Path $fullPath
if (-not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
Set-Content -Path $fullPath -Value $notes
Write-Host "Release notes written to $fullPath"
