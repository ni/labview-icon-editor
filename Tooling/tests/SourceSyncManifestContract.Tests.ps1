#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Source sync manifest contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\container-parity\source-sync-manifest.sh'
        $script:runViAnalyzerLinuxPath = Join-Path $script:repoRoot 'Tooling\container-parity\run-vi-analyzer-linux.sh'
        $script:runViAnalyzerWindowsPath = Join-Path $script:repoRoot 'Tooling\container-parity\run-vi-analyzer-windows.ps1'
        $script:runLabviewLinuxPath = Join-Path $script:repoRoot 'Tooling\container-parity\runlabview-linux.sh'
        $script:workflowPath = Join-Path $script:repoRoot '.github\workflows\labview-parity.yml'
    }

    It 'defines helper functions for deterministic sync-manifest generation' {
        (Test-Path -LiteralPath $script:helperPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Raw -Path $script:helperPath
        $content | Should -Match 'sync_manifest_capture_before_state'
        $content | Should -Match 'sync_manifest_write'
        $content | Should -Match '"manifest_kind": "source-sync"'
        $content | Should -Match '"classification"'
    }

    It 'wires source-sync manifest generation into vi-analyzer linux sync path' {
        (Test-Path -LiteralPath $script:runViAnalyzerLinuxPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Raw -Path $script:runViAnalyzerLinuxPath
        $content | Should -Match 'source-sync-manifest\.sh'
        $content | Should -Match 'SOURCE_SYNC_MANIFEST_PATH'
        $content | Should -Match 'source-sync-manifest-vi-analyzer-linux\.json'
        $content | Should -Match 'sync_manifest_capture_before_state'
        $content | Should -Match 'sync_manifest_write'
    }

    It 'wires source-sync manifest generation into vi-analyzer windows sync path' {
        (Test-Path -LiteralPath $script:runViAnalyzerWindowsPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Raw -Path $script:runViAnalyzerWindowsPath
        $content | Should -Match 'Synchronizing workspace Icon Editor sources into LabVIEW install before VI Analyzer\.'
        $content | Should -Match 'source-sync-manifest-vi-analyzer-windows\.json'
        $content | Should -Match 'Write-SourceSyncManifest'
        $content | Should -Match 'source_sync_manifest_path'
        $content | Should -Match 'source_sync'
    }

    It 'wires source-sync manifest generation into linux build-spec parity path' {
        (Test-Path -LiteralPath $script:runLabviewLinuxPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Raw -Path $script:runLabviewLinuxPath
        $content | Should -Match 'source-sync-manifest\.sh'
        $content | Should -Match 'SOURCE_SYNC_MANIFEST_PATH'
        $content | Should -Match 'source-sync-manifest-parity-linux\.json'
        $content | Should -Match 'sync_manifest_capture_before_state'
        $content | Should -Match 'sync_manifest_write'
    }

    It 'uploads source-sync manifest artifacts in parity workflow' {
        (Test-Path -LiteralPath $script:workflowPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Raw -Path $script:workflowPath
        $content | Should -Match 'Upload source sync manifest \(Linux container\)'
        $content | Should -Match 'labview-container-source-sync-manifest-linux'
        $content | Should -Match 'builds/status/source-sync-manifest-parity-linux\.json'
        $content | Should -Match 'vi-analyzer-source-sync-manifest-parity-linux'
        $content | Should -Match 'builds/status/source-sync-manifest-vi-analyzer-linux\.json'
        $content | Should -Match 'vi-analyzer-source-sync-manifest-parity-windows'
        $content | Should -Match 'builds/status/source-sync-manifest-vi-analyzer-windows\.json'
    }
}
