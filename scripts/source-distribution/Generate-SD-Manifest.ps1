[CmdletBinding()]
param(
    [string]$BundlePath,
    [string]$OutputRoot,
    [string]$TempRoot,
    [switch]$KeepExtract
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function New-TempDir {
    param([string]$Root, [string]$Prefix)
    $base = if ($Root) { $Root } else { [IO.Path]::GetTempPath() }
    $name = "{0}-{1}" -f $Prefix, (Get-Date -Format "yyyyMMdd-HHmmss")
    $path = Join-Path $base $name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Get-LlbContainerPath {
    param([string]$RelativePath)
    $parts = $RelativePath -split "[\\/]"
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i].EndsWith('.llb', [StringComparison]::OrdinalIgnoreCase)) {
            return ($parts[0..$i] -join '/')
        }
    }
    return $null
}

if (-not $BundlePath) {
    $BundlePath = Join-Path (Get-Location) "builds/artifacts/sd-bundle.zip"
}
if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) {
    throw "Bundle not found: $BundlePath"
}
$bundleResolved = (Resolve-Path -LiteralPath $BundlePath).Path

$extractPath = New-TempDir -Root $TempRoot -Prefix "sd-bundle"
Write-Host ("[sd] Extracting bundle {0} -> {1}" -f $bundleResolved, $extractPath)
Expand-Archive -LiteralPath $bundleResolved -DestinationPath $extractPath -Force

