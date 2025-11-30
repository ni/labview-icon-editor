Set-StrictMode -Version Latest

function Invoke-LabVIEWCliProbe {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$LabVIEWExePath,

        [string]$LabVIEWCliPath,

        [string]$LabVIEWIniPath,

        [string]$RepoRoot,

        [string]$TempDirectory,

        [int]$MinimumVersionYear = 2025
    )

    $result = [ordered]@{
        LabVIEWExePath       = $LabVIEWExePath
        LabVIEWCliPath       = $LabVIEWCliPath
        LabVIEWIniPath       = $LabVIEWIniPath
        LogPath              = $null
        ExitCode             = $null
        StdOut               = @()
        LogTail              = @()
        Version              = $null
        VersionYear          = $null
        IsAvailable          = $false
        IsSupportedVersion   = $false
        DevModeReady         = $false
        Status               = 'probe-not-run'
        Message              = $null
        DevMode              = $null
    }

    $normalizePath = {
        param([string]$PathValue)
        if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
        try {
            return (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
        } catch {
            try {
                return [System.IO.Path]::GetFullPath($PathValue)
            } catch {
                return $PathValue
            }
        }
    }
    $normalizeDir = {
        param([string]$PathValue)
        $normalized = & $normalizePath $PathValue
        if ($normalized) {
            return $normalized.TrimEnd('\','/')
        }
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($LabVIEWExePath)) {
        $result.Status = 'labview-path-missing'
        $result.Message = 'LabVIEW path not specified.'
        return [pscustomobject]$result
    }

    $resolvedExe = $LabVIEWExePath
    $labviewRoot = $null
    try {
        $candidateItem = Get-Item -LiteralPath $LabVIEWExePath -ErrorAction Stop
        if ($candidateItem.PSIsContainer) {
            $labviewRoot = $candidateItem.FullName
        } else {
            $resolvedExe = $candidateItem.FullName
            $labviewRoot = $candidateItem.DirectoryName
        }
    } catch {
        $labviewRoot = Split-Path -Parent $LabVIEWExePath
        if (-not $labviewRoot) {
            $labviewRoot = $LabVIEWExePath
        }
    }
    $result.LabVIEWExePath = $resolvedExe

    if (-not $LabVIEWIniPath -and $labviewRoot) {
        $LabVIEWIniPath = Join-Path $labviewRoot 'LabVIEW.ini'
    }

    $result.LabVIEWIniPath = $LabVIEWIniPath

    if (-not $LabVIEWIniPath -or -not (Test-Path -LiteralPath $LabVIEWIniPath -PathType Leaf)) {
        $result.Status = 'labview-ini-missing'
        if ($LabVIEWIniPath) {
            $result.Message = "LabVIEW.ini not found at $LabVIEWIniPath"
        } else {
            $result.Message = "LabVIEW.ini path could not be determined from $LabVIEWExePath"
        }
        return [pscustomobject]$result
    }

    try {
        $iniLines = Get-Content -LiteralPath $LabVIEWIniPath -ErrorAction Stop
    } catch {
        $result.Status = 'labview-ini-read-error'
        $result.Message = ("Unable to read LabVIEW.ini at {0}: {1}" -f $LabVIEWIniPath, $_.Exception.Message)
        return [pscustomobject]$result
    }

    # Dev-mode / LocalHost.LibraryPaths evaluation
    $devInfo = [ordered]@{
        requiredPath    = $null
        configuredPaths = @()
        status          = 'not-evaluated'
        message         = 'LocalHost.LibraryPaths not evaluated.'
    }
    $result.DevMode = $devInfo

    $normalizedRepo = $null
    if ($RepoRoot) {
        $normalizedRepo = & $normalizeDir $RepoRoot
        if (-not $normalizedRepo) {
            $normalizedRepo = $RepoRoot
        }
        $devInfo.requiredPath = $normalizedRepo
    }

    $libraryEntries = @()
    foreach ($line in $iniLines) {
        if ($line -match '^\s*LocalHost\.LibraryPaths\s*=\s*(?<paths>.+)$') {
            $libraryEntries += $Matches['paths']
        }
    }

    $configuredPaths = New-Object System.Collections.Generic.List[object]
    if ($libraryEntries.Count -gt 0) {
        foreach ($entry in $libraryEntries) {
            $segments = $entry -split ';'
            foreach ($segment in $segments) {
                $candidate = $segment.Trim()
                if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
                $candidate = $candidate.Trim('"')
                if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
                $normalizedCandidate = & $normalizeDir $candidate
                $exists = Test-Path -LiteralPath $candidate -PathType Container
                $matchesRequired = $false
                if ($normalizedRepo) {
                    $matchesRequired = ($normalizedCandidate -and ($normalizedCandidate -ieq $normalizedRepo))
                }
                $configuredPaths.Add([pscustomobject]@{
                    raw             = $candidate
                    normalized      = $normalizedCandidate
                    exists          = $exists
                    matchesRequired = $matchesRequired
                }) | Out-Null
            }
        }
    }
    $devInfo.configuredPaths = $configuredPaths

    if ($configuredPaths.Count -eq 0) {
        $devInfo.status = 'missing'
        $devInfo.message = 'LocalHost.LibraryPaths entry not found in LabVIEW.ini.'
    } else {
        $missingPaths = @($configuredPaths | Where-Object { -not $_.exists })
        if ($missingPaths.Count -gt 0) {
            $devInfo.status = 'invalid-paths'
            $missingList = ($missingPaths | Select-Object -First 3 | ForEach-Object { $_.raw }) -join ', '
            $devInfo.message = "LocalHost.LibraryPaths contains paths that do not exist: $missingList"
        } else {
            $devInfo.status = 'configured'
            $devInfo.message = 'LocalHost.LibraryPaths entries resolved successfully.'
        }

        if ($normalizedRepo) {
            $matching = @($configuredPaths | Where-Object { $_.matchesRequired })
            if ($matching.Count -gt 0) {
                $validMatch = @($matching | Where-Object { $_.exists })
                if ($validMatch.Count -gt 0) {
                    $devInfo.status = 'ok'
                    $devInfo.message = 'LocalHost.LibraryPaths includes the repository root.'
                    $result.DevModeReady = $true
                } else {
                    $devInfo.status = 'repo-missing'
                    $devInfo.message = 'LocalHost.LibraryPaths references the repository root but it does not exist on disk.'
                }
            } else {
                $devInfo.status = 'repo-not-listed'
                $devInfo.message = 'LocalHost.LibraryPaths does not include the repository root.'
            }
        } elseif ($devInfo.status -eq 'configured') {
            $result.DevModeReady = $true
        }
    }

    # Resolve LabVIEWCLI.exe location without invoking it
    if (-not $LabVIEWCliPath -and $labviewRoot) {
        $LabVIEWCliPath = Join-Path $labviewRoot 'LabVIEWCLI.exe'
    }

    $resolvedCli = $LabVIEWCliPath
    $cliExists = $false
    if ($LabVIEWCliPath -and (Test-Path -LiteralPath $LabVIEWCliPath -PathType Leaf)) {
        $resolvedCli = (Get-Item -LiteralPath $LabVIEWCliPath).FullName
        $cliExists = $true
    }
    if (-not $resolvedCli) {
        $resolvedCli = 'LabVIEWCLI.exe'
    }
    $result.LabVIEWCliPath = $resolvedCli

    # Derive LabVIEW version from LabVIEW.ini or folder name
    $versionLine = $null
    foreach ($line in $iniLines) {
        if ($line -match '^\s*LabVIEWVersion\s*=\s*(?<ver>.+)$') {
            $versionLine = $Matches['ver'].Trim()
            break
        }
        if ($line -match '^\s*Version\s*=\s*(?<ver>.+)$') {
            $versionLine = $Matches['ver'].Trim()
        }
    }

    if (-not $versionLine -and $resolvedExe) {
        $folderHint = Split-Path -Parent $resolvedExe | Split-Path -Leaf
        if ($folderHint -match '20\d{2}') {
            $versionLine = $folderHint
        }
    }

    if ($versionLine) {
        $result.Version = $versionLine
        if ($versionLine -match '(20\d{2})') {
            $result.VersionYear = [int]$Matches[1]
        }
    }

    $exeExists = Test-Path -LiteralPath $resolvedExe -PathType Leaf
    $result.IsAvailable = $exeExists -and $cliExists

    if (-not $exeExists) {
        $result.Status = 'labview-exe-missing'
        $result.Message = "LabVIEW executable not found at $resolvedExe"
        return [pscustomobject]$result
    }

    if (-not $cliExists) {
        $result.Status = 'cli-missing'
        $result.Message = "LabVIEWCLI.exe not found next to '$resolvedExe'. Install LabVIEW CLI to enable headless operations."
    } else {
        $result.Status = 'ok'
        $result.Message = 'LabVIEW executable and LabVIEWCLI.exe discovered.'
    }

    if ($MinimumVersionYear -gt 0) {
        if ($result.VersionYear -and $result.VersionYear -ge $MinimumVersionYear) {
            $result.IsSupportedVersion = $true
        } elseif ($result.VersionYear) {
            $result.IsSupportedVersion = $false
            $result.Status = 'version-too-old'
            $result.Message = "LabVIEW $($result.VersionYear) detected; version $MinimumVersionYear or newer is required."
        } else {
            $result.IsSupportedVersion = $false
            if ($result.IsAvailable) {
                $result.Status = 'version-unknown'
                $result.Message = "LabVIEW installation detected but its version could not be determined. Version $MinimumVersionYear+ is required."
            }
        }
    } else {
        $result.IsSupportedVersion = $result.IsAvailable
    }

    return [pscustomobject]$result
}

