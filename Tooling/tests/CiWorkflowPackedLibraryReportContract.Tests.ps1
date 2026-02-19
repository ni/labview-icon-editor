#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI workflow packed-library report naming contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
        $script:buildPpl32Section = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-x86:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
        $script:buildPpl64Section = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  build-ppl-x64:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
    }

    It 'writes deterministic XML reports for 32-bit and 64-bit packed-library lanes' {
        $script:buildPpl32Section | Should -Match 'Write packed library report \(32-bit\)'
        $script:buildPpl32Section | Should -Match 'lv_icon\.lvlibp-\{0\}-32\.xml'
        $script:buildPpl32Section | Should -Match 'ppl_build_report'
        $script:buildPpl32Section | Should -Match 'schema_version'

        $script:buildPpl64Section | Should -Match 'Write packed library report \(64-bit\)'
        $script:buildPpl64Section | Should -Match 'lv_icon\.lvlibp-\{0\}-64\.xml'
        $script:buildPpl64Section | Should -Match 'ppl_build_report'
        $script:buildPpl64Section | Should -Match 'schema_version'
    }

    It 'uploads packed-library report artifacts with OS/bitness-suffixed names' {
        $script:buildPpl32Section | Should -Match 'Upload packed library report artifact \(32-bit\)'
        $script:buildPpl32Section | Should -Match 'lv_icon\.lvlibp-\$\{\{ runner\.os \}\}-32-report'
        $script:buildPpl32Section | Should -Match 'lv_icon\.lvlibp-\$\{\{ runner\.os \}\}-32\.xml'

        $script:buildPpl64Section | Should -Match 'Upload packed library report artifact \(64-bit\)'
        $script:buildPpl64Section | Should -Match 'lv_icon\.lvlibp-\$\{\{ runner\.os \}\}-64-report'
        $script:buildPpl64Section | Should -Match 'lv_icon\.lvlibp-\$\{\{ runner\.os \}\}-64\.xml'
    }

    It 'routes packed-library jobs to bitness-specific runners and removes x64->x86 chaining' {
        $script:buildPpl32Section | Should -Match 'needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*unit-tests,\s*version\s*\]'
        $script:buildPpl32Section | Should -Match "runs-on:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_32 \|\| vars\.LVIE_RUNNER_LABEL \|\| 'self-hosted-windows-lv'\s*\}\}"
        $script:buildPpl32Section | Should -Not -Match 'build-ppl-x64'

        $script:buildPpl64Section | Should -Match 'needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*unit-tests,\s*version\s*\]'
        $script:buildPpl64Section | Should -Match "runs-on:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_64 \|\| vars\.LVIE_RUNNER_LABEL \|\| 'self-hosted-windows-lv'\s*\}\}"
    }
}
