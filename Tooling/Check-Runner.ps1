#Requires -Version 7.0
<#
.SYNOPSIS
    Validates runner environment expectations and optionally fixes Git safe.directory.

.DESCRIPTION
    Ensures work roots exist, prints context, and sets scoped Git safe.directory
    to prevent "dubious ownership" errors when the runner service account differs
    from the checkout owner.

.PARAMETER WorkRoot
    Explicit runner work root. Defaults to LVIE_RUNNER_WORK_ROOT if set.

.PARAMETER WorktreeRoot
    Explicit worktree root. Defaults to LVIE_WORKTREE_ROOT if set.

.PARAMETER FixSafeDirectory
    Attempt to add a scoped safe.directory rule when missing.

.PARAMETER SafeDirectoryScope
    Target Git config scope for safe.directory. Defaults to System.
#>

[CmdletBinding()]
param(
    [string]$WorkRoot,
    [string]$WorktreeRoot,
    [string]$RepoRoot,
    [switch]$FixSafeDirectory,
    [ValidateSet('System', 'Global')]
    [string]$SafeDirectoryScope = 'System'
)

$ErrorActionPreference = 'Stop'
$fixSafeDirectoryEnabled = $FixSafeDirectory.IsPresent -or -not $PSBoundParameters.ContainsKey('FixSafeDirectory')

function Resolve-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }
    return $full
}

function Resolve-RepoRoot {
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -Path $Path)) {
        return (Resolve-Path -Path $Path -ErrorAction Stop).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE) -and (Test-Path -Path $env:GITHUB_WORKSPACE)) {
        return (Resolve-Path -Path $env:GITHUB_WORKSPACE -ErrorAction Stop).Path
    }

    return $null
}

