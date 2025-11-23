#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$DiffPrefix,
    [string]$Workspace = $Env:GITHUB_WORKSPACE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Workspace) {
    $Workspace = (Get-Location).Path
} else {
    $Workspace = (Resolve-Path $Workspace).Path
}

Set-Location $Workspace

$dirty = git status --porcelain
if (-not $dirty) {
    Write-Host "No changes detected; skipping diff report."
    exit 0
}

$projFiles = git ls-files "*.lvproj"
if (-not $projFiles) {
    Write-Host "No tracked .lvproj files found."
    exit 0
}

$hasDiff = $false
foreach ($pf in $projFiles) {
    $diff = git diff -- $pf
    if (-not $diff) { continue }

    $leaf    = Split-Path $pf -Leaf
    $outFile = "post_mip_dirty_${DiffPrefix}_${leaf}.diff"
    $diff | Out-File $outFile -Encoding utf8

    Write-Host "Workspace became dirty during $Label for $pf. Diff follows:"
    Write-Host "------ $pf diff ($DiffPrefix) ------"
    Write-Host ($diff -join [Environment]::NewLine)
    Write-Host "----------------------------------------------"

    if ($Env:GITHUB_STEP_SUMMARY) {
        Add-Content -Path $Env:GITHUB_STEP_SUMMARY -Value ("### Workspace changed during {0}" -f $Label) -Encoding utf8
        Add-Content -Path $Env:GITHUB_STEP_SUMMARY -Value ("File: {0}" -f $pf) -Encoding utf8
        Add-Content -Path $Env:GITHUB_STEP_SUMMARY -Value '```diff' -Encoding utf8
        Add-Content -Path $Env:GITHUB_STEP_SUMMARY -Value ($diff -join [Environment]::NewLine) -Encoding utf8
        Add-Content -Path $Env:GITHUB_STEP_SUMMARY -Value '```' -Encoding utf8
    }

    git checkout -- $pf
    $hasDiff = $true
}

if ($hasDiff -and $Env:GITHUB_OUTPUT) {
    'found_diff=true' | Out-File -FilePath $Env:GITHUB_OUTPUT -Append -Encoding utf8
}

exit 0
