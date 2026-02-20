#Requires -Version 7.0

function Add-ModulePathPrefix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath
    )

    $resolvedPath = (Resolve-Path -LiteralPath $ModulePath).Path
    $separator = [System.IO.Path]::PathSeparator
    $currentParts = @()
    if (-not [string]::IsNullOrWhiteSpace($env:PSModulePath)) {
        $currentParts = @($env:PSModulePath -split [regex]::Escape([string]$separator))
    }

    $normalizedCurrentParts = @($currentParts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($normalizedCurrentParts -contains $resolvedPath) {
        return
    }

    $combinedParts = @($resolvedPath) + $normalizedCurrentParts
    $env:PSModulePath = ($combinedParts -join [string]$separator)
}

function Test-IsOneDrivePath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path,
        [string[]]$KnownOneDriveRoots
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $resolvedPath = $Path
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    } catch {
        # Keep original path when resolution fails.
    }

    foreach ($root in $KnownOneDriveRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        if ($resolvedPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return ($resolvedPath -match '(?i)\\OneDrive(\\|$)')
}

function Get-KnownOneDriveRoots {
    [CmdletBinding()]
    param()

    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        try {
            $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
            if (-not $roots.Contains($resolved)) {
                $roots.Add($resolved)
            }
        } catch {
            if (-not $roots.Contains($candidate)) {
                $roots.Add($candidate)
            }
        }
    }

    return @($roots)
}

function Copy-PesterCandidateToLocalCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Candidate,
        [Parameter(Mandatory = $true)]
        [string]$LocalPesterRoot
    )

    $candidateVersion = $Candidate.Version.ToString()
    $destinationVersionRoot = Join-Path $LocalPesterRoot $candidateVersion
    $destinationManifest = Join-Path $destinationVersionRoot 'Pester.psd1'
    if (Test-Path -LiteralPath $destinationManifest -PathType Leaf) {
        return
    }

    New-Item -Path $destinationVersionRoot -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $Candidate.ModuleBase '*') -Destination $destinationVersionRoot -Recurse -Force
}

function Get-PreferredPesterCandidate {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Candidates,
        [string[]]$KnownOneDriveRoots
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) {
        return $null
    }

    $preferred = @(
        $Candidates |
            Where-Object { -not (Test-IsOneDrivePath -Path $_.ModuleBase -KnownOneDriveRoots $KnownOneDriveRoots) } |
            Select-Object -First 1
    )
    if ($preferred.Count -gt 0 -and $preferred[0]) {
        return $preferred[0]
    }

    return $Candidates[0]
}

function Import-RepoPester {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [version]$MinimumVersion = [version]'5.0.0',
        [switch]$AllowInstallFromGallery
    )

    $repoRootResolved = (Resolve-Path -LiteralPath $RepoRoot).Path
    $localModuleRoot = Join-Path $repoRootResolved 'Tooling\.cache\powershell\Modules'
    $localPesterRoot = Join-Path $localModuleRoot 'Pester'
    New-Item -Path $localPesterRoot -ItemType Directory -Force | Out-Null
    Add-ModulePathPrefix -ModulePath $localModuleRoot

    $localCandidates = @(
        Get-Module -ListAvailable -Name Pester |
            Where-Object { $_.Version -ge $MinimumVersion -and $_.ModuleBase.StartsWith($localPesterRoot, [System.StringComparison]::OrdinalIgnoreCase) } |
            Sort-Object Version -Descending
    )

    if ($localCandidates.Count -eq 0) {
        $knownOneDriveRoots = Get-KnownOneDriveRoots
        $allCandidates = @(
            Get-Module -ListAvailable -Name Pester |
                Where-Object { $_.Version -ge $MinimumVersion } |
                Sort-Object Version -Descending
        )

        $candidate = $null
        if ($allCandidates.Count -gt 0) {
            $candidate = Get-PreferredPesterCandidate -Candidates $allCandidates -KnownOneDriveRoots $knownOneDriveRoots
        }
        if ($candidate) {
            Copy-PesterCandidateToLocalCache -Candidate $candidate -LocalPesterRoot $localPesterRoot
        } elseif ($AllowInstallFromGallery) {
            Save-Module -Name Pester -MinimumVersion $MinimumVersion -Path $localModuleRoot -Force -ErrorAction Stop
        } else {
            throw ("Pester >= {0} not found and local installation is disabled." -f $MinimumVersion)
        }

        $localCandidates = @(
            Get-Module -ListAvailable -Name Pester |
                Where-Object { $_.Version -ge $MinimumVersion -and $_.ModuleBase.StartsWith($localPesterRoot, [System.StringComparison]::OrdinalIgnoreCase) } |
                Sort-Object Version -Descending
        )
    }

    if ($localCandidates.Count -eq 0) {
        throw ("Unable to resolve local cached Pester >= {0} under {1}." -f $MinimumVersion, $localPesterRoot)
    }

    $selected = $localCandidates[0]
    $manifestPath = Join-Path $selected.ModuleBase 'Pester.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Pester manifest not found in local cache: $manifestPath"
    }

    $loadedPester = Get-Module -Name Pester -ErrorAction SilentlyContinue
    if ($loadedPester -and -not $loadedPester.ModuleBase.StartsWith($localPesterRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
    }

    Import-Module -Name $manifestPath -Force -ErrorAction Stop | Out-Null
    if (-not (Get-Command -Name New-PesterConfiguration -ErrorAction SilentlyContinue)) {
        throw ("Loaded Pester {0} but New-PesterConfiguration is unavailable. Ensure Pester >= {1}." -f $selected.Version, $MinimumVersion)
    }

    $imported = Get-Module -Name Pester -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Version         = $imported.Version.ToString()
        ModuleBase      = $imported.ModuleBase
        LocalModuleRoot = $localModuleRoot
    }
}
