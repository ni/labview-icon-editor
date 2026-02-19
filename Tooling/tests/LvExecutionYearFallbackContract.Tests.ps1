#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW execution-year fallback contract' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:pplBuildScriptPath = Join-Path $script:repoRoot '.github\actions\build-lvlibp\BuildProjectSpec.ps1'
        $script:invokeVipBuildPath = Join-Path $script:repoRoot 'Tooling\Invoke-VipBuild.ps1'
        $script:buildVipScriptPath = Join-Path $script:repoRoot '.github\actions\build-vip\build_vip.ps1'

        $script:pplBuildScriptContent = Get-Content -Path $script:pplBuildScriptPath -Raw
        $script:invokeVipBuildContent = Get-Content -Path $script:invokeVipBuildPath -Raw
        $script:buildVipScriptContent = Get-Content -Path $script:buildVipScriptPath -Raw
    }

    It 'BuildProjectSpec accepts execution-year override and keeps source version contract' {
        $script:pplBuildScriptContent | Should -Match '\[string\]\$ExecutionLabVIEWYear'
        $script:pplBuildScriptContent | Should -Match 'Get-LabVIEWVersionInfo -VersionInput \$LabVIEWVersion -RepoRoot \$RepoRoot'
        $script:pplBuildScriptContent | Should -Match 'LabVIEW source contract: raw=\{0\}; year=\{1\}'
        $script:pplBuildScriptContent | Should -Match 'LabVIEW execution-year compatibility mapping applied'
    }

    It 'BuildProjectSpec uses execution year for runtime operations' {
        $script:pplBuildScriptContent | Should -Match 'Resolve-LabVIEWExecutablePath -VersionYear \$executionLabVIEWYear'
        $script:pplBuildScriptContent | Should -Match '-LabVIEWVersion \$executionLabVIEWYear'
        $script:pplBuildScriptContent | Should -Match 'Get-IconEditorSyncExcludeList -LabVIEWYear \$executionLabVIEWYear'
        $script:pplBuildScriptContent | Should -Match '\$supportsHeadlessBuildSpec = \[int\]::TryParse\(\[string\]\$executionLabVIEWYear'
        $script:pplBuildScriptContent | Should -Match 'Invoke-CloseLabVIEWSafely -Version \$executionLabVIEWYear'
    }

    It 'Invoke-VipBuild forwards execution-year override to build_vip script' {
        $script:invokeVipBuildContent | Should -Match '\[string\]\$ExecutionLabVIEWYear'
        $script:invokeVipBuildContent | Should -Match '\$sourceLabVIEWYear ='
        $script:invokeVipBuildContent | Should -Match '\$resolvedExecutionLabVIEWYear ='
        $script:invokeVipBuildContent | Should -Match '''-ExecutionLabVIEWYear'',\s*\$resolvedExecutionLabVIEWYear'
        $script:invokeVipBuildContent | Should -Match 'VIP build LabVIEW execution-year compatibility mapping applied'
    }

    It 'build_vip uses execution year for VIPM runtime contract while preserving source validation' {
        $script:buildVipScriptContent | Should -Match '\[string\]\$ExecutionLabVIEWYear'
        $script:buildVipScriptContent | Should -Match 'Get-LabVIEWVersionInfo -VersionInput \$LabVIEWVersion -RepoRoot \$ResolvedRepoRoot'
        $script:buildVipScriptContent | Should -Match '\$resolvedExecutionLabVIEWYear ='
        $script:buildVipScriptContent | Should -Match '''--labview-version'',\s*\$resolvedExecutionLabVIEWYear\.ToString\(\)'
        $script:buildVipScriptContent | Should -Match '-VersionYear \$resolvedExecutionLabVIEWYear\.ToString\(\)'
        $script:buildVipScriptContent | Should -Match '\$lvNumericMajor\s*=\s*\[int\]\$resolvedExecutionLabVIEWYear - 2000'
    }
}
