#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Pester test-result output collision contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:runPesterPath = Join-Path $script:repoRoot 'Test\Pester\Run-Pester.ps1'
        $script:devModeSmokePath = Join-Path $script:repoRoot 'Tooling\Invoke-DevModeNoLabVIEWSmoke.ps1'
        $script:runPesterContent = Get-Content -Raw -Path $script:runPesterPath
        $script:devModeSmokeContent = Get-Content -Raw -Path $script:devModeSmokePath
    }

    It 'uses a unique CI XML filename for Test/Pester/Run-Pester.ps1' {
        (Test-Path -LiteralPath $script:runPesterPath -PathType Leaf) | Should -BeTrue
        $script:runPesterContent | Should -Match "\$pesterRunTokenTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'"
        $script:runPesterContent | Should -Match '\$pesterRunTokenParts \+= \$PID'
        $script:runPesterContent | Should -Match 'pester-devmode-\{0\}\.xml" -f \$pesterRunToken'
    }

    It 'uses a unique XML and summary token for DevMode.NoLabVIEW smoke runs' {
        (Test-Path -LiteralPath $script:devModeSmokePath -PathType Leaf) | Should -BeTrue
        $script:devModeSmokeContent | Should -Match "\$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'"
        $script:devModeSmokeContent | Should -Match '\$runToken = ''\{0\}-\{1\}'' -f \$timestamp, \$PID'
        $script:devModeSmokeContent | Should -Match 'pester-devmode-no-labview-smoke-\{0\}-\{1\}-bit-\{2\}\.xml" -f \$LabVIEWVersion, \$bitness, \$runToken'
        $script:devModeSmokeContent | Should -Match 'summary-\{0\}-bit-\{1\}\.txt" -f \$bitness, \$runToken'
    }
}
