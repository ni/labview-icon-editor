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

function Resolve-ProductHomepageUrl {
    param(
        [string]$ProductHomepageUrl,
        [string]$RepoPath,
        [string]$DefaultOwner = 'ni'
    )

    # Explicit override wins
    if (-not [string]::IsNullOrWhiteSpace($ProductHomepageUrl)) {
        return $ProductHomepageUrl
    }

    if ([string]::IsNullOrWhiteSpace($RepoPath)) {
        return "https://github.com/$DefaultOwner"
    }

    $resolvedRepo = $null
    try {
        $resolvedRepo = (Resolve-Path -LiteralPath $RepoPath -ErrorAction Stop).Path
    }
    catch {
        return "https://github.com/$DefaultOwner"
    }

    $owner = $DefaultOwner
    $repoName = Split-Path -Leaf $resolvedRepo

    try {
        $remote = git -C $resolvedRepo remote get-url origin 2>$null
        if ($remote) {
            $pattern = [regex]::Escape("github.com") + "[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\\.git)?$"
            $match = [regex]::Match($remote.Trim(), $pattern, 'IgnoreCase')
            if ($match.Success) {
                if ($match.Groups['owner'].Value) { $owner = $match.Groups['owner'].Value }
                if ($match.Groups['repo'].Value)  { $repoName = $match.Groups['repo'].Value }
            }
        }
    }
    catch {
        # Ignore git failures and fall back to defaults
        $global:LASTEXITCODE = 0
    }

    return ("https://github.com/{0}/{1}" -f $owner, $repoName)
}
