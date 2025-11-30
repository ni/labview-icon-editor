# Helper functions to resolve LabVIEW ini locations and remove stale LocalHost.LibraryPaths entries.

# Allow tests to inject their own implementation; only define if not already present.
if (-not (Test-Path Function:\Resolve-LVIniPath)) {
    function Resolve-LVIniPath {
        param(
            [string]$LvVersion,
            [string]$Arch
        )

        $canonical = if ($Arch -eq '64') {
            "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
        } else {
            "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
        }

        if (Test-Path -LiteralPath $canonical) {
            return $canonical
        }

        # When running from WSL/Linux PowerShell, also check the /mnt/<drive> translation.
        if (-not $IsWindows) {
            $mntPath = $canonical
            if ($mntPath -match '^[A-Za-z]:') {
                $drive = ($mntPath.Substring(0,1)).ToLower()
                $rest  = $mntPath.Substring(2)
                $mntPath = "/mnt/$drive/$rest"
            }
            $mntPath = $mntPath -replace '\\', '/'
            if (Test-Path -LiteralPath $mntPath) {
                return $mntPath
            }
        }

        throw "LabVIEW.ini not found at canonical path: $canonical"
    }
}

if (-not (Test-Path Function:\Clear-StaleLibraryPaths)) {
    function Clear-StaleLibraryPaths {
        param(
            [string]$LvVersion,
            [string]$Arch,
            [string]$RepositoryRoot,
            [switch]$Force,
            [string]$TargetPath
        )
        $lvIniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
        if (-not $lvIniPath) { return }

        $ini     = Get-Content -LiteralPath $lvIniPath -Raw
        $pattern = 'LocalHost\.LibraryPaths\d*='
        $lines   = $ini -split "`r?`n"
        $cleaned = @()
        $removed = @()
        $seen    = @{}
        $repoNorm = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()

        foreach ($line in $lines) {
            if (-not ($line -match $pattern)) {
                $cleaned += $line
                continue
            }

            $parts = $line -split '=',2
            $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            if ([string]::IsNullOrWhiteSpace($value)) {
                $removed += $line
                continue
            }
            $valNorm = ([System.IO.Path]::GetFullPath($value)).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()

            $shouldRemove =
                ($line -like "*actions-runner*actions-runner*") -or
                ($seen.ContainsKey($valNorm))

            if ($shouldRemove) {
                $removed += $line
                continue
            }

            # If Force with a TargetPath is supplied, remove entries that do not match the target
            if ($Force -and $TargetPath) {
                $targetNorm = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()
                if ($valNorm -ne $targetNorm) {
                    $removed += $line
                    continue
                }
            }

            $seen[$valNorm] = $true
            $cleaned += $line
        }
        if ($removed.Count -gt 0) {
            Set-Content -LiteralPath $lvIniPath -Value ($cleaned -join "`r`n")
            $sample = $removed | Select-Object -First 1
            Write-Warning ("Removed {0} LocalHost.LibraryPaths entries from {1}. Example removed entry: {2}. If you still need that path, re-bind it explicitly for the intended repo/bitness." -f $removed.Count, $lvIniPath, $sample)
        }
    }
}

if (-not (Test-Path Function:\Add-LibraryPathToken)) {
    function Add-LibraryPathToken {
        param(
            [string]$LvVersion,
            [string]$Arch,
            [string]$TokenPath,
            [string]$RepositoryRoot
        )

        $lvIniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
        if (-not $lvIniPath) { return }

        $normToken = [System.IO.Path]::GetFullPath($TokenPath).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()
        $lines = Get-Content -LiteralPath $lvIniPath -ErrorAction Stop -Encoding UTF8
        if ($lines -isnot [System.Array]) {
            $lines = @($lines)
        }

        $pattern = 'LocalHost\.LibraryPaths(?<idx>\d*)\s*=\s*(?<val>.*)'
        $currentSection = ''
        $labviewSectionStart = $null
        $nextSectionAfterLabview = $null
        $removeIndices = New-Object System.Collections.Generic.List[int]

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            $sectionMatch = [regex]::Match($line, '^\s*\[(?<name>.+?)\]\s*$')
            if ($sectionMatch.Success) {
                $currentSection = $sectionMatch.Groups['name'].Value
                if ($currentSection -ieq 'LabVIEW') {
                    $labviewSectionStart = $i
                } elseif ($labviewSectionStart -ne $null -and $nextSectionAfterLabview -eq $null) {
                    $nextSectionAfterLabview = $i
                }
            }

            $m = [regex]::Match($line, $pattern, 'IgnoreCase')
            if (-not $m.Success) { continue }

            $valNorm = ([System.IO.Path]::GetFullPath($m.Groups['val'].Value)).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)).ToLowerInvariant()
            if ($valNorm -eq $normToken) {
                $removeIndices.Add($i)
                continue
            }
        }

        $newLine = "LocalHost.LibraryPaths={0}" -f $TokenPath
        $added = $false
        $newLines = New-Object System.Collections.Generic.List[string]

        if ($labviewSectionStart -ne $null) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($removeIndices.Contains($i)) { continue }
                if ($i -eq $labviewSectionStart) {
                    $newLines.Add($lines[$i])
                    if (-not $added) {
                        $newLines.Add($newLine)
                        $added = $true
                    }
                    continue
                }
                $newLines.Add($lines[$i])
            }
        }
        else {
            foreach ($line in $lines) {
                $newLines.Add($line)
            }
            $newLines.Add('[LabVIEW]')
            $newLines.Add($newLine)
            $added = $true
        }

        if (-not $added) {
            $newLines.Add($newLine)
        }

        $lines = $newLines
        Set-Content -LiteralPath $lvIniPath -Value ($lines -join "`r`n")
        Write-Information ("Added LocalHost.LibraryPaths entry to canonical INI {0}: {1}" -f $lvIniPath, $newLine) -InformationAction Continue
    }
}
