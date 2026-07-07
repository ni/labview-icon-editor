$ErrorActionPreference = 'Stop'

Describe 'LabVIEW version contract' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:assertScript = Join-Path $script:repoRoot 'Tooling\Assert-LabVIEWVersion.ps1'
        $script:versionHelper = Join-Path $script:repoRoot 'Tooling\support\LabVIEWVersion.ps1'

        if (-not (Test-Path -Path $script:assertScript)) {
            throw "Assert script not found at $script:assertScript"
        }
        if (-not (Test-Path -Path $script:versionHelper)) {
            throw "Version helper not found at $script:versionHelper"
        }

        $script:newTempRepo = {
            param(
                [string]$Version,
                [string]$VersionHelperPath
            )

            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $toolingDir = Join-Path $root 'Tooling\support'
            New-Item -Path $toolingDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $VersionHelperPath -Destination (Join-Path $toolingDir 'LabVIEWVersion.ps1') -Force
            Set-Content -Path (Join-Path $root '.lvversion') -Value $Version -Encoding ascii
            return $root
        }
    }

    $envVars = @(
        'LVIE_REQUIRED_LABVIEW_VERSION',
        'LVIE_REQUIRED_LABVIEW_VERSION_YEAR',
        'LVIE_REQUIRED_LABVIEW_MINOR_REVISION',
        'LABVIEW_VERSION_YEAR',
        'LABVIEW_MINOR_REVISION'
    )

    BeforeEach {
        $script:envBackup = @{}
        foreach ($name in $envVars) {
            $current = $null
            $item = Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue
            if ($item) {
                $current = $item.Value
            }
            $script:envBackup[$name] = $current
            Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        foreach ($name in $envVars) {
            if ($null -ne $script:envBackup[$name]) {
                [Environment]::SetEnvironmentVariable($name, $script:envBackup[$name])
            } else {
                Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
            }
        }
    }

    It 'accepts matching expected version' {
        $root = & $script:newTempRepo -Version '21.0' -VersionHelperPath $script:versionHelper
        $result = & $script:assertScript -RepoRoot $root -ExpectedVersion '2021'
        $result.Year | Should -Be '2021'
    }

    It 'throws when expected version mismatches .lvversion' {
        $root = & $script:newTempRepo -Version '21.0' -VersionHelperPath $script:versionHelper
        { & $script:assertScript -RepoRoot $root -ExpectedVersion '2022' } | Should -Throw
    }

    It 'allows mismatches when AllowMismatch is set' {
        $root = & $script:newTempRepo -Version '21.0' -VersionHelperPath $script:versionHelper
        { & $script:assertScript -RepoRoot $root -ExpectedVersion '2022' -AllowMismatch } | Should -Not -Throw
    }

    It 'throws when required env overrides mismatch .lvversion' {
        $root = & $script:newTempRepo -Version '21.0' -VersionHelperPath $script:versionHelper
        $env:LVIE_REQUIRED_LABVIEW_VERSION = '2022'
        { & $script:assertScript -RepoRoot $root } | Should -Throw
    }

    It 'accepts matching year/minor env overrides' {
        $root = & $script:newTempRepo -Version '21.0' -VersionHelperPath $script:versionHelper
        Remove-Item -Path Env:LVIE_REQUIRED_LABVIEW_VERSION -ErrorAction SilentlyContinue
        $env:LABVIEW_VERSION_YEAR = '2021'
        $env:LABVIEW_MINOR_REVISION = '0'
        { & $script:assertScript -RepoRoot $root } | Should -Not -Throw
    }
}
