$ErrorActionPreference = 'Stop'

Describe 'LabVIEW executable path helper' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\LabVIEWExecutablePath.ps1'
        if (-not (Test-Path -Path $script:helperPath)) {
            throw "LabVIEW executable path helper not found at $script:helperPath"
        }
        . $script:helperPath
    }

    It 'returns the canonical install path when it exists' {
        $expected = 'C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe'

        Mock -CommandName Test-Path -MockWith {
            param($Path, $PathType)
            if ($Path -eq $expected -and $PathType -eq 'Leaf') {
                return $true
            }
            return $false
        }
        Mock -CommandName Resolve-Path -MockWith {
            param($Path)
            [pscustomobject]@{ Path = $Path }
        }
        Mock -CommandName Get-ItemProperty -MockWith {
            throw 'Get-ItemProperty should not be called for canonical path resolution.'
        }

        $result = Resolve-LabVIEWExecutablePath -VersionYear '2021' -Bitness '64'
        $result | Should -Be $expected
    }

    It 'falls back to registry when canonical path is absent' {
        $registryInstallPath = 'D:\NI\LabVIEW 2021'
        $expected = 'D:\NI\LabVIEW 2021\LabVIEW.exe'
        $registryPath = 'HKLM:\SOFTWARE\National Instruments\LabVIEW 2021'

        Mock -CommandName Test-Path -MockWith {
            param($Path, $PathType)
            if ($Path -eq $expected -and $PathType -eq 'Leaf') {
                return $true
            }
            return $false
        }
        Mock -CommandName Get-ItemProperty -MockWith {
            param($Path)
            if ($Path -eq $registryPath) {
                return [pscustomobject]@{
                    InstallPath = $registryInstallPath
                }
            }
            throw "Unexpected registry lookup: $Path"
        }
        Mock -CommandName Resolve-Path -MockWith {
            param($Path)
            [pscustomobject]@{ Path = $Path }
        }

        $result = Resolve-LabVIEWExecutablePath -VersionYear '2021' -Bitness '64'
        $result | Should -Be $expected
    }

    It 'throws a clear error when no path can be resolved' {
        Mock -CommandName Test-Path -MockWith { return $false }
        Mock -CommandName Get-ItemProperty -MockWith { throw 'Registry key not found.' }

        {
            Resolve-LabVIEWExecutablePath -VersionYear '2021' -Bitness '64'
        } | Should -Throw "*Could not resolve LabVIEW executable for 64-bit LabVIEW 2021*"
    }
}

