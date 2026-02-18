#Requires -Version 7.0
<#
.SYNOPSIS
    Resolve VI Analyzer container metadata from .lvcontainer.

.DESCRIPTION
    Accepts a literal NI LabVIEW container tag (for example, "2026q1-linux"
    or "latest-windows") and returns deterministic metadata used by CI.
    When VersionInput is empty, the function reads .lvcontainer from RepoRoot.
    Live tag discovery uses Docker Hub and falls back to a committed snapshot.
#>

function Get-LabVIEWContainerReleaseInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VersionInput,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$CatalogSnapshotPath,

        [Parameter(Mandatory = $false)]
        [string]$DockerHubTagsApi = 'https://hub.docker.com/v2/repositories/nationalinstruments/labview/tags?page_size=100',

        [Parameter(Mandatory = $false)]
        [switch]$DisableLiveDiscovery
    )

    function Get-DefaultSnapshotPath {
        param([string]$ResolvedRepoRoot)

        if (-not [string]::IsNullOrWhiteSpace($ResolvedRepoRoot)) {
            return Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling/container-parity/labview-container-tags.snapshot.json'
        }

        $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
        return [System.IO.Path]::GetFullPath((Join-Path -Path $scriptRoot -ChildPath '../container-parity/labview-container-tags.snapshot.json'))
    }

    function Get-NormalizedContainerOperatingSystem {
        param(
            [string]$OsInput,
            [string]$Tag
        )

        $os = if ([string]::IsNullOrWhiteSpace($OsInput)) { '' } else { $OsInput.Trim().ToLowerInvariant() }
        if ($os -eq 'linux') {
            return 'linux'
        }
        if ($os.StartsWith('windows')) {
            return 'windows'
        }

        if ($Tag -match '-linux$') {
            return 'linux'
        }
        if ($Tag -match '-windows(?:-beta)?$') {
            return 'windows'
        }

        return ''
    }

    function Get-TagMetadataFromPattern {
        param(
            [string]$Tag,
            [string]$LatestYear
        )

        $releaseTag = $null
        $minorRevision = $null
        $year = $null

        $releaseMatch = [regex]::Match($Tag, '^(?<year>\d{4})q(?<quarter>[1-4])(?:patch\d+)?-(?<suffix>linux|windows(?:-beta)?)$')
        if ($releaseMatch.Success) {
            $year = $releaseMatch.Groups['year'].Value
            $minorRevision = [int]$releaseMatch.Groups['quarter'].Value
            $releaseTag = '{0}q{1}' -f $year, $releaseMatch.Groups['quarter'].Value
            return [pscustomobject]@{
                Year          = $year
                MinorRevision = $minorRevision
                ReleaseTag    = $releaseTag
            }
        }

        $latestMatch = [regex]::Match($Tag, '^latest-(linux|windows)$')
        if ($latestMatch.Success) {
            $year = if ([string]::IsNullOrWhiteSpace($LatestYear)) { '2026' } else { $LatestYear }
            $minorRevision = 1
            $releaseTag = '{0}q1' -f $year
            return [pscustomobject]@{
                Year          = $year
                MinorRevision = $minorRevision
                ReleaseTag    = $releaseTag
            }
        }

        return $null
    }

    function Get-ContainerTagCatalogFromSnapshot {
        param([string]$SnapshotPath)

        if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
            throw 'Snapshot path is empty.'
        }

        $resolvedPath = [System.IO.Path]::GetFullPath($SnapshotPath)
        if (-not (Test-Path -Path $resolvedPath -PathType Leaf)) {
            throw "Container tag snapshot was not found: $resolvedPath"
        }

        $doc = Get-Content -Path $resolvedPath -Raw | ConvertFrom-Json
        $tags = @($doc.tags)
        if ($tags.Count -eq 0) {
            throw "Container tag snapshot has no tags: $resolvedPath"
        }

        $entries = New-Object System.Collections.Generic.List[object]
        foreach ($entry in $tags) {
            $tag = [string]$entry.tag
            if ([string]::IsNullOrWhiteSpace($tag)) {
                continue
            }

            $os = Get-NormalizedContainerOperatingSystem -OsInput ([string]$entry.os) -Tag $tag
            $entries.Add([pscustomobject]@{
                    Tag           = $tag.Trim()
                    Os            = $os
                    Year          = if ($null -eq $entry.year) { $null } else { [string]$entry.year }
                    MinorRevision = if ($null -eq $entry.minorRevision) { $null } else { [int]$entry.minorRevision }
                    ReleaseTag    = if ($null -eq $entry.releaseTag) { $null } else { [string]$entry.releaseTag }
                }) | Out-Null
        }

        if ($entries.Count -eq 0) {
            throw "Container tag snapshot has no valid entries: $resolvedPath"
        }

        return [pscustomobject]@{
            Source     = 'snapshot'
            LatestYear = if ($null -eq $doc.latestYear) { '2026' } else { [string]$doc.latestYear }
            Entries    = $entries.ToArray()
            Path       = $resolvedPath
        }
    }

    function Get-ContainerTagCatalogFromDockerHub {
        param([string]$ApiUrl)

        if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
            throw 'DockerHubTagsApi is empty.'
        }

        $nextUrl = $ApiUrl
        $entries = New-Object System.Collections.Generic.List[object]
        while (-not [string]::IsNullOrWhiteSpace($nextUrl)) {
            $response = Invoke-RestMethod -Uri $nextUrl -Method Get -ErrorAction Stop
            foreach ($result in @($response.results)) {
                $tag = [string]$result.name
                if ([string]::IsNullOrWhiteSpace($tag)) {
                    continue
                }

                $os = ''
                foreach ($img in @($result.images)) {
                    $imgOs = [string]$img.os
                    if (-not [string]::IsNullOrWhiteSpace($imgOs)) {
                        $os = Get-NormalizedContainerOperatingSystem -OsInput $imgOs -Tag $tag
                        if (-not [string]::IsNullOrWhiteSpace($os)) {
                            break
                        }
                    }
                }

                if ([string]::IsNullOrWhiteSpace($os)) {
                    $os = Get-NormalizedContainerOperatingSystem -OsInput '' -Tag $tag
                }

                $entries.Add([pscustomobject]@{
                        Tag           = $tag.Trim()
                        Os            = $os
                        Year          = $null
                        MinorRevision = $null
                        ReleaseTag    = $null
                    }) | Out-Null
            }

            $nextUrl = [string]$response.next
        }

        if ($entries.Count -eq 0) {
            throw "Docker Hub returned no tags from $ApiUrl"
        }

        return [pscustomobject]@{
            Source     = 'live'
            LatestYear = '2026'
            Entries    = $entries.ToArray()
            Path       = $null
        }
    }

    function Resolve-EntryInfo {
        param(
            [object]$Entry,
            [string]$LatestYear
        )

        $tag = [string]$Entry.Tag
        $os = Get-NormalizedContainerOperatingSystem -OsInput ([string]$Entry.Os) -Tag $tag

        $year = if ($null -eq $Entry.Year) { '' } else { [string]$Entry.Year }
        $minor = if ($null -eq $Entry.MinorRevision) { $null } else { [int]$Entry.MinorRevision }
        $releaseTag = if ($null -eq $Entry.ReleaseTag) { '' } else { [string]$Entry.ReleaseTag }

        if ([string]::IsNullOrWhiteSpace($year) -or $null -eq $minor -or [string]::IsNullOrWhiteSpace($releaseTag)) {
            $derived = Get-TagMetadataFromPattern -Tag $tag -LatestYear $LatestYear
            if ($null -eq $derived) {
                throw "Tag '$tag' is supported by catalog but has unsupported metadata format. Add explicit mapping in snapshot."
            }

            if ([string]::IsNullOrWhiteSpace($year)) {
                $year = [string]$derived.Year
            }
            if ($null -eq $minor) {
                $minor = [int]$derived.MinorRevision
            }
            if ([string]::IsNullOrWhiteSpace($releaseTag)) {
                $releaseTag = [string]$derived.ReleaseTag
            }
        }

        if ([string]::IsNullOrWhiteSpace($os)) {
            throw "Unable to resolve OS for container tag '$tag'."
        }

        return [pscustomobject]@{
            Tag           = $tag
            Os            = $os
            Year          = $year
            MinorRevision = $minor
            ReleaseTag    = $releaseTag
        }
    }

    $inputProvided = -not [string]::IsNullOrWhiteSpace($VersionInput)
    $raw = if ($inputProvided) { $VersionInput.Trim() } else { '' }
    $repoRaw = $null

    $resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { '' } else { (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path }
    $versionPath = if ([string]::IsNullOrWhiteSpace($resolvedRepoRoot)) { $null } else { Join-Path -Path $resolvedRepoRoot -ChildPath '.lvcontainer' }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        if ([string]::IsNullOrWhiteSpace($resolvedRepoRoot)) {
            throw 'RepoRoot is required when VersionInput is not provided.'
        }

        if (-not (Test-Path -Path $versionPath -PathType Leaf)) {
            throw ".lvcontainer not found at $versionPath"
        }

        $repoRaw = (Get-Content -Raw -Path $versionPath).Trim()
        $raw = $repoRaw
    } elseif (-not [string]::IsNullOrWhiteSpace($resolvedRepoRoot)) {
        if (-not (Test-Path -Path $versionPath -PathType Leaf)) {
            throw ".lvcontainer not found at $versionPath"
        }

        $repoRaw = (Get-Content -Raw -Path $versionPath).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw 'LabVIEW container tag input is empty.'
    }

    $snapshotPath = if ([string]::IsNullOrWhiteSpace($CatalogSnapshotPath)) {
        Get-DefaultSnapshotPath -ResolvedRepoRoot $resolvedRepoRoot
    } else {
        [System.IO.Path]::GetFullPath($CatalogSnapshotPath)
    }

    $snapshotCatalog = $null
    $latestYear = '2026'
    try {
        $snapshotCatalog = Get-ContainerTagCatalogFromSnapshot -SnapshotPath $snapshotPath
        if (-not [string]::IsNullOrWhiteSpace([string]$snapshotCatalog.LatestYear)) {
            $latestYear = [string]$snapshotCatalog.LatestYear
        }
    } catch {
        if ($DisableLiveDiscovery) {
            throw $_.Exception
        }
    }

    $catalog = $null
    $liveError = $null
    if (-not $DisableLiveDiscovery) {
        try {
            $catalog = Get-ContainerTagCatalogFromDockerHub -ApiUrl $DockerHubTagsApi
            if ($null -ne $snapshotCatalog -and -not [string]::IsNullOrWhiteSpace([string]$snapshotCatalog.LatestYear)) {
                $catalog.LatestYear = [string]$snapshotCatalog.LatestYear
            }
        } catch {
            $liveError = $_.Exception.Message
        }
    }

    if ($null -eq $catalog) {
        if ($null -eq $snapshotCatalog) {
            if ([string]::IsNullOrWhiteSpace($liveError)) {
                throw "Unable to resolve container tag catalog. Snapshot path: $snapshotPath"
            }

            throw ("Unable to resolve container tag catalog from Docker Hub and no valid snapshot was available. Live error: {0}" -f $liveError)
        }

        $catalog = $snapshotCatalog
    }

    $tagMap = @{}
    foreach ($entry in @($catalog.Entries)) {
        $tag = [string]$entry.Tag
        if ([string]::IsNullOrWhiteSpace($tag)) {
            continue
        }

        if (-not $tagMap.ContainsKey($tag.ToLowerInvariant())) {
            $tagMap[$tag.ToLowerInvariant()] = $entry
        }
    }

    $lookupKey = $raw.ToLowerInvariant()
    if (-not $tagMap.ContainsKey($lookupKey)) {
        $allowed = $tagMap.Keys |
            Sort-Object |
            ForEach-Object { $tagMap[$_].Tag } |
            Select-Object -Unique
        throw ("Unsupported .lvcontainer tag '{0}'. Allowed tags: {1}" -f $raw, ($allowed -join ', '))
    }

    $selectedEntry = $tagMap[$lookupKey]
    $metadata = Resolve-EntryInfo -Entry $selectedEntry -LatestYear ([string]$catalog.LatestYear)

    if ($inputProvided -and -not [string]::IsNullOrWhiteSpace($repoRaw)) {
        if (-not [string]::Equals($raw, $repoRaw, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "LabVIEW container tag '$raw' does not match .lvcontainer '$repoRaw'."
        }
    }

    $tag = [string]$metadata.Tag
    $image = 'nationalinstruments/labview:{0}' -f $tag
    $linuxImage = if ($metadata.Os -eq 'linux') { $image } else { '' }
    $numericMajor = [int]$metadata.Year - 2000
    $numericVersion = '{0}.{1}' -f $numericMajor, [int]$metadata.MinorRevision

    return [pscustomobject]@{
        Raw            = $raw
        Tag            = $tag
        Image          = $image
        Os             = [string]$metadata.Os
        Year           = [string]$metadata.Year
        MinorRevision  = [int]$metadata.MinorRevision
        NumericMajor   = $numericMajor
        NumericVersion = $numericVersion
        ReleaseTag     = [string]$metadata.ReleaseTag
        LinuxImage     = $linuxImage
        CatalogSource  = [string]$catalog.Source
    }
}
