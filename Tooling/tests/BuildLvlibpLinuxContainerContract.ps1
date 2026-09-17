#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Build LVLIBP Linux Container workflow contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $workflowPath = Join-Path $repoRoot '.github/workflows/build-lvlibp-linux-container.yml'
        if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
            throw "Workflow not found: $workflowPath"
        }
        $script:content = Get-Content -LiteralPath $workflowPath -Raw
    }

    It 'is triggered only by workflow_dispatch and workflow_call' {
        $script:content | Should -Match '(?m)^\s*workflow_dispatch:'
        $script:content | Should -Match '(?m)^\s*workflow_call:'
        $script:content | Should -Not -Match '(?m)^\s*push:'
        $script:content | Should -Not -Match '(?m)^\s*pull_request:'
    }

    It 'declares labview_version input under both workflow_dispatch and workflow_call' {
        $dispatchBlock = [regex]::Match($script:content, '(?s)workflow_dispatch:.*?(?=\nworkflow_call:|\non:|\njobs:)').Value
        $callBlock = [regex]::Match($script:content, '(?s)workflow_call:.*?(?=\non:|\njobs:)').Value

        $dispatchBlock | Should -Match 'labview_version'
        $callBlock | Should -Match 'labview_version'
    }

    It 'runs on ubuntu-latest' {
        $script:content | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest\s*$'
        $script:content | Should -Not -Match 'windows'
    }

    It 'validates minimum LabVIEW version for Linux Docker' {
        $script:content | Should -Match '2025'
        $script:content | Should -Match 'minYear\s*=\s*2025|minimum.*2025q3'
    }

    It 'reads version from .lvcontainer when no input is provided' {
        $script:content | Should -Match '\.lvcontainer'
    }

    It 'uploads built PPL artifact on success' {
        $script:content | Should -Match 'upload-artifact'
        $script:content | Should -Match '\.lvlibp'
    }
}