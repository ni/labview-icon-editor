<#
.SYNOPSIS
Generates a VSCode tasks manifest JSON file with provenance information.

.DESCRIPTION
Creates a manifest file containing metadata about the .vscode/tasks.json file,
including commit information, author details, file hashes, and other provenance data.

.PARAMETER RepositoryPath
Path to the repository root. Defaults to current directory.

.PARAMETER OutputPath
Path where the manifest JSON file will be written.

.PARAMETER Commit
Git commit SHA. If not provided, uses git to get HEAD commit.

.PARAMETER Ref
Git ref (branch/tag). Optional.

.PARAMETER RunId
GitHub Actions run ID. Optional.

.PARAMETER RunAttempt
GitHub Actions run attempt. Optional.

.PARAMETER Repository
GitHub repository slug (owner/repo). Optional.

.PARAMETER Actor
GitHub actor who triggered the workflow. Optional.

.EXAMPLE
./generate-vscode-tasks-manifest.ps1 -RepositoryPath /repo -OutputPath /out/manifest.json -Commit abc123
#>
[CmdletBinding()]
param(
    [Parameter()][string]$RepositoryPath = '.',
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter()][string]$Commit,
    [Parameter()][string]$Ref,
    [Parameter()][string]$RunId,
    [Parameter()][string]$RunAttempt,
    [Parameter()][string]$Repository,
    [Parameter()][string]$Actor
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$SchemaVersion = 'urn:vscode-tasks-manifest:v1'

# Resolve repository path
$RepositoryPath = Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop

# Locate tasks.json
$tasksFile = Join-Path $RepositoryPath '.vscode/tasks.json'
if (-not (Test-Path -LiteralPath $tasksFile -PathType Leaf)) {
    throw "VSCode tasks.json not found at $tasksFile"
}

# Get file info and hash
$fileInfo = Get-Item -LiteralPath $tasksFile
$hash = (Get-FileHash -LiteralPath $tasksFile -Algorithm SHA256).Hash.ToLower()

# Get commit SHA if not provided
if ([string]::IsNullOrWhiteSpace($Commit)) {
    Push-Location $RepositoryPath
    try {
        $Commit = git rev-parse HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Commit)) {
            $Commit = 'unknown'
        }
        $global:LASTEXITCODE = 0  # Clear git exit code
    }
    finally {
        Pop-Location
    }
}

# Get commit author information from git
Push-Location $RepositoryPath
try {
    $commitAuthorName = git log -1 --format='%an' 2>$null
    $global:LASTEXITCODE = 0  # Clear git exit code
}
finally {
    Pop-Location
}

if ([string]::IsNullOrWhiteSpace($commitAuthorName)) {
    $commitAuthorName = $Actor
    if ([string]::IsNullOrWhiteSpace($commitAuthorName)) {
        $commitAuthorName = 'unknown'
    }
}

# Always use noreply email to avoid exposing personal emails in artifacts
if (-not [string]::IsNullOrWhiteSpace($Actor)) {
    $commitAuthorEmail = "$Actor@users.noreply.github.com"
}
else {
    $commitAuthorEmail = 'unknown@users.noreply.github.com'
}

# Build manifest object
$manifest = [ordered]@{
    schema           = $SchemaVersion
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    commit           = $Commit
    commit_author    = [ordered]@{
        name  = $commitAuthorName
        email = $commitAuthorEmail
    }
    ref              = if ([string]::IsNullOrWhiteSpace($Ref)) { $null } else { $Ref }
    run_id           = if ([string]::IsNullOrWhiteSpace($RunId)) { $null } else { $RunId }
    run_attempt      = if ([string]::IsNullOrWhiteSpace($RunAttempt)) { $null } else { $RunAttempt }
    repository       = if ([string]::IsNullOrWhiteSpace($Repository)) { $null } else { $Repository }
    actor            = if ([string]::IsNullOrWhiteSpace($Actor)) { $null } else { $Actor }
    files            = @(
        [ordered]@{
            path       = '.vscode/tasks.json'
            size_bytes = $fileInfo.Length
            sha256     = $hash
        }
    )
}

# Ensure output directory exists
$outDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Write manifest JSON
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Generated VSCode tasks manifest at $OutputPath"
Write-Host "Commit: $Commit"
Write-Host "Author: $commitAuthorName"
Write-Host "File hash: $hash"

# Return manifest path for caller
$OutputPath