function Get-LabVIEWInstallRoot {
    param([string]$Version, [string]$Bitness)

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Get-EnvValue {
    param([string]$Name)
    if (Test-Path "Env:$Name") {
        return (Get-Item "Env:$Name").Value
    }
    return $null
}

function Test-EnvBool {
    param(
        [string]$Name,
        [bool]$Default = $false
    )

    $value = Get-EnvValue -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    $normalized = $value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function Test-ForceNoLabVIEWDevMode {
    return (Test-EnvBool -Name 'LVIE_FORCE_NO_LABVIEW_DEVMODE' -Default $false)
}

function Test-DirectoryWriteAccess {
    param([string]$Path)
    $probe = Join-Path $Path ("lvie-acl-probe-{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
    try {
        New-Item -Path $probe -ItemType File -Force | Out-Null
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Test-FileWriteAccess {
    param([string]$Path)
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $stream.Close()
        return $true
    } catch {
        return $false
    }
}

function Grant-ModifyAccess {
    param(
        [string]$Path,
        [string]$Identity,
        [switch]$Recurse
    )

    if ([string]::IsNullOrWhiteSpace($Identity)) {
        throw "Identity is required to grant permissions."
    }

    $grantValue = if ($Recurse.IsPresent) {
        "{0}:(OI)(CI)M" -f $Identity
    } else {
        "{0}:M" -f $Identity
    }

    $icaclsArgs = @($Path, '/grant', $grantValue)
    if ($Recurse.IsPresent) {
        $icaclsArgs += '/T'
    }

    & icacls @icaclsArgs | Out-Null
}

$resolvedWorkRoot = if ($WorkRoot) { $WorkRoot } else { $env:LVIE_RUNNER_WORK_ROOT }
$resolvedWorktreeRoot = if ($WorktreeRoot) { $WorktreeRoot } else { $env:LVIE_WORKTREE_ROOT }
$resolvedWorkRoot = Resolve-NormalizedPath -Path $resolvedWorkRoot
$resolvedWorktreeRoot = Resolve-NormalizedPath -Path $resolvedWorktreeRoot
$resolvedRepoRoot = Resolve-RepoRoot -Path $RepoRoot

Write-Host ("Runner check: work_root={0}" -f ($resolvedWorkRoot ?? '<unset>'))
Write-Host ("Runner check: worktree_root={0}" -f ($resolvedWorktreeRoot ?? '<unset>'))
Write-Host ("Runner check: repo_root={0}" -f ($resolvedRepoRoot ?? '<unset>'))

if ($resolvedWorkRoot -and -not (Test-Path -Path $resolvedWorkRoot)) {
    Write-Warning ("Runner work root does not exist: {0}" -f $resolvedWorkRoot)
}
if ($resolvedWorktreeRoot -and -not (Test-Path -Path $resolvedWorktreeRoot)) {
    Write-Warning ("Worktree root does not exist: {0}" -f $resolvedWorktreeRoot)
}

function Get-GitSafeDirectory {
    param([string]$Scope)
    $gitArgs = @('config')
    if ($Scope -eq 'System') { $gitArgs += '--system' }
    if ($Scope -eq 'Global') { $gitArgs += '--global' }
    $gitArgs += @('--get-all', 'safe.directory')
    try {
        & git @gitArgs 2>$null | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    } catch {
        @()
    }
}

function Add-GitSafeDirectory {
    param([string]$Scope, [string]$PathPattern)
    $gitArgs = @('config')
    if ($Scope -eq 'System') { $gitArgs += '--system' }
    if ($Scope -eq 'Global') { $gitArgs += '--global' }
    $gitArgs += @('--add', 'safe.directory', $PathPattern)
    & git @gitArgs
}

if ($resolvedWorkRoot) {
    $safePattern = ($resolvedWorkRoot -replace '\\', '/') + '/*'
    $safeList = Get-GitSafeDirectory -Scope $SafeDirectoryScope
    $hasSafe = $false
    if ($safeList) {
        $hasSafe = $safeList | Where-Object { $_ -eq '*' -or $_ -eq $safePattern }
    }

    if (-not $hasSafe) {
        Write-Warning ("Git safe.directory missing for {0} (scope: {1})" -f $safePattern, $SafeDirectoryScope)
        if ($fixSafeDirectoryEnabled) {
            try {
                Add-GitSafeDirectory -Scope $SafeDirectoryScope -PathPattern $safePattern
                Write-Host ("Added git safe.directory: {0} ({1})" -f $safePattern, $SafeDirectoryScope)
            } catch {
                Write-Warning ("Failed to add git safe.directory: {0}" -f $_.Exception.Message)
            }
        }
    } else {
        Write-Host ("Git safe.directory OK: {0} ({1})" -f $safePattern, $SafeDirectoryScope)
    }
}

if ($resolvedRepoRoot) {
    $assertScript = Join-Path $resolvedRepoRoot 'Tooling/Assert-LabVIEWVersion.ps1'
    if (Test-Path -Path $assertScript) {
        $lvInfo = & $assertScript -RepoRoot $resolvedRepoRoot -Context 'runner sanity'
        if (-not $IsWindows) {
            Write-Host "Runner check: non-Windows runner; skipping LabVIEW install check."
            return
        }
        if ($lvInfo -and -not [string]::IsNullOrWhiteSpace($lvInfo.Year)) {
            $missing = @()
            foreach ($bitness in @('64', '32')) {
                if (-not (Get-LabVIEWInstallRoot -Version $lvInfo.Year -Bitness $bitness)) {
                    $missing += $bitness
                }
            }
            if ($missing.Count -gt 0) {
                $label = ($missing | ForEach-Object { "$_-bit" }) -join ', '
                throw "LabVIEW $($lvInfo.Year) install missing for: $label."
            }

            $aclCheckEnv = Get-EnvValue -Name 'LVIE_RUNNER_ACL_CHECK'
            if (-not [string]::IsNullOrWhiteSpace($aclCheckEnv)) {
                $aclCheckEnabled = Test-EnvBool -Name 'LVIE_RUNNER_ACL_CHECK' -Default $false
            } else {
                $aclCheckEnabled = Test-ForceNoLabVIEWDevMode
            }

            if ($aclCheckEnabled) {
                $autoFixEnabled = Test-EnvBool -Name 'LVIE_RUNNER_ACL_AUTOFIX' -Default $false
                $warnOnly = Test-EnvBool -Name 'LVIE_RUNNER_ACL_WARN_ONLY' -Default $false
                $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                Write-Host ("Runner ACL check: identity={0}, autofix={1}" -f $identity, $autoFixEnabled)

                $issues = @()
                $fixTargets = @()
                foreach ($bitness in @('64', '32')) {
                    $installRoot = Get-LabVIEWInstallRoot -Version $lvInfo.Year -Bitness $bitness
                    if (-not $installRoot) {
                        continue
                    }

                    $viLibRoot = Join-Path $installRoot 'vi.lib'
                    $iconApiDir = Join-Path $viLibRoot 'LabVIEW Icon API'
                    $pluginsRoot = Join-Path $installRoot 'resource\plugins'
                    $iniPath = Join-Path $installRoot 'LabVIEW.ini'

                    $targets = @(
                        @{ Label = 'vi.lib'; Path = $viLibRoot; Type = 'dir'; Recurse = $false },
                        @{ Label = 'resource\\plugins'; Path = $pluginsRoot; Type = 'dir'; Recurse = $false },
                        @{ Label = 'LabVIEW.ini'; Path = $iniPath; Type = 'file'; Recurse = $false }
                    )

                    if (Test-Path -Path $iconApiDir) {
                        $targets += @{ Label = 'vi.lib\\LabVIEW Icon API'; Path = $iconApiDir; Type = 'dir'; Recurse = $true }
                    }

                    foreach ($target in $targets) {
                        if (-not (Test-Path -Path $target.Path)) {
                            $issues += ("Missing {0} for LabVIEW {1} ({2}-bit): {3}" -f $target.Label, $lvInfo.Year, $bitness, $target.Path)
                            continue
                        }

                        $hasAccess = if ($target.Type -eq 'file') {
                            Test-FileWriteAccess -Path $target.Path
                        } else {
                            Test-DirectoryWriteAccess -Path $target.Path
                        }

                        if (-not $hasAccess) {
                            $issues += ("No write access to {0} for LabVIEW {1} ({2}-bit): {3}" -f $target.Label, $lvInfo.Year, $bitness, $target.Path)
                            $fixTargets += $target
                        }
                    }
                }

                if ($issues.Count -gt 0 -and $autoFixEnabled -and $fixTargets.Count -gt 0) {
                    foreach ($target in $fixTargets) {
                        try {
                            if ($target.Type -eq 'file') {
                                Grant-ModifyAccess -Path $target.Path -Identity $identity
                            } else {
                                Grant-ModifyAccess -Path $target.Path -Identity $identity -Recurse:([bool]$target.Recurse)
                            }
                            Write-Host ("Granted Modify access to {0}" -f $target.Path)
                        } catch {
                            Write-Warning ("ACL auto-fix failed for {0}: {1}" -f $target.Path, $_.Exception.Message)
                        }
                    }

                    $issues = @()
                    foreach ($target in $fixTargets) {
                        if (-not (Test-Path -Path $target.Path)) {
                            $issues += ("Missing {0}: {1}" -f $target.Label, $target.Path)
                            continue
                        }
                        $hasAccess = if ($target.Type -eq 'file') {
                            Test-FileWriteAccess -Path $target.Path
                        } else {
                            Test-DirectoryWriteAccess -Path $target.Path
                        }
                        if (-not $hasAccess) {
                            $issues += ("No write access to {0}: {1}" -f $target.Label, $target.Path)
                        }
                    }
                }

                if ($issues.Count -gt 0) {
                    $details = $issues -join [Environment]::NewLine
                    $message = "Runner ACL check failed. Grant Modify permissions to the runner identity for LabVIEW install paths, or set LVIE_RUNNER_ACL_AUTOFIX=1. Issues:`n$details"
                    if ($warnOnly) {
                        Write-Warning $message
                    } else {
                        throw $message
                    }
                }
            }
        }
    } else {
        Write-Warning ("LabVIEW version assertion script not found at {0}; skipping version checks." -f $assertScript)
    }
} else {
    Write-Warning "Runner check: repo_root not resolved; skipping LabVIEW version checks."
}


