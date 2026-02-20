#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Pester bootstrap local-module contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:bootstrapPath = Join-Path $script:repoRoot 'Tooling\support\PesterBootstrap.ps1'
        $script:runPesterPath = Join-Path $script:repoRoot 'Test\Pester\Run-Pester.ps1'
        $script:devModeSmokePath = Join-Path $script:repoRoot 'Tooling\Invoke-DevModeNoLabVIEWSmoke.ps1'
        $script:bootstrapContent = Get-Content -Raw -Path $script:bootstrapPath
        $script:runPesterContent = Get-Content -Raw -Path $script:runPesterPath
        $script:devModeSmokeContent = Get-Content -Raw -Path $script:devModeSmokePath
    }

    It 'defines repo-local cache behavior in Pester bootstrap helper' {
        (Test-Path -LiteralPath $script:bootstrapPath -PathType Leaf) | Should -BeTrue
        $script:bootstrapContent | Should -Match 'function Import-RepoPester'
        $script:bootstrapContent | Should -Match 'Tooling\\\.cache\\powershell\\Modules'
        $script:bootstrapContent | Should -Match 'Save-Module -Name Pester'
        $script:bootstrapContent | Should -Match 'Test-IsOneDrivePath'
    }

    It 'loads Pester via the bootstrap helper in Test/Pester/Run-Pester.ps1' {
        (Test-Path -LiteralPath $script:runPesterPath -PathType Leaf) | Should -BeTrue
        $script:runPesterContent | Should -Match 'Tooling\\support\\PesterBootstrap\.ps1'
        $script:runPesterContent | Should -Match 'Import-RepoPester'
    }

    It 'loads Pester via the bootstrap helper in DevMode smoke script' {
        (Test-Path -LiteralPath $script:devModeSmokePath -PathType Leaf) | Should -BeTrue
        $script:devModeSmokeContent | Should -Match 'Tooling\\support\\PesterBootstrap\.ps1'
        $script:devModeSmokeContent | Should -Match 'Import-RepoPester'
    }
}
