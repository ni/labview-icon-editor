$ErrorActionPreference = 'Stop'

Describe 'Dev mode (no LabVIEW) scripts' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:enableScript = Join-Path $script:repoRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
        $script:revertScript = Join-Path $script:repoRoot 'Tooling\Revert-DevelopmentMode-NoLabVIEW.ps1'

        if (-not (Test-Path -Path $script:enableScript)) {
            throw "Enable script not found at $script:enableScript"
        }
        if (-not (Test-Path -Path $script:revertScript)) {
            throw "Revert script not found at $script:revertScript"
        }

        . $script:enableScript
        . $script:revertScript
    }

    function New-TestInstall {
        param(
            [string]$Root
        )

        $installRoot = Join-Path $Root 'LabVIEW 2021'
        $iconApiDir = Join-Path $installRoot 'vi.lib\LabVIEW Icon API'
        $pluginsDir = Join-Path $installRoot 'resource\plugins'

        New-Item -ItemType Directory -Path $iconApiDir -Force | Out-Null
        Set-Content -Path (Join-Path $iconApiDir 'dummy.txt') -Value 'data' -Encoding ascii
        New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
        Set-Content -Path (Join-Path $pluginsDir 'lv_icon.lvlibp') -Value 'bin' -Encoding ascii

        return $installRoot
    }

    It 'enables and reverts dev mode without LabVIEW' {
        $root = Join-Path $env:TEMP ("lvie-devmode-" + [guid]::NewGuid().ToString('N'))
        $repoRoot = Join-Path $root 'repo'
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
        $installRoot = New-TestInstall -Root $root
        $iniPath = Join-Path $installRoot 'LabVIEW.ini'
        Set-Content -Path $iniPath -Value "Other=1`nLocalhost.LibraryPaths=C:\keep" -Encoding ascii

        Mock -CommandName Get-LabVIEWInstallRoot -MockWith { return $installRoot }

        try {
            Enable-DevModeNoLabVIEW -Bitness '64' -RepoRoot $repoRoot -LabVIEWYear '2021'

            (Test-Path -Path (Join-Path $installRoot 'vi.lib\LabVIEW Icon API')) | Should Be $false
            (Test-Path -Path (Join-Path $installRoot 'vi.lib\LabVIEW Icon API.zip')) | Should Be $true
            (Test-Path -Path (Join-Path $installRoot 'resource\plugins\lv_icon.ship')) | Should Be $true
            (Test-Path -Path (Join-Path $installRoot 'resource\plugins\lv_icon.lvlibp')) | Should Be $false
            (Get-Content -Path $iniPath -Raw) | Should Match ([regex]::Escape($repoRoot))

            Disable-DevModeNoLabVIEW -Bitness '64' -RepoRoot $repoRoot -LabVIEWYear '2021'

            (Test-Path -Path (Join-Path $installRoot 'vi.lib\LabVIEW Icon API')) | Should Be $true
            (Test-Path -Path (Join-Path $installRoot 'vi.lib\LabVIEW Icon API.zip')) | Should Be $false
            (Test-Path -Path (Join-Path $installRoot 'resource\plugins\lv_icon.lvlibp')) | Should Be $true
            (Test-Path -Path (Join-Path $installRoot 'resource\plugins\lv_icon.ship')) | Should Be $false
            $iniContents = Get-Content -Path $iniPath -Raw
            $iniContents | Should Match ([regex]::Escape('C:\keep'))
            $iniContents | Should Not Match ([regex]::Escape($repoRoot))
        }
        finally {
            Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
