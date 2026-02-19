#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI container image fallback contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
        $script:linuxContainerSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-linux-container:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
        $script:windowsContainerSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-windows-container:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
    }

    It 'linux packed-library lane falls back to a deterministic container release when requested release is unavailable' {
        $script:linuxContainerSection | Should -Match 'LV_REQUESTED_RELEASE:\s*\$\{\{\s*format\(''\{0\}q1'',\s*needs\.version-gate\.outputs\.year\)\s*\}\}'
        $script:linuxContainerSection | Should -Match 'fallback_release="\$\{LVIE_CONTAINER_PARITY_FALLBACK_RELEASE:-2026q1\}"'
        $script:linuxContainerSection | Should -Match "Requested Linux container release '\$\{requested_release\}' is unavailable\. Falling back to '\$\{fallback_release\}'\."
        $script:linuxContainerSection | Should -Match 'Unable to pull LabVIEW Linux image for requested release'
    }

    It 'windows packed-library lane falls back to a deterministic container release when requested release is unavailable' {
        $script:windowsContainerSection | Should -Match '\$requestedRelease = ''\$\{\{\s*needs\.version-gate\.outputs\.year\s*\}\}q1'''
        $script:windowsContainerSection | Should -Match '\$fallbackRelease = \[Environment\]::GetEnvironmentVariable\(''LVIE_CONTAINER_PARITY_FALLBACK_RELEASE''\)'
        $script:windowsContainerSection | Should -Match '\$fallbackRelease = ''2026q1'''
        $script:windowsContainerSection | Should -Match 'function Try-PullWindowsRelease'
        $script:windowsContainerSection | Should -Match "Requested Windows container release '\{0\}' is unavailable\. Falling back to '\{1\}'\."
        $script:windowsContainerSection | Should -Match 'Unable to pull LabVIEW Windows image for requested release'
    }
}
