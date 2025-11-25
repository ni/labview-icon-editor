# Utility helpers for build metadata resolution (repo owner, company/author names).

function Get-RepoOwner {
    param([string]$RepoPath)

    if ([string]::IsNullOrWhiteSpace($RepoPath)) {
        return ''
    }

    $resolved = $null
    try {
        $resolved = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).Path
    }
    catch {
        return ''
    }

    try {
        $remote = git -C $resolved remote get-url origin 2>$null
        if ($remote -and ($remote -match '[:/]([^/]+)/([^/]+?)(\.git)?$')) {
            return $Matches[1]
        }
    }
    catch {
        # Fall through to folder name
    }

    return (Split-Path -Leaf $resolved)
}

function Resolve-CompanyName {
    param(
        [string]$CompanyName,
        [string]$RepoPath
    )

    if (-not [string]::IsNullOrWhiteSpace($CompanyName) -and $CompanyName -ne 'LabVIEW-Community-CI-CD') {
        return $CompanyName
    }

    return Get-RepoOwner -RepoPath $RepoPath
}

function Resolve-AuthorName {
    param(
        [string]$AuthorName,
        [string]$RepoPath
    )

    if (-not [string]::IsNullOrWhiteSpace($AuthorName) -and $AuthorName -ne 'Local Developer') {
        return $AuthorName
    }

    return Get-RepoOwner -RepoPath $RepoPath
}
