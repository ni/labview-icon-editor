#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW parity workflow build-spec contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/labview-parity.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
    }

    It 'removes run_build_spec input surface and output wiring' {
        $workflowContent | Should -Not -Match 'run_build_spec'
    }

    It 'uses mandatory --build-spec true in parity run invocations' {
        $trueFlagMatches = [regex]::Matches($workflowContent, '--build-spec\s+true')
        $trueFlagMatches.Count | Should -BeGreaterThan 2
        $workflowContent | Should -Not -Match '--build-spec\s+"\$\{\{'
    }

    It 'does not gate parity verification or uploads on build-spec toggles' {
        $workflowContent | Should -Not -Match 'outputs\.run_build_spec'
        $workflowContent | Should -Not -Match 'run_build_spec\s*=='
    }
}
