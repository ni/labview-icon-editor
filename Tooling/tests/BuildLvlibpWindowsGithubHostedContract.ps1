#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Build LVLIBP Windows GitHub-Hosted workflow contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $workflowPath = Join-Path $repoRoot '.github/workflows/build-lvlibp-windows-github-hosted.yml'
        if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
            throw "Workflow not found: $workflowPath"
        }
        $script:content = Get-Content -LiteralPath $workflowPath -Raw

        $isoMapPath = Join-Path $repoRoot '.lv-iso-map.json'
        if (-not (Test-Path -LiteralPath $isoMapPath -PathType Leaf)) {
            throw ".lv-iso-map.json not found: $isoMapPath"
        }
        $script:isoMap = Get-Content -LiteralPath $isoMapPath -Raw | ConvertFrom-Json
    }

    It 'is triggered only by workflow_dispatch and workflow_call' {
        $script:content | Should -Match '(?m)^\s*workflow_dispatch:'
        $script:content | Should -Match '(?m)^\s*workflow_call:'
        $script:content | Should -Not -Match '(?m)^\s*push:'
        $script:content | Should -Not -Match '(?m)^\s*pull_request:'
    }

    It 'declares labview_version and bitness inputs under workflow_dispatch and workflow_call' {
        $dispatchBlock = [regex]::Match($script:content, '(?s)workflow_dispatch:.*?(?=\nworkflow_call:|\non:|\njobs:)').Value
        $callBlock = [regex]::Match($script:content, '(?s)workflow_call:.*?(?=\non:|\njobs:)').Value

        $dispatchBlock | Should -Match 'labview_version'
        $dispatchBlock | Should -Match 'bitness'
        $callBlock | Should -Match 'labview_version'
        $callBlock | Should -Match 'bitness'
    }

    It 'declares LABVIEW_SERIAL_NUMBER secret under workflow_call' {
        $callBlock = [regex]::Match($script:content, '(?s)workflow_call:.*?(?=\non:|\njobs:)').Value
        $callBlock | Should -Match 'LABVIEW_SERIAL_NUMBER'
    }

    It 'bitness input is type choice under workflow_dispatch and type string under workflow_call' {
        $dispatchBlock = [regex]::Match($script:content, '(?s)workflow_dispatch:.*?(?=\nworkflow_call:|\non:|\njobs:)').Value
        $callBlock = [regex]::Match($script:content, '(?s)workflow_call:.*?(?=\non:|\njobs:)').Value

        $dispatchBlock | Should -Match 'type:\s*choice'
        # workflow_call does not support choice type
        $callBlock | Should -Not -Match 'type:\s*choice'
        $callBlock | Should -Match 'type:\s*string'
    }

    It 'runs on windows-latest' {
        $script:content | Should -Match '(?m)^\s*runs-on:\s*windows-latest\s*$'
    }

    It 'reads LabVIEW version and ISO URL from .lv-iso-map.json' {
        $script:content | Should -Match '\.lv-iso-map\.json'
        $script:content | Should -Match 'ISO_URL'
    }

    It 'falls back to .lv-iso-map.json default version when input is empty' {
        $script:content | Should -Match '\$isoMap\.default'
    }

    It 'default version exists in .lv-iso-map.json' {
        $default = $script:isoMap.default
        $default | Should -Not -BeNullOrEmpty -Because '.lv-iso-map.json must define a default version'
    }

    It 'extracts LV_YEAR from version string for configure-labview step' {
        $script:content | Should -Match 'LV_YEAR'
        $script:content | Should -Match 'labview_version:\s*\$\{\{\s*env\.LV_YEAR\s*\}\}'
    }

    It 'uses PowerShell append syntax for environment variables' {
        $script:content | Should -Not -Match '(?m)^\s*echo\s+"[A-Z_]+=.*>>'
        $script:content | Should -Match '>>\s*\$env:GITHUB_ENV'
        $script:content | Should -Match '>>\s*\$env:GITHUB_OUTPUT'
    }

    It 'uploads built PPL artifact on success' {
        $script:content | Should -Match 'upload-artifact'
        $script:content | Should -Match '\.lvlibp'
    }
}