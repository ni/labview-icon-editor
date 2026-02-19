#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:scriptPath = Join-Path $script:repoRoot '.github\actions\missing-in-project\Invoke-MissingInProjectCLI.ps1'
    if (-not (Test-Path -Path $script:scriptPath -PathType Leaf)) {
        throw "Script not found: $script:scriptPath"
    }

    $content = Get-Content -Path $script:scriptPath -Raw
    $resolveBoolMatch = [regex]::Match($content, '(?ms)function Resolve-BoolFromEnv\s*\{.*?\n\}')
    if (-not $resolveBoolMatch.Success) {
        throw 'Failed to locate Resolve-BoolFromEnv function definition.'
    }

    $allowGapMatch = [regex]::Match($content, '(?ms)function Test-AllowNoLabVIEWIconApiGap\s*\{.*?\n\}')
    if (-not $allowGapMatch.Success) {
        throw 'Failed to locate Test-AllowNoLabVIEWIconApiGap function definition.'
    }

    $functionHarnessPath = Join-Path $TestDrive 'MissingInProject-AllowGap.Functions.ps1'
    Set-Content -Path $functionHarnessPath -Value @(
        $resolveBoolMatch.Value
        $allowGapMatch.Value
    ) -Encoding utf8
    . $functionHarnessPath
}

Describe 'Test-AllowNoLabVIEWIconApiGap' {
    BeforeEach {
        $script:prevForce = $env:LVIE_FORCE_NO_LABVIEW_DEVMODE
        $script:prevWarnOnly = $env:LVIE_RUNNER_ACL_WARN_ONLY
        $script:prevAllowGap = $env:LVIE_ALLOW_MISSING_IN_PROJECT_ICON_API_GAP
    }

    AfterEach {
        if ($null -eq $script:prevForce) {
            Remove-Item Env:LVIE_FORCE_NO_LABVIEW_DEVMODE -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_FORCE_NO_LABVIEW_DEVMODE = $script:prevForce
        }
        if ($null -eq $script:prevWarnOnly) {
            Remove-Item Env:LVIE_RUNNER_ACL_WARN_ONLY -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_RUNNER_ACL_WARN_ONLY = $script:prevWarnOnly
        }
        if ($null -eq $script:prevAllowGap) {
            Remove-Item Env:LVIE_ALLOW_MISSING_IN_PROJECT_ICON_API_GAP -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_ALLOW_MISSING_IN_PROJECT_ICON_API_GAP = $script:prevAllowGap
        }
    }

    It 'returns true for x86 forced no-LabVIEW mode when missing lines are limited to NI icon paths' {
        $env:LVIE_FORCE_NO_LABVIEW_DEVMODE = '1'
        $env:LVIE_RUNNER_ACL_WARN_ONLY = '1'
        Remove-Item Env:LVIE_ALLOW_MISSING_IN_PROJECT_ICON_API_GAP -ErrorAction SilentlyContinue

        $missing = @(
            'C:\Program Files (x86)\National Instruments\LabVIEW 2021\resource\plugins\NIIconEditor\Controls\Arrow Up.ctl',
            'C:\Program Files (x86)\National Instruments\LabVIEW 2021\vi.lib\LabVIEW Icon API\Get VI Icon.vi',
            'C:\actions-runner\_work\_temp\lvie\w\ci-305B2CFF-32\lv_icon_editor.lvproj'
        )

        Test-AllowNoLabVIEWIconApiGap -MissingLines $missing -Arch '32' -LabVIEWYear '2021' | Should -BeTrue
    }

    It 'returns false when an x86 LabVIEW missing line is outside NI icon paths' {
        $env:LVIE_FORCE_NO_LABVIEW_DEVMODE = '1'
        $env:LVIE_RUNNER_ACL_WARN_ONLY = '1'

        $missing = @(
            'C:\Program Files (x86)\National Instruments\LabVIEW 2021\resource\plugins\NIIconEditor\Controls\Arrow Up.ctl',
            'C:\Program Files (x86)\National Instruments\LabVIEW 2021\resource\plugins\OtherPlugin\Other.vi'
        )

        Test-AllowNoLabVIEWIconApiGap -MissingLines $missing -Arch '32' -LabVIEWYear '2021' | Should -BeFalse
    }

    It 'returns false for non-32-bit requests' {
        $env:LVIE_FORCE_NO_LABVIEW_DEVMODE = '1'
        $env:LVIE_RUNNER_ACL_WARN_ONLY = '1'

        $missing = @(
            'C:\Program Files (x86)\National Instruments\LabVIEW 2021\resource\plugins\NIIconEditor\Controls\Arrow Up.ctl'
        )

        Test-AllowNoLabVIEWIconApiGap -MissingLines $missing -Arch '64' -LabVIEWYear '2021' | Should -BeFalse
    }
}