$distExtract = $null
try {
    $commitIndexFile = Get-ChildItem -Path $extractPath -Filter 'commit-index.json' -Recurse -File | Select-Object -First 1
    $commitIndexMap = @{}
    $commitIndexLlbMap = @{}
    if ($commitIndexFile) {
        $commitIndex = Get-Content -LiteralPath $commitIndexFile.FullName -Raw | ConvertFrom-Json
        if ($commitIndex -and $commitIndex.entries) {
            foreach ($entry in $commitIndex.entries) {
                if (-not $entry.path) { continue }
                $key = $entry.path.ToString().ToLowerInvariant()
                $commitIndexMap[$key] = $entry
                if ($entry.isContainer -and $key.EndsWith('.llb')) {
                    $commitIndexLlbMap[$key] = $entry
                }
            }
            Write-Host ("[sd] Loaded commit index ({0} entries)" -f $commitIndex.entries.Count)
        }
    }
    else {
        Write-Warning "commit-index.json not found in bundle; manifest commit_source will be 'generated'."
    }

    $distRoot = $null
    $distZip = Get-ChildItem -Path $extractPath -Filter 'labview-icon-api.zip' -Recurse -File | Select-Object -First 1
    if ($distZip) {
        $distExtract = New-TempDir -Root $TempRoot -Prefix "sd-dist"
        Write-Host ("[sd] Extracting source distribution zip {0} -> {1}" -f $distZip.FullName, $distExtract)
        Expand-Archive -LiteralPath $distZip.FullName -DestinationPath $distExtract -Force
        $singleDir = Get-ChildItem -Path $distExtract -Directory | Select-Object -First 1
        $distRoot = if ($singleDir) { $singleDir.FullName } else { $distExtract }
    }
    if (-not $distRoot) {
        $candidate = Get-ChildItem -Path $extractPath -Directory -Recurse | Where-Object { $_.Name -eq 'LabVIEWIconAPI' } | Select-Object -First 1
        if ($candidate) { $distRoot = $candidate.FullName }
    }
    if (-not $distRoot) {
        throw "Could not locate LabVIEW Icon API distribution (labview-icon-api.zip or LabVIEWIconAPI directory) inside bundle."
    }

    $generatedFiles = @(
        'manifest.json',
        'manifest.csv',
        'configs/vscode/task-schema.sample.json',
        'configs/vi-compare-run-request.sample.json',
        'configs/vi-compare-run-request.failure.json',
        'configs/vi-compare-run-request.disabled.json',
        'scripts/vi-compare/run-vi-history-suite-sd.ps1',
        'scripts/vi-compare/RunViCompareReplay.ps1',
        'lv_icon_editor.lvproj'
    )
    $allowedPrefixes = @(
        'resource/',
        'vi.lib/LabVIEW Icon API/',
        'Test/Unit tests/',
        'Program Files/National Instruments/',
        'Tooling/'
    )

    # Include hidden files (dotfiles) so manifest parity matches build output
    $files = @(Get-ChildItem -Path $distRoot -File -Recurse -Force)
    $manifest = @()
    $processed = 0
    foreach ($f in $files) {
        $processed++
        $rel = [IO.Path]::GetRelativePath($distRoot, $f.FullName).Replace('\\','/').Replace('\','/')
        $commitInfo = $null
        $commitSource = 'generated'
        if ($generatedFiles -contains $rel) {
            $commitSource = 'generated'
        }
        else {
            $indexKey = $rel.ToLowerInvariant()
            if ($commitIndexMap.ContainsKey($indexKey)) {
                $entry = $commitIndexMap[$indexKey]
                $commitInfo = $entry
                $commitSource = 'index'
            }
            elseif ($rel -like '*.llb/*') {
                $llbPath = Get-LlbContainerPath -RelativePath $rel
                if ($llbPath) {
                    $llbKey = $llbPath.ToLowerInvariant()
                    if ($commitIndexLlbMap.ContainsKey($llbKey)) {
                        $entry = $commitIndexLlbMap[$llbKey]
                        $commitInfo = $entry
                        $commitSource = 'llb_container'
                    }
                }
            }
        }

        if (-not ($generatedFiles -contains $rel)) {
            $allowed = $false
            foreach ($p in $allowedPrefixes) {
                if ($rel.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) { $allowed = $true; break }
            }
            if (-not $allowed) {
                throw "Manifest contains paths outside allowed scope: $rel"
            }
        }

        $manifest += [pscustomobject]@{
            path          = $rel
            last_commit   = if ($commitInfo) { $commitInfo.commit } else { $null }
            commit_author = if ($commitInfo) { $commitInfo.author } else { $null }
            commit_date   = if ($commitInfo) { $commitInfo.date } else { $null }
            size_bytes    = $f.Length
            commit_source = $commitSource
        }

        if ($processed % 100 -eq 0) {
            Write-Host ("[sd] Processed {0}/{1} files" -f $processed, $files.Count)
        }
    }

    if (-not $OutputRoot) {
        $OutputRoot = Join-Path (Split-Path -Parent $bundleResolved) 'builds/reports/source-distribution-verify'
    }
    if (-not [IO.Path]::IsPathRooted($OutputRoot)) {
        $OutputRoot = Join-Path (Get-Location) $OutputRoot
    }
    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }

    $manifestPath = Join-Path $OutputRoot 'manifest.json'
    $csvPath = Join-Path $OutputRoot 'manifest.csv'
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    if ($manifest.Count -gt 0) {
        $manifest | Select-Object path,last_commit,commit_author,commit_date,commit_source,size_bytes |
            ConvertTo-Csv -NoTypeInformation |
            Set-Content -LiteralPath $csvPath -Encoding utf8
    }
    else {
        @('"path","last_commit","commit_author","commit_date","commit_source","size_bytes"') | Set-Content -LiteralPath $csvPath -Encoding utf8
    }

    Write-Host ("[artifact][sd-manifest] manifest.json: {0}" -f $manifestPath)
    Write-Host ("[artifact][sd-manifest] manifest.csv: {0}" -f $csvPath)
}
finally {
    if (-not $KeepExtract) {
        foreach ($p in @($distExtract, $extractPath)) {
            if ($p -and (Test-Path -LiteralPath $p)) {
                try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }
    else {
        if ($distExtract) {
            Write-Host ("[sd] KeepExtract enabled; bundle at {0}, dist at {1}" -f $extractPath, $distExtract)
        }
        else {
            Write-Host ("[sd] KeepExtract enabled; bundle at {0}" -f $extractPath)
        }
    }
}
