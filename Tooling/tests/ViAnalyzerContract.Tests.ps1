#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'VI Analyzer contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:tasksPath = Join-Path $script:repoRoot 'Tooling\vi-analyzer\tasks.json'
        $script:linuxTasksPath = Join-Path $script:repoRoot 'Tooling\vi-analyzer\tasks.linux.json'
        $script:lvcontainerPath = Join-Path $script:repoRoot '.lvcontainer'
        $script:ciPath = Join-Path $script:repoRoot '.github\workflows\ci.yml'
        $script:parityPath = Join-Path $script:repoRoot '.github\workflows\labview-parity.yml'
        $script:runViAnalyzerPath = Join-Path $script:repoRoot 'Tooling\Run-ViAnalyzer.ps1'
        $script:runViAnalyzerWindowsPath = Join-Path $script:repoRoot 'Tooling\container-parity\run-vi-analyzer-windows.ps1'
    }

    It 'defines exactly three deterministic VI Analyzer tasks' {
        (Test-Path -LiteralPath $script:tasksPath -PathType Leaf) | Should -BeTrue

        $tasksDoc = Get-Content -Raw -Path $script:tasksPath | ConvertFrom-Json
        ($tasksDoc.PSObject.Properties.Name -contains 'tasks') | Should -BeTrue

        $tasks = @($tasksDoc.tasks)
        $tasks.Count | Should -Be 3
        @($tasks.id) | Should -Be @('labview-icon-api', 'plugins', 'tooling')
    }

    It 'defines a linux-specific VI Analyzer task subset' {
        (Test-Path -LiteralPath $script:linuxTasksPath -PathType Leaf) | Should -BeTrue

        $linuxTasksDoc = Get-Content -Raw -Path $script:linuxTasksPath | ConvertFrom-Json
        ($linuxTasksDoc.PSObject.Properties.Name -contains 'tasks') | Should -BeTrue

        $linuxTasks = @($linuxTasksDoc.tasks)
        $linuxTasks.Count | Should -BeGreaterThan 0
        @($linuxTasks.id) | Should -Be @('labview-icon-api')
    }

    It 'defines a dedicated .lvcontainer contract file for vi-analyzer Linux container resolution' {
        (Test-Path -LiteralPath $script:lvcontainerPath -PathType Leaf) | Should -BeTrue
        $raw = (Get-Content -LiteralPath $script:lvcontainerPath -Raw).Trim()
        $raw | Should -Match '^(?:\d{4}q[1-4](?:patch\d+)?-(?:linux|windows(?:-beta)?)|latest-(?:linux|windows))$'
    }

    It 'resolves all VI Analyzer task config files from the task registry' {
        $tasks = @((Get-Content -Raw -Path $script:tasksPath | ConvertFrom-Json).tasks)
        foreach ($task in $tasks) {
            [string]::IsNullOrWhiteSpace([string]$task.config_path) | Should -BeFalse
            $configPath = if ([System.IO.Path]::IsPathRooted([string]$task.config_path)) {
                [string]$task.config_path
            } else {
                Join-Path $script:repoRoot ([string]$task.config_path)
            }

            (Test-Path -LiteralPath $configPath -PathType Leaf) | Should -BeTrue
        }
    }

    It 'wires vi-analyzer into CI self-hosted execution and parity container ownership' {
        (Test-Path -LiteralPath $script:ciPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $script:parityPath -PathType Leaf) | Should -BeTrue

        $ciContent = Get-Content -Raw -Path $script:ciPath
        $ciContent | Should -Not -Match '(?ms)^\s*container-contract:\s*$'
        $ciContent | Should -Match '(?ms)^  vi-analyzer:\s*$'
        $ciContent | Should -Match '(?ms)^  vi-analyzer:\s*.*?name:\s*vi-analyzer-\$\{\{\s*matrix\.bitness\s*\}\}-bit'
        $ciContent | Should -Match '(?ms)^  vi-analyzer:\s*.*?needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*apply-deps-64,\s*apply-deps-32\s*\]'
        $ciContent | Should -Match '(?ms)^  vi-analyzer:\s*.*?Tooling/Run-ViAnalyzer\.ps1'
        $ciContent | Should -Match '(?ms)^  publish-gate:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $ciContent | Should -Match '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $ciContent | Should -Match '(?ms)\$requiredFullValidation\s*=\s*@\(\s*.*?''vi-analyzer'''

        $parityContent = Get-Content -Raw -Path $script:parityPath
        $parityContent | Should -Not -Match '(?ms)^  vi-analyzer-linux:\s*$'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*$'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?name:\s*Parity \(Linux Container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*}}\)'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?LVIE_VI_ANALYZER_TASKS_PATH:\s*Tooling/vi-analyzer/tasks\.linux\.json'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_year\s*}}'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?run-vi-analyzer-linux\.sh'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?vi-analyzer-reports-parity'
        $parityContent | Should -Match '(?ms)^  parity-linux:\s*.*?vi-analyzer-status-parity'

        $parityContent | Should -Match '(?ms)^  parity-windows:\s*$'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?name:\s*Parity \(Windows Container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_windows_tag\s*}}\)'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?LVIE_VI_ANALYZER_TASKS_PATH:\s*Tooling\\vi-analyzer\\tasks\.json'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?run-vi-analyzer-windows\.ps1'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?vi-analyzer-windows-logs-parity'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?vi-analyzer-reports-parity-windows'
        $parityContent | Should -Match '(?ms)^  parity-windows:\s*.*?vi-analyzer-status-parity-windows'
        (Test-Path -LiteralPath $script:runViAnalyzerWindowsPath -PathType Leaf) | Should -BeTrue
    }

    It 'enforces non-zero analyzed tests and file-level failure extraction in Run-ViAnalyzer' {
        (Test-Path -LiteralPath $script:runViAnalyzerPath -PathType Leaf) | Should -BeTrue

        $content = Get-Content -Raw -Path $script:runViAnalyzerPath
        $content | Should -Match 'Resolve-LabVIEWCliPortFromContract'
        $content | Should -Match 'RunVIAnalyzer'
        $content | Should -Match 'analyzed_total'
        $content | Should -Match 'No tests were analyzed'
        $content | Should -Match 'Failed Tests'
        $content | Should -Match 'Testing Errors'
        $content | Should -Match 'failure_items'
        $content | Should -Match 'failure_file_paths'
    }
}
