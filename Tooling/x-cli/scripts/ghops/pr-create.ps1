<#
.SYNOPSIS
Creates a branch from base, pushes it, and opens a PR.

.PARAMETER Branch
The branch name to create/push.

.PARAMETER Title
Pull request title.

.PARAMETER BodyFile
Optional path to a PR body file.

.PARAMETER Base
Base branch (default: develop).

.PARAMETER Labels
Comma-separated labels to apply.

.PARAMETER Draft
Open PR as draft.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)] [string]$Branch,
    [Parameter(Mandatory=$true, Position=1)] [string]$Title,
    [Parameter(Position=2)] [string]$BodyFile,
    [string]$Base = 'develop',
    [string]$Labels,
    [switch]$Draft,
    [switch]$DryRun,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/util-common.ps1"

Ensure-Git -AllowDryRun:$DryRun
Ensure-Gh  -AllowDryRun:$DryRun

$repo = Get-RepoSlug
Initialize-Log -DryRun:$DryRun -Repo $repo -Json:$Json

try {
    Invoke-Logged -DryRun:$DryRun -Cmd @('git','fetch','origin',$Base)
} catch {
}

# Try to base on origin/<base>, fall back to local <base>
try {
    Invoke-Logged -DryRun:$DryRun -Cmd @('git','checkout','-B',$Branch,"origin/$Base")
} catch {
    Invoke-Logged -DryRun:$DryRun -Cmd @('git','checkout','-B',$Branch,$Base)
}

Invoke-Logged -DryRun:$DryRun -Cmd @('git','push','-u','origin',$Branch)

$argsList = @('-R', $repo, '-B', $Base, '-H', $Branch, '-t', $Title)

if ($BodyFile -and (Test-Path -LiteralPath $BodyFile)) {
    $argsList += @('-F', $BodyFile)
}

if ($Labels) {
    ($Labels -split ',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.Length -gt 0 } |
        ForEach-Object { $argsList += @('--label', $_) }
}

if ($Draft.IsPresent) {
    $argsList += '--draft'
}

$cmd = @('gh','pr','create') + $argsList
Invoke-Logged -DryRun:$DryRun -Cmd $cmd

$extra = @{ branch = $Branch; base = $Base; draft = [bool]$Draft; title = $Title }
if ($BodyFile) { $extra.bodyFile = (Resolve-Path -LiteralPath $BodyFile).Path }
if ($Labels)   { $extra.labels  = ($Labels -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
Flush-Log -Json:$Json -Extra $extra
