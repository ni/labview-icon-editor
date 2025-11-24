[CmdletBinding()]
param(
    [Parameter()][string]$RepositoryPath = ".",
    [Parameter()][string]$VipPath = "builds/VI Package",
    [Parameter()][string]$ReleaseNotesPath = "Tooling/deployment/release_notes.md",
    [Parameter()][string]$Tag,
    [Parameter()][string]$Title,
    [Parameter()][int]$Major,
    [Parameter()][int]$Minor,
    [Parameter()][int]$Patch,
    [Parameter()][int]$Build = 0,
    [Parameter()][object]$Prerelease = $true
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path -Path $RepositoryPath

function Get-GitHubToken {
    if ($Env:GH_TOKEN) { return $Env:GH_TOKEN }
    if ($Env:GITHUB_TOKEN) { return $Env:GITHUB_TOKEN }

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $token = & gh auth token 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)) {
                return $token.Trim()
            }
        }
        catch {
            $global:LASTEXITCODE = 0
        }
    }

    return $null
}

function Resolve-Asset {
    param(
        [string]$Path,
        [string]$Description,
        [string]$DefaultFilter
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path -Path $repoRoot -ChildPath $Path }

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return Get-Item -LiteralPath $candidate
    }

    $dir = $candidate
    $filter = $DefaultFilter

    if (-not (Test-Path -LiteralPath $dir)) {
        $dir = Split-Path -Path $candidate -Parent
        $leaf = Split-Path -Path $candidate -Leaf
        if ($leaf -and $leaf -ne '.' -and $leaf -ne '..') { $filter = $leaf }
    }
    elseif (Test-Path -LiteralPath $dir -PathType Leaf) {
        $dir = Split-Path -Path $candidate -Parent
    }

    $match = Get-ChildItem -Path $dir -Filter $filter -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $match) {
        throw ("{0} not found. Checked '{1}' with filter '{2}'." -f $Description, $dir, $filter)
    }

    return $match
}

Push-Location -LiteralPath $repoRoot

try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) not found. Install it and ensure it is on PATH."
    }

    $token = Get-GitHubToken
    if (-not $token) {
        throw "Set GH_TOKEN or GITHUB_TOKEN (or run 'gh auth login') so the GitHub CLI can create the draft release."
    }
    $Env:GH_TOKEN = $token

    # Treat "auto" and blank values as unset so the tag/title can be derived
    if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag -eq 'auto') {
        $Tag = $null
    }
    if ([string]::IsNullOrWhiteSpace($Title) -or $Title -eq 'auto') {
        $Title = $null
    }

    # Normalize prerelease to a boolean regardless of string input
    $isPrerelease = $false
    if ($Prerelease -is [bool]) {
        $isPrerelease = $Prerelease
    }
    elseif ($Prerelease -is [string]) {
        $normalized = $Prerelease.Trim().ToLowerInvariant()
        $isPrerelease = $normalized -in @('true', '1', 'yes', 'y', 'on')
    }

    # Derive build number from total commit count; fall back to provided Build
    $buildNumber = $Build
    try {
        git -C $repoRoot fetch --unshallow 2>$null | Out-Null
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    try {
        $count = git -C $repoRoot rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $count) {
            $buildNumber = [int]$count
            Write-Host ("Using build number from commit count: {0}" -f $buildNumber)
        }
    }
    catch {
        $global:LASTEXITCODE = 0
    }

    $vipFile = Resolve-Asset -Path $VipPath -Description "VI Package (.vip)" -DefaultFilter "*.vip"

    $notesFile = $null
    try {
        $notesFile = Resolve-Asset -Path $ReleaseNotesPath -Description "Release notes" -DefaultFilter "*.md"
    }
    catch {
        # Fall back to release_notes_*.md; if still missing, create the desired path
        $targetPath = if ([System.IO.Path]::IsPathRooted($ReleaseNotesPath)) {
            $ReleaseNotesPath
        } else {
            Join-Path -Path $repoRoot -ChildPath $ReleaseNotesPath
        }
        $notesDir = Split-Path -Path $targetPath -Parent
        if (-not (Test-Path -LiteralPath $notesDir)) {
            New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
        }
        $fallback = Get-ChildItem -Path $notesDir -Filter "release_notes_*.md" -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($fallback) {
            $notesFile = $fallback
        } else {
            New-Item -ItemType File -Path $targetPath -Force | Out-Null
            $notesFile = Get-Item -LiteralPath $targetPath
            Write-Host ("Created placeholder release notes at {0}" -f $notesFile.FullName)
        }
    }

    if (-not $Tag) {
        if ($PSBoundParameters.ContainsKey('Major') -and $PSBoundParameters.ContainsKey('Minor') -and $PSBoundParameters.ContainsKey('Patch')) {
            $Tag = ("v{0}.{1}.{2}.{3}" -f $Major, $Minor, $Patch, $buildNumber)
        }
        else {
            throw "Provide -Tag or all of -Major, -Minor, -Patch so a tag can be derived."
        }
    }

    if (-not $Title) {
        $Title = $Tag
    }

    $assetList = @($vipFile.FullName, $notesFile.FullName)

    $releaseExists = $false
    try {
        & gh release view $Tag *> $null
        $releaseExists = $LASTEXITCODE -eq 0
    }
    catch {
        $releaseExists = $false
        $global:LASTEXITCODE = 0
    }

    if ($releaseExists) {
        Write-Host ("Release {0} exists; updating draft metadata and refreshing assets." -f $Tag)
        $editArgs = @('release', 'edit', $Tag, '--draft', '--title', $Title, '--notes-file', $notesFile.FullName)
        if ($isPrerelease) { $editArgs += '--prerelease' }
        & gh @editArgs

        $uploadArgs = @('release', 'upload', $Tag) + $assetList + '--clobber'
        & gh @uploadArgs
    }
    else {
        Write-Host ("Creating draft release {0} and uploading assets." -f $Tag)
        $createArgs = @('release', 'create', $Tag) + $assetList + @('--draft', '--title', $Title, '--notes-file', $notesFile.FullName)
        if ($isPrerelease) { $createArgs += '--prerelease' }
        & gh @createArgs
    }

    Write-Host ("Attached assets:`n- {0}`n- {1}" -f $vipFile.Name, $notesFile.Name)
}
finally {
    Pop-Location
}
