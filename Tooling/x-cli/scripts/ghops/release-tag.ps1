<#
.SYNOPSIS
Creates a Git tag and GitHub Release with optional notes and attachments.

.PARAMETER Tag
Tag name (e.g., v1.2.3).

.PARAMETER Notes
Optional path to release notes file; otherwise generate notes.

.PARAMETER Attach
Optional file glob for assets to attach (e.g., 'dist/x-cli-*').
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)] [string]$Tag,
    [string]$Notes,
    [string]$Attach,
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
    Invoke-Logged -DryRun:$DryRun -Cmd @('git','tag','-s',$Tag,'-m',$Tag)
} catch {
    Invoke-Logged -DryRun:$DryRun -Cmd @('git','tag',$Tag,'-m',$Tag)
}

Invoke-Logged -DryRun:$DryRun -Cmd @('git','push','origin',$Tag)

$argsList = @('-R', $repo, $Tag)

if ($Notes -and (Test-Path -LiteralPath $Notes)) {
    $argsList += @('-F', $Notes)
} else {
    $argsList += '--generate-notes'
}

if ($Attach) {
    # Expand any wildcard pattern to concrete files if possible
    $files = @(Get-ChildItem -Path $Attach -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    if ($files.Count -gt 0) {
        $argsList += $files
    } else {
        # Fallback: pass the literal string; gh may handle globs depending on shell
        $argsList += $Attach
    }
}

${cmd} = @('gh','release','create') + $argsList
Invoke-Logged -DryRun:$DryRun -Cmd $cmd
Write-Notice "Release created for $Tag"

$extra = @{ tag = $Tag }
if ($Notes) { $extra.notes = (Resolve-Path -LiteralPath $Notes -ErrorAction SilentlyContinue).Path }
if ($Attach) { $extra.attach = $Attach }
Flush-Log -Json:$Json -Extra $extra
