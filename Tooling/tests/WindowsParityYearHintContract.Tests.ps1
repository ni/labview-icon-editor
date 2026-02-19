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

    It 'passes self-hosted lane bitness from runner-cli into windows parity script invocation' {
        (Test-Path -LiteralPath $script:parityServicePath -PathType Leaf) | Should -BeTrue
        $script:parityServiceContent | Should -Match '"-LabVIEWBitness",\s*bitness'
        $script:parityServiceContent | Should -Match 'CONTAINER_PARITY_LABVIEW_BITNESS'
    }

    It 'applies LV2020 compatibility mapping for self-hosted parity execution year' {
        (Test-Path -LiteralPath $script:parityServicePath -PathType Leaf) | Should -BeTrue
        $script:parityServiceContent | Should -Match 'ResolveSelfHostedExecutionYear\(context\)'
        $script:parityServiceContent | Should -Match 'Self-hosted parity compatibility mapping applied: source \.lvversion year'
        $script:parityServiceContent | Should -Match 'ResolveReleaseYear\(DefaultContainerFallbackRelease,\s*context\.LabVIEWYear\)'
        $script:parityServiceContent | Should -Match '"-LabVIEWVersion",\s*executionYear'
        $script:parityServiceContent | Should -Match 'CONTAINER_PARITY_LABVIEW_VERSION"\]\s*=\s*executionYear'
        $script:parityServiceContent | Should -Match 'CONTAINER_PARITY_SOURCE_LABVIEW_VERSION"\]\s*=\s*context\.LabVIEWYear'
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

    It 'resolves windows parity contract bitness in precedence order and uses dynamic bitness checks' {
        (Test-Path -LiteralPath $script:windowsParityScriptPath -PathType Leaf) | Should -BeTrue
        $script:windowsParityScriptContent | Should -Match 'Resolved LabVIEW contract bitness: \{0\} \(source: \{1\}, raw: \{2\}\)'
        $script:windowsParityScriptContent | Should -Match 'Resolved LabVIEWCLI contract target: year=\{0\} bitness=\{1\}'

        $bitnessResolverMatch = [regex]::Match(
            $script:windowsParityScriptContent,
            '(?ms)^function Resolve-LabVIEWContractBitness \{.*?^\}'
        )
        $bitnessResolverMatch.Success | Should -BeTrue
        $bitnessResolverBlock = $bitnessResolverMatch.Value

        $hintIndex = $bitnessResolverBlock.IndexOf('parameter:LabVIEWBitness', [System.StringComparison]::Ordinal)
        $envIndex = $bitnessResolverBlock.IndexOf('$env:CONTAINER_PARITY_LABVIEW_BITNESS', [System.StringComparison]::Ordinal)
        $pathIndex = $bitnessResolverBlock.IndexOf('inferred:LabVIEWExecutablePath', [System.StringComparison]::Ordinal)

        $hintIndex | Should -BeGreaterThan -1
        $envIndex | Should -BeGreaterThan -1
        $pathIndex | Should -BeGreaterThan -1
        $hintIndex | Should -BeLessThan $envIndex
        $envIndex | Should -BeLessThan $pathIndex

        $portResolverMatch = [regex]::Match(
            $script:windowsParityScriptContent,
            '(?ms)^function Resolve-LabVIEWCliPort \{.*?^\}'
        )
        $portResolverMatch.Success | Should -BeTrue
        $portResolverBlock = $portResolverMatch.Value

        $portResolverBlock | Should -Match '\$yearNode\.PSObject\.Properties\.Name -contains \$bitness'
        $portResolverBlock | Should -Match '\$yearNode\.\$bitness'
        $portResolverBlock | Should -Not -Match "bitness '64' for year"
    }

    It 'supports explicit LabVIEW.ini port-contract remediation when enabled by environment' {
        (Test-Path -LiteralPath $script:windowsParityScriptPath -PathType Leaf) | Should -BeTrue
        $script:windowsParityScriptContent | Should -Match 'LVIE_REMEDIATE_LABVIEWCLI_PORT_CONTRACT'
        $script:windowsParityScriptContent | Should -Match 'function Set-LabVIEWIniValueStrict'
        $script:windowsParityScriptContent | Should -Match 'LabVIEWCLI contract remediation applied for year=\{0\} bitness=\{1\}'
        $script:windowsParityScriptContent | Should -Match 'remediated server\.tcp\.port to \{2\}'
    }

    It 'keeps lv_release year matching strict only for self-hosted parity context mode' {
        $script:parityServiceContent | Should -Match '(?ms)^    public static ParityContext BuildContext\(\s*string\? repoRootOverride,\s*string\? lvReleaseInput,\s*string\? contractPathOverride,\s*string\? parityModeHint\)'
        $script:parityServiceContent | Should -Match 'ResolveLvRelease\(\s*lvReleaseInput,\s*versionInfo\.Year,\s*contract\.DefaultReleaseSuffix,\s*parityModeHint\)'
        $script:parityServiceContent | Should -Match 'var enforceYearMatch = !string\.Equals\(normalizedMode, "linux-container", StringComparison\.Ordinal\)\s*&&'
        $script:parityServiceContent | Should -Match '!\s*string\.Equals\(normalizedMode, "windows-container", StringComparison\.Ordinal\);'
        $script:parityServiceContent | Should -Match 'Self-hosted parity lane requires matching year contracts\.'
    }
}
