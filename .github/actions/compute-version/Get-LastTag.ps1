# Returns the last reachable tag and whether this is the first release scenario.
param(
    [switch] $AsJson,
    [switch] $RequireTag
)

$ErrorActionPreference = 'Stop'

$tag = ''
try {
    $tag = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) {
        $tag = ''
    }
} catch {
    $tag = ''
}

$result = [PSCustomObject]@{
    LastTag        = $tag
    IsFirstRelease = [string]::IsNullOrWhiteSpace($tag)
}

if ($RequireTag -and $result.IsFirstRelease) {
    throw "No git tags were found. Create the first semantic version tag (for example, v0.1.0) so versioning can derive MAJOR/MINOR/PATCH."
}

if ($AsJson) {
    $result | ConvertTo-Json -Compress
} else {
    $result
}
