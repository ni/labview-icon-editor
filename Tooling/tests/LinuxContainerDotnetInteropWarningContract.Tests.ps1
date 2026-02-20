#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Linux container optional DotNET interop warning contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:runLabviewLinuxPath = Join-Path $script:repoRoot 'Tooling\container-parity\runlabview-linux.sh'
        $script:runViAnalyzerLinuxPath = Join-Path $script:repoRoot 'Tooling\container-parity\run-vi-analyzer-linux.sh'
        $script:runLabviewLinuxContent = Get-Content -Raw -Path $script:runLabviewLinuxPath
        $script:runViAnalyzerLinuxContent = Get-Content -Raw -Path $script:runViAnalyzerLinuxPath
    }

    It 'wires optional DotNET interop discovery and LD_LIBRARY_PATH setup into linux build-spec parity script' {
        (Test-Path -LiteralPath $script:runLabviewLinuxPath -PathType Leaf) | Should -BeTrue
        $script:runLabviewLinuxContent | Should -Match 'LVIE_SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING'
        $script:runLabviewLinuxContent | Should -Match 'OPTIONAL_DOTNET_INTEROP_WARNING_REGEX'
        $script:runLabviewLinuxContent | Should -Match 'append_ld_library_path'
        $script:runLabviewLinuxContent | Should -Match 'configure_optional_dotnet_interop'
        $script:runLabviewLinuxContent | Should -Match 'find "\$LABVIEW_ROOT" /usr/local/natinst -name ''libniDotNETCoreInterop\.so'''
        $script:runLabviewLinuxContent | Should -Match 'Effective LD_LIBRARY_PATH'
        $script:runLabviewLinuxContent | Should -Match 'emit_labviewcli_output'
        $script:runLabviewLinuxContent | Should -Match 'Suppressed \$suppressed_count known optional libniDotNETCoreInterop\.so warning line\(s\)\.'
    }

    It 'wires optional DotNET interop discovery and warning suppression into linux vi-analyzer script' {
        (Test-Path -LiteralPath $script:runViAnalyzerLinuxPath -PathType Leaf) | Should -BeTrue
        $script:runViAnalyzerLinuxContent | Should -Match 'LVIE_SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING'
        $script:runViAnalyzerLinuxContent | Should -Match 'OPTIONAL_DOTNET_INTEROP_WARNING_REGEX'
        $script:runViAnalyzerLinuxContent | Should -Match 'append_ld_library_path'
        $script:runViAnalyzerLinuxContent | Should -Match 'configure_optional_dotnet_interop'
        $script:runViAnalyzerLinuxContent | Should -Match 'find "\$LABVIEW_ROOT" /usr/local/natinst -name ''libniDotNETCoreInterop\.so'''
        $script:runViAnalyzerLinuxContent | Should -Match 'Effective LD_LIBRARY_PATH'
        $script:runViAnalyzerLinuxContent | Should -Match 'emit_labviewcli_output'
        $script:runViAnalyzerLinuxContent | Should -Match 'Suppressed \$suppressed_count known optional libniDotNETCoreInterop\.so warning line\(s\)\.'
    }
}
