# Shared helper functions for build and packaging workflows.

function Get-LabVIEWVersionOrFail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath
    )

    $resolved = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).Path
    $script = Join-Path -Path $resolved -ChildPath "scripts/get-package-lv-version.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        throw "get-package-lv-version.ps1 not found at $script"
    }

    $lv = & $script -RepositoryPath $resolved
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($lv)) {
        throw "Failed to derive LabVIEW version from VIPB under $resolved."
    }
    return $lv
}

function Get-CanonicalVipcPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath
    )

    $resolved = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).Path
    $vipcPath = Join-Path $resolved ".github\actions\apply-vipc\runner_dependencies.vipc"
    if (-not (Test-Path -LiteralPath $vipcPath)) {
        throw "Canonical runner_dependencies.vipc not found at $vipcPath. Copy or fetch it to match CI before building."
    }
    return $vipcPath
}

function Assert-DevModePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][ValidateSet('32','64')][string]$Bitness,
        [switch]$WarnOnly
    )

    $pathsScript = Join-Path -Path $RepoPath -ChildPath "scripts/read-library-paths.ps1"
    if (-not (Test-Path -LiteralPath $pathsScript)) { return }

    if ($WarnOnly) {
        & $pathsScript -RepositoryPath $RepoPath -SupportedBitness $Bitness
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("LocalHost.LibraryPaths preflight failed for {0}-bit (non-blocking). Run 'Revert Dev Mode' then 'Set Dev Mode' for {0}-bit to refresh paths." -f $Bitness)
        }
        return
    }

    & $pathsScript -RepositoryPath $RepoPath -SupportedBitness $Bitness -FailOnMissing
    if ($LASTEXITCODE -ne 0) {
        throw ("LocalHost.LibraryPaths preflight failed for {0}-bit. Run 'Revert Dev Mode' then 'Set Dev Mode' for {0}-bit to refresh paths." -f $Bitness)
    }
}

Export-ModuleMember -Function Get-LabVIEWVersionOrFail, Get-CanonicalVipcPath, Assert-DevModePaths
