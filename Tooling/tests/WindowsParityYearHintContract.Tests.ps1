#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Windows parity year-hint contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:parityServicePath = Join-Path $script:repoRoot 'Tooling\runner-cli\RunnerCli\ParityService.cs'
        $script:windowsParityScriptPath = Join-Path $script:repoRoot 'Tooling\container-parity\runlabview-windows.ps1'
        $script:parityServiceContent = Get-Content -LiteralPath $script:parityServicePath -Raw
        $script:windowsParityScriptContent = Get-Content -LiteralPath $script:windowsParityScriptPath -Raw
    }

    It 'passes container year hint from runner-cli into windows parity script invocation' {
        (Test-Path -LiteralPath $script:parityServicePath -PathType Leaf) | Should -BeTrue
        $script:parityServiceContent | Should -Match 'runlabview-windows\.ps1'' -LabVIEWVersion ''\{containerYearHint\}'''
    }

    It 'resolves windows parity contract year in precedence order and logs source' {
        (Test-Path -LiteralPath $script:windowsParityScriptPath -PathType Leaf) | Should -BeTrue
        $script:windowsParityScriptContent | Should -Match 'Resolved LabVIEW contract year: \{0\} \(source: \{1\}, raw: \{2\}\)'

        $resolverMatch = [regex]::Match(
            $script:windowsParityScriptContent,
            '(?ms)^function Resolve-LabVIEWContractYear \{.*?^\}'
        )
        $resolverMatch.Success | Should -BeTrue
        $resolverBlock = $resolverMatch.Value

        $hintIndex = $resolverBlock.IndexOf('parameter:LabVIEWVersion', [System.StringComparison]::Ordinal)
        $envIndex = $resolverBlock.IndexOf('$env:CONTAINER_PARITY_LABVIEW_VERSION', [System.StringComparison]::Ordinal)
        $fileIndex = $resolverBlock.IndexOf('.lvversion', [System.StringComparison]::Ordinal)

        $hintIndex | Should -BeGreaterThan -1
        $envIndex | Should -BeGreaterThan -1
        $fileIndex | Should -BeGreaterThan -1
        $hintIndex | Should -BeLessThan $envIndex
        $envIndex | Should -BeLessThan $fileIndex
    }

    It 'keeps lv_release year matching strict only for self-hosted parity context mode' {
        $script:parityServiceContent | Should -Match '(?ms)^    public static ParityContext BuildContext\(\s*string\? repoRootOverride,\s*string\? lvReleaseInput,\s*string\? contractPathOverride,\s*string\? parityModeHint\)'
        $script:parityServiceContent | Should -Match 'ResolveLvRelease\(\s*lvReleaseInput,\s*versionInfo\.Year,\s*contract\.DefaultReleaseSuffix,\s*parityModeHint\)'
        $script:parityServiceContent | Should -Match 'var enforceYearMatch = !string\.Equals\(normalizedMode, "linux-container", StringComparison\.Ordinal\)\s*&&'
        $script:parityServiceContent | Should -Match '!\s*string\.Equals\(normalizedMode, "windows-container", StringComparison\.Ordinal\);'
        $script:parityServiceContent | Should -Match 'Self-hosted parity lane requires matching year contracts\.'
    }
}
