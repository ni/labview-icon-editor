#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'VIP build CLI contract' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:buildVipScript = Join-Path $script:repoRoot '.github\actions\build-vip\build_vip.ps1'
        $script:buildVipAction = Join-Path $script:repoRoot '.github\actions\build-vip\action.yml'
    }

    It 'build_vip.ps1 invokes VIPM CLI build and does not call g-cli directly' {
        (Test-Path -LiteralPath $script:buildVipScript -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:buildVipScript -Raw

        $content | Should -Match 'Get-Command vipm'
        $content | Should -Match "'build'"
        $content | Should -Match 'vipm-build\.log'
        $content | Should -Not -Match '&\s*g-cli'
    }

    It 'build-vip action preflight validates VIPM CLI and publishes VIPM logs artifact' {
        (Test-Path -LiteralPath $script:buildVipAction -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:buildVipAction -Raw

        $content | Should -Match 'Pre-flight VIPM CLI availability check'
        $content | Should -Match 'Get-Command vipm'
        $content | Should -Match 'vipm-preflight\.log'
        $content | Should -Match 'name:\s*vipm-logs'
        $content | Should -Not -Match 'Pre-flight g-cli'
    }
}
