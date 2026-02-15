# NOTE: This helper is imported by Tooling/container-parity/runlabview-windows.ps1
# inside NI Windows containers via powershell.exe (Windows PowerShell 5.1).
# Keep this file compatible with Windows PowerShell 5.1 and do not add
# #Requires -Version at file scope.
<#
.SYNOPSIS
    Shared path root contract helpers for host and container scripts.
#>

$ErrorActionPreference = 'Stop'

function ConvertTo-LvieFullPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return [System.IO.Path]::GetFullPath($Path)
    } catch {
        return $Path
    }
}

function Resolve-LvieRepoRoot {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$LvieRepoRoot,

        [AllowNull()]
        [string]$WorkspaceRoot,

        [AllowNull()]
        [string]$RepoRoot,

        [AllowNull()]
        [string]$DefaultRepoRoot
    )

    $candidateList = @(
        [pscustomobject]@{ Value = $LvieRepoRoot; Source = '$env:LVIE_REPO_ROOT' },
        [pscustomobject]@{ Value = $WorkspaceRoot; Source = '$env:WORKSPACE_ROOT or parameter:WorkspaceRoot' },
        [pscustomobject]@{ Value = $RepoRoot; Source = '$env:REPO_ROOT' },
        [pscustomobject]@{ Value = $DefaultRepoRoot; Source = 'default' }
    )

    foreach ($candidate in $candidateList) {
        if ([string]::IsNullOrWhiteSpace($candidate.Value)) {
            continue
        }

        return [pscustomobject]@{
            Path   = ConvertTo-LvieFullPath -Path $candidate.Value
            Source = $candidate.Source
        }
    }

    throw "Unable to resolve repository root from LVIE_REPO_ROOT, WORKSPACE_ROOT, REPO_ROOT, or default."
}

function Resolve-LvieProjectPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$LvieProjectPath,

        [AllowNull()]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [AllowNull()]
        [string]$ProjectRelativePath,

        [string]$DefaultProjectRelativePath = 'lv_icon_editor.lvproj'
    )

    if (-not [string]::IsNullOrWhiteSpace($LvieProjectPath)) {
        $resolved = if ([System.IO.Path]::IsPathRooted($LvieProjectPath)) {
            ConvertTo-LvieFullPath -Path $LvieProjectPath
        } else {
            ConvertTo-LvieFullPath -Path (Join-Path -Path $RepoRoot -ChildPath $LvieProjectPath)
        }

        return [pscustomobject]@{
            Path         = $resolved
            Source       = '$env:LVIE_PROJECT_PATH'
            RelativePath = $ProjectRelativePath
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
        $resolved = if ([System.IO.Path]::IsPathRooted($ProjectPath)) {
            ConvertTo-LvieFullPath -Path $ProjectPath
        } else {
            ConvertTo-LvieFullPath -Path (Join-Path -Path $RepoRoot -ChildPath $ProjectPath)
        }

        return [pscustomobject]@{
            Path         = $resolved
            Source       = '$env:PROJECT_PATH'
            RelativePath = $ProjectRelativePath
        }
    }

    $effectiveRelativePath = if ([string]::IsNullOrWhiteSpace($ProjectRelativePath)) {
        $DefaultProjectRelativePath
    } else {
        $ProjectRelativePath
    }

    $resolvedPath = if ([System.IO.Path]::IsPathRooted($effectiveRelativePath)) {
        ConvertTo-LvieFullPath -Path $effectiveRelativePath
    } else {
        ConvertTo-LvieFullPath -Path (Join-Path -Path $RepoRoot -ChildPath $effectiveRelativePath)
    }

    return [pscustomobject]@{
        Path         = $resolvedPath
        Source       = '$env:LVIE_PROJECT_RELATIVE_PATH or default'
        RelativePath = $effectiveRelativePath
    }
}

function Join-LvieRepoPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return ConvertTo-LvieFullPath -Path $RelativePath
    }

    return ConvertTo-LvieFullPath -Path (Join-Path -Path $RepoRoot -ChildPath $RelativePath)
}
