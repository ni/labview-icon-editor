[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [int]$MaxPerCategory = 10,
    [int]$MaxAgeDays = 14,
    [switch]$KeepAll
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$stashRoot = Join-Path $repoRoot 'builds\log-stash'

if (-not (Test-Path -LiteralPath $stashRoot)) {
    Write-Host "[log-stash] No stash found; nothing to clean."
    return
}

$now = Get-Date
$deadline = if ($MaxAgeDays -gt 0) { $now.AddDays(-1 * $MaxAgeDays) } else { $null }

$bundles = @()
$commitDirs = Get-ChildItem -LiteralPath $stashRoot -Directory -ErrorAction SilentlyContinue
foreach ($commitDir in $commitDirs) {
    $categoryDirs = Get-ChildItem -LiteralPath $commitDir.FullName -Directory -ErrorAction SilentlyContinue
    foreach ($catDir in $categoryDirs) {
        $bundleDirs = Get-ChildItem -LiteralPath $catDir.FullName -Directory -ErrorAction SilentlyContinue
        foreach ($bundleDir in $bundleDirs) {
            $bundles += [pscustomobject]@{
                Category = $catDir.Name
                Path     = $bundleDir.FullName
                Stamp    = $bundleDir.LastWriteTimeUtc
            }
        }
    }
}

if (-not $bundles -or $bundles.Count -eq 0) {
    Write-Host "[log-stash] No bundles to clean."
    return
}

$toRemove = New-Object System.Collections.Generic.List[object]

if (-not $KeepAll) {
    if ($deadline) {
        foreach ($b in $bundles) {
            if ($b.Stamp -lt $deadline.ToUniversalTime()) {
                $toRemove.Add($b)
            }
        }
    }

    if ($MaxPerCategory -gt 0) {
        $grouped = $bundles | Group-Object -Property Category
        foreach ($grp in $grouped) {
            $ordered = $grp.Group | Sort-Object -Property Stamp -Descending
            $excess = $ordered | Select-Object -Skip $MaxPerCategory
            foreach ($b in $excess) {
                $toRemove.Add($b)
            }
        }
    }
}

$uniqueToRemove = $toRemove | Sort-Object -Property Path -Unique
if (-not $uniqueToRemove -or $uniqueToRemove.Count -eq 0) {
    Write-Host "[log-stash] No bundles matched cleanup criteria."
    return
}

foreach ($item in $uniqueToRemove) {
    $rel = try { [System.IO.Path]::GetRelativePath($repoRoot, $item.Path) } catch { $item.Path }
    if ($PSCmdlet.ShouldProcess($rel, "Remove log-stash bundle")) {
        try {
            Remove-Item -LiteralPath $item.Path -Recurse -Force -ErrorAction Stop
            Write-Host ("[log-stash] Removed bundle: {0}" -f $rel)
        }
        catch {
            Write-Warning ("[log-stash] Failed to remove {0}: {1}" -f $rel, $_.Exception.Message)
        }
    }
}
