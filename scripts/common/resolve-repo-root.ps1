<#
.SYNOPSIS
    Resolve the repository root by walking up from candidate paths.
.DESCRIPTION
    Given one or more starting paths, walks upward until it finds a directory
    containing a known repo marker (.git, lv_icon_editor.lvproj, scripts/, Tooling/).
    Returns the first match as a fully resolved path. Intended to make scripts
    robust when the current working directory or shell redirection changes
    (e.g., when OneDrive is enabled/disabled and known-folder paths move).
.PARAMETER StartPaths
    Candidate starting paths to probe, in priority order. If omitted, defaults
    to: $PSScriptRoot, current location, and the process working directory.
.EXAMPLE
    # Emit repo root when invoked directly
    pwsh resolve-repo-root.ps1
.EXAMPLE
    # Use from another script
    . "$PSScriptRoot/common/resolve-repo-root.ps1"
    $repo = Resolve-RepoRoot -StartPaths @($RepositoryPath, $PSScriptRoot, (Get-Location).Path)
#>
param(
    [string[]]$StartPaths
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepoRoot {
    param(
        [string[]]$StartPaths,
        [string[]]$Markers = @('.git', 'lv_icon_editor.lvproj', 'scripts', 'Tooling')
    )

    function Normalize-Path {
        param([string]$Path)
        if (-not $Path) { return $null }
        try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path }
        catch { return $null }
    }

    function Try-LocateRoot {
        param([string]$Path,[string[]]$Markers)
        $current = Normalize-Path -Path $Path
        if (-not $current) { return $null }
        while ($true) {
            foreach ($marker in $Markers) {
                if (-not $marker) { continue }
                $candidate = Join-Path $current $marker
                if (Test-Path -LiteralPath $candidate) { return $current }
            }
            $parent = Split-Path -Parent $current
            if (-not $parent -or $parent -eq $current) { break }
            $current = $parent
        }
        return $null
    }

    $candidates = @()
    if ($StartPaths) { $candidates += $StartPaths }
    if ($PSScriptRoot) { $candidates += $PSScriptRoot }
    try { $candidates += (Get-Location).Path } catch { }
    if ($PWD) { $candidates += $PWD }

    foreach ($cand in $candidates) {
        $root = Try-LocateRoot -Path $cand -Markers $Markers
        if ($root) { return $root }
    }
    return $null
}

# Emit the resolved path when invoked directly (not dot-sourced)
if ($MyInvocation.InvocationName -notin @('.', '&')) {
    $root = Resolve-RepoRoot -StartPaths $StartPaths
    if ($root) { Write-Output $root }
    else { throw 'Unable to resolve repository root from the provided start paths.' }
}
