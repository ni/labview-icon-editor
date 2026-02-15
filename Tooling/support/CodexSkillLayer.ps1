#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

function Resolve-CodexSkillLayerRepoRoot {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    try {
        $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
        }
    } catch {
        Write-Verbose ("Unable to resolve git root from {0}: {1}" -f $scriptRoot, $_.Exception.Message)
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..\..') -ErrorAction Stop).Path
}

function Resolve-CodexSkillLayerLockPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$LockPath
    )

    $candidate = $LockPath
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $env:LVIE_CODEX_SKILL_LAYER_LOCK_PATH
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = 'Tooling/codex-skill-layer.lock.json'
    }

    if ([System.IO.Path]::IsPathRooted($candidate)) {
        return [System.IO.Path]::GetFullPath($candidate)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $candidate))
}

function Get-CodexSkillLayerLock {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$LockPath
    )

    $resolvedRoot = Resolve-CodexSkillLayerRepoRoot -RepoRoot $RepoRoot
    $resolvedLockPath = Resolve-CodexSkillLayerLockPath -RepoRoot $resolvedRoot -LockPath $LockPath

    if (-not (Test-Path -Path $resolvedLockPath -PathType Leaf)) {
        throw ("Codex skill lock file not found: {0}" -f $resolvedLockPath)
    }

    $raw = Get-Content -Path $resolvedLockPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw ("Codex skill lock file is empty: {0}" -f $resolvedLockPath)
    }

    $lock = $raw | ConvertFrom-Json -ErrorAction Stop
    foreach ($required in @('repo', 'tag', 'asset_name', 'sha256', 'required_files', 'license_spdx')) {
        if (-not ($lock.PSObject.Properties.Name -contains $required)) {
            throw ("Codex skill lock file is missing required property '{0}': {1}" -f $required, $resolvedLockPath)
        }
    }

    return [pscustomobject]@{
        RepoRoot = $resolvedRoot
        LockPath = $resolvedLockPath
        Lock = $lock
    }
}

function Resolve-CodexSkillLayerRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$LayerRoot
    )

    $candidate = $LayerRoot
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $env:LVIE_CODEX_SKILL_LAYER_ROOT
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = 'TestResults/codex-skill-layer'
    }

    if ([System.IO.Path]::IsPathRooted($candidate)) {
        return [System.IO.Path]::GetFullPath($candidate)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $candidate))
}

function Resolve-CodexSkillLayerVersionRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LayerRoot,

        [Parameter(Mandatory = $true)]
        [object]$Lock
    )

    $safeTag = [regex]::Replace([string]$Lock.tag, '[^a-zA-Z0-9._-]', '_')
    if ([string]::IsNullOrWhiteSpace($safeTag)) {
        $safeTag = 'unknown'
    }
    return Join-Path $LayerRoot $safeTag
}

function Get-CodexSkillLayerState {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$LockPath,

        [Parameter(Mandatory = $false)]
        [string]$LayerRoot
    )

    $lockInfo = Get-CodexSkillLayerLock -RepoRoot $RepoRoot -LockPath $LockPath
    $resolvedLayerRoot = Resolve-CodexSkillLayerRoot -RepoRoot $lockInfo.RepoRoot -LayerRoot $LayerRoot
    $versionRoot = Resolve-CodexSkillLayerVersionRoot -LayerRoot $resolvedLayerRoot -Lock $lockInfo.Lock

    return [pscustomobject]@{
        RepoRoot = $lockInfo.RepoRoot
        LockPath = $lockInfo.LockPath
        Lock = $lockInfo.Lock
        LayerRoot = $resolvedLayerRoot
        VersionRoot = $versionRoot
    }
}

