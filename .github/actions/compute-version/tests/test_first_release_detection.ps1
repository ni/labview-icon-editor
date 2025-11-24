$ErrorActionPreference = 'Stop'
function New-TempRepo {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string] $Name)
    $root = if ($Env:RUNNER_TEMP) { $Env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    $path = Join-Path -Path $root -ChildPath $Name
    if (Test-Path $path -PathType Any) {
        if ($PSCmdlet.ShouldProcess($path, "Remove existing temp repo")) {
            Remove-Item -Recurse -Force $path
        }
    }
    New-Item -ItemType Directory -Path $path | Out-Null
    Push-Location $path
    git init | Out-Null
    git config user.email "test@example.com"
    git config user.name "Test User"
    Set-Content -Path file.txt -Value "init"
    git add file.txt
    git commit -m "init" | Out-Null
    return $path
}

$parentPath = Join-Path -Path $PSScriptRoot -ChildPath ".."
$scriptPath = Join-Path -Path $parentPath -ChildPath "Get-LastTag.ps1"

# No-tag scenario should be marked as first release
$repo = New-TempRepo -Name ("compute-version-no-tags-" + [guid]::NewGuid())
try {
    $info = & "$scriptPath" -AsJson | ConvertFrom-Json
    if (-not $info.IsFirstRelease) {
        throw "Expected IsFirstRelease when no tags exist."
    }
    if ($info.LastTag) {
        throw "Expected LastTag to be empty when no tags exist."
    }
    try {
        & "$scriptPath" -AsJson -RequireTag | Out-Null
        throw "Expected RequireTag to throw when no tags exist."
    }
    catch {
        if ($_.Exception.Message -notlike "*Create the first semantic version tag*") {
            throw "RequireTag error message did not mention creating the first tag. Actual: $($_.Exception.Message)"
        }
    }
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $repo
}

# With a tag present, should not be marked as first release
$repo2 = New-TempRepo -Name ("compute-version-with-tag-" + [guid]::NewGuid())
try {
    git tag v0.1.0
    $info = & "$scriptPath" -AsJson | ConvertFrom-Json
    if ($info.IsFirstRelease) {
        throw "Did not expect IsFirstRelease after adding a tag."
    }
    if ($info.LastTag -ne 'v0.1.0') {
        throw "Expected LastTag to be v0.1.0, got '$($info.LastTag)'."
    }
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $repo2
}

Write-Output "First release detection tests passed."
