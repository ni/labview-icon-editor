#Requires -Version 7.0
<#
.SYNOPSIS
    Resolve LabVIEW executable path for a version and bitness.

.DESCRIPTION
    Resolution order:
      1) Standard install paths under Program Files / Program Files (x86)
      2) LabVIEW registry keys with Path/InstallDir/InstallPath values
#>

function Resolve-LabVIEWExecutablePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionYear,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    $candidatePaths = if ($Bitness -eq '32') {
        @("C:\Program Files (x86)\National Instruments\LabVIEW $VersionYear\LabVIEW.exe")
    } else {
        @("C:\Program Files\National Instruments\LabVIEW $VersionYear\LabVIEW.exe")
    }

    foreach ($candidate in $candidatePaths) {
        if (Test-Path -Path $candidate -PathType Leaf) {
            return (Resolve-Path -Path $candidate -ErrorAction Stop).Path
        }
    }

    $registryPaths = if ($Bitness -eq '32') {
        @("HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $VersionYear")
    } else {
        @("HKLM:\SOFTWARE\National Instruments\LabVIEW $VersionYear")
    }

    foreach ($regPath in $registryPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($propName in @('Path', 'InstallDir', 'InstallPath')) {
                $rootValue = [string]$props.$propName
                if ([string]::IsNullOrWhiteSpace($rootValue)) {
                    continue
                }

                $candidateExe = if ($rootValue.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
                    $rootValue
                } else {
                    Join-Path -Path $rootValue -ChildPath 'LabVIEW.exe'
                }

                if (Test-Path -Path $candidateExe -PathType Leaf) {
                    return (Resolve-Path -Path $candidateExe -ErrorAction Stop).Path
                }
            }
        } catch {
            continue
        }
    }

    $expected = if ($Bitness -eq '32') {
        "C:\Program Files (x86)\National Instruments\LabVIEW $VersionYear\LabVIEW.exe"
    } else {
        "C:\Program Files\National Instruments\LabVIEW $VersionYear\LabVIEW.exe"
    }

    throw ("Could not resolve LabVIEW executable for {0}-bit LabVIEW {1}. Expected path like '{2}'." -f $Bitness, $VersionYear, $expected)
}