function Test-CodexSkillLayerVersionRoot {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    if (-not (Test-Path -Path $State.VersionRoot -PathType Container)) {
        throw ("Codex skill layer is not installed at {0}" -f $State.VersionRoot)
    }

    $manifestPath = Join-Path $State.VersionRoot 'manifest.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw ("Codex skill layer manifest is missing: {0}" -f $manifestPath)
    }

    $manifestRaw = Get-Content -Path $manifestPath -Raw -ErrorAction Stop
    $manifest = $manifestRaw | ConvertFrom-Json -ErrorAction Stop
    $actualLicense = [string]$manifest.license_spdx
    $expectedLicense = [string]$State.Lock.license_spdx
    if ([string]::IsNullOrWhiteSpace($actualLicense)) {
        throw ("Codex skill layer manifest is missing license_spdx: {0}" -f $manifestPath)
    }
    if ($actualLicense -ne $expectedLicense) {
        throw ("Codex skill layer license mismatch. Expected '{0}', found '{1}'." -f $expectedLicense, $actualLicense)
    }

    foreach ($relative in @($State.Lock.required_files)) {
        $target = Join-Path $State.VersionRoot ([string]$relative)
        if (-not (Test-Path -Path $target)) {
            throw ("Codex skill layer is missing required file '{0}' at {1}" -f $relative, $target)
        }
    }

    return [pscustomobject]@{
        ManifestPath = $manifestPath
        Manifest = $manifest
    }
}

function Install-CodexSkillLayerInternal {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State,

        [Parameter(Mandatory = $false)]
        [string]$Token,

        [switch]$Force
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "gh CLI is required to install Codex skill layer assets."
    }

    if (-not (Test-Path -Path $State.LayerRoot)) {
        New-Item -Path $State.LayerRoot -ItemType Directory -Force | Out-Null
    }

    if ((Test-Path -Path $State.VersionRoot) -and -not $Force) {
        Test-CodexSkillLayerVersionRoot -State $State | Out-Null
        return [pscustomobject]@{
            Installed = $false
            VersionRoot = $State.VersionRoot
            AssetPath = $null
            Sha256 = [string]$State.Lock.sha256
        }
    }

    $tempRoot = Join-Path $env:TEMP ("lvie-codex-skill-layer-{0}" -f ([guid]::NewGuid().ToString('N')))
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    try {
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $env:GH_TOKEN = $Token
        } elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_CODEX_SKILL_LAYER_TOKEN)) {
            $env:GH_TOKEN = $env:LVIE_CODEX_SKILL_LAYER_TOKEN
        }

        & gh release download ([string]$State.Lock.tag) `
            --repo ([string]$State.Lock.repo) `
            --pattern ([string]$State.Lock.asset_name) `
            --dir $tempRoot `
            --clobber
        if ($LASTEXITCODE -ne 0) {
            throw ("Failed to download Codex skill layer asset '{0}' from {1} tag {2}." -f $State.Lock.asset_name, $State.Lock.repo, $State.Lock.tag)
        }

        $assetPath = Join-Path $tempRoot ([string]$State.Lock.asset_name)
        if (-not (Test-Path -Path $assetPath -PathType Leaf)) {
            throw ("Downloaded Codex skill layer asset was not found at {0}" -f $assetPath)
        }

        $actualHash = (Get-FileHash -Path $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = ([string]$State.Lock.sha256).ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw ("Codex skill layer SHA256 mismatch. Expected {0}, got {1}." -f $expectedHash, $actualHash)
        }

        $extractRoot = Join-Path $tempRoot 'extract'
        Expand-Archive -Path $assetPath -DestinationPath $extractRoot -Force

        $extractState = [pscustomobject]@{
            RepoRoot = $State.RepoRoot
            LockPath = $State.LockPath
            Lock = $State.Lock
            LayerRoot = $State.LayerRoot
            VersionRoot = $extractRoot
        }
        Test-CodexSkillLayerVersionRoot -State $extractState | Out-Null

        if (Test-Path -Path $State.VersionRoot) {
            Remove-Item -Path $State.VersionRoot -Recurse -Force
        }
        New-Item -Path $State.VersionRoot -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $extractRoot '*') -Destination $State.VersionRoot -Recurse -Force

        Test-CodexSkillLayerVersionRoot -State $State | Out-Null

        return [pscustomobject]@{
            Installed = $true
            VersionRoot = $State.VersionRoot
            AssetPath = $assetPath
            Sha256 = $actualHash
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
