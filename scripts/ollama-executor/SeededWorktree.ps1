Set-StrictMode -Version Latest

function Get-VipbVersionInfo {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $vipbPath = Join-Path $RepoPath 'Tooling/deployment/seed.vipb'
    if (-not (Test-Path -LiteralPath $vipbPath -PathType Leaf)) {
        return $null
    }

    try {
        [xml]$vipbXml = Get-Content -LiteralPath $vipbPath -Raw
    }
    catch {
        Write-Warning "[seeded-worktree] Failed to parse ${vipbPath}: $($_.Exception.Message)"
        return $null
    }

    $settings = $vipbXml.SelectSingleNode('/VI_Package_Builder_Settings')
    if (-not $settings) {
        $settings = $vipbXml.SelectSingleNode('/Package')
    }
    if (-not $settings) { return $null }

    $general = $settings.SelectSingleNode('Library_General_Settings')
    if (-not $general) { return $null }

    $raw = [string]$general.Package_LabVIEW_Version
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

    $verMatch = [regex]::Match($raw, '^(?<major>\d{2})\.(?<minor>\d)')
    if (-not $verMatch.Success) { return $null }
    $maj = [int]$verMatch.Groups['major'].Value
    $minor = $verMatch.Groups['minor'].Value
    $version = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }

    $bitMatch = [regex]::Match($raw, '\((?<bitness>32|64)-bit\)')
    $bitness = if ($bitMatch.Success) { $bitMatch.Groups['bitness'].Value } else { '32' }

    return [pscustomobject]@{
        Version = $version
        Minor   = $minor
        Bitness = $bitness
    }
}

function Get-SeededWorktree {
    [CmdletBinding()]
    param(
        [string]$RepoPath = ".",
        [Parameter(Mandatory = $true)][int]$TargetLabVIEWVersion,
        [ValidateSet('0','3')][string]$TargetLabVIEWMinor = '0',
        [ValidateSet('32','64')][string]$TargetBitness = '64',
        [string]$WorktreeName,
        [switch]$ForceRecreate
    )

    $repoFull = (Resolve-Path -LiteralPath $RepoPath).Path
    $repoParent = Split-Path -Parent $repoFull
    if (-not $WorktreeName) {
        $suffix = "lv$($TargetLabVIEWVersion)$TargetLabVIEWMinor-$TargetBitness"
        $WorktreeName = "seeded-$suffix"
    }
    $worktreePath = Join-Path $repoParent $WorktreeName

    $needsCreate = $ForceRecreate.IsPresent
    if (-not $needsCreate -and (Test-Path -LiteralPath $worktreePath -PathType Container)) {
        $info = Get-VipbVersionInfo -RepoPath $worktreePath
        if ($info -and $info.Version -eq $TargetLabVIEWVersion.ToString() -and $info.Minor -eq $TargetLabVIEWMinor -and $info.Bitness -eq $TargetBitness) {
            Write-Host "[seeded-worktree] Reusing $worktreePath for LabVIEW $TargetLabVIEWVersion.$TargetLabVIEWMinor $TargetBitness-bit"
        }
        else {
            $needsCreate = $true
            Write-Host "[seeded-worktree] Existing worktree at $worktreePath does not match requested version/minor/bitness."
        }
    }
    else {
        $needsCreate = $true
    }

    if ($needsCreate) {
        $vipbScript = Join-Path $repoFull 'scripts/labview/vipb-bump-worktree.ps1'
        if (-not (Test-Path -LiteralPath $vipbScript -PathType Leaf)) {
            throw "vipb-bump-worktree.ps1 not found at $vipbScript"
        }

        $callArgs = @(
            '-RepositoryPath', $repoFull,
            '-TargetLabVIEWVersion', $TargetLabVIEWVersion,
            '-TargetLabVIEWMinor', $TargetLabVIEWMinor,
            '-WorktreeName', $WorktreeName,
            '-TargetBitness', $TargetBitness,
            '-ForceWorktree'
        )

        Write-Host "[seeded-worktree] Creating worktree '$WorktreeName' for LabVIEW $TargetLabVIEWVersion.$TargetLabVIEWMinor $TargetBitness-bit"
        $null = & pwsh -NoProfile -File $vipbScript @callArgs
        if ($LASTEXITCODE -ne 0) {
            throw "vipb-bump-worktree.ps1 failed with exit code $LASTEXITCODE"
        }
        if (-not (Test-Path -LiteralPath $worktreePath -PathType Container)) {
            throw "vipb-bump-worktree.ps1 completed but no worktree was found at $worktreePath"
        }
    }

    return [pscustomobject]@{
        WorktreePath = $worktreePath
        WorktreeName = $WorktreeName
    }
}
