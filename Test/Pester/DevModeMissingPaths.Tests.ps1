$ErrorActionPreference = 'Stop'

Describe 'Dev mode missing paths helper' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\DevModeMissingPaths.ps1'
        if (-not (Test-Path -Path $script:helperPath)) {
            throw "Missing paths helper not found at $script:helperPath"
        }
        . $script:helperPath
    }

    It 'extracts missing paths from an error source line' {
        $output = @(
            'Error -593450 occurred at missing: lv_icon.vi, lv_icon.vit'
        )

        $result = Get-DevModeMissingPathsFromOutput -Output $output
        $result | Should -Be @('lv_icon.vi', 'lv_icon.vit')
    }

    It 'extracts missing paths from a missing paths line' {
        $output = @(
            'Missing paths: file1.vi, file2.vi'
        )

        $result = Get-DevModeMissingPathsFromOutput -Output $output
        $result | Should -Be @('file1.vi', 'file2.vi')
    }

    It 'returns empty when nothing is reported' {
        $output = @(
            'Error -593451 occurred at missing:',
            'Possible reason(s):',
            'No paths reported'
        )

        $result = Get-DevModeMissingPathsFromOutput -Output $output
        $result | Should -HaveCount 0
    }
}
