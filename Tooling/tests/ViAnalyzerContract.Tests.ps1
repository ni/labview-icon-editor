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

    It 'wires vi-analyzer into parity ownership and keeps CI wiring during phased cutover' {
        (Test-Path -LiteralPath $script:ciPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $script:parityPath -PathType Leaf) | Should -BeTrue

        $ciContent = Get-Content -Raw -Path $script:ciPath
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*$'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?Resolve \.lvcontainer'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*raw:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*tag:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*image:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*os:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*year:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*minor:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*release_tag:'
        $ciContent | Should -Match '(?ms)^\s*container-contract:\s*.*?outputs:\s*.*?\n\s*linux_image:'
        $ciViAnalyzerBlockMatch = [regex]::Match(
            $ciContent,
            '(?ms)^  vi-analyzer:\s*$.*?(?=^  [A-Za-z0-9_-]+:\s*$)'
        )
        $ciViAnalyzerBlockMatch.Success | Should -BeTrue
        $ciViAnalyzerBlock = $ciViAnalyzerBlockMatch.Value

        $ciViAnalyzerBlock | Should -Match '(?m)^\s*name:\s*VI Analyzer Linux container \${{\s*needs\.container-contract\.outputs\.raw\s*}}'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*container-contract\s*\]'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*runs-on:\s*ubuntu-latest'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_VI_ANALYZER_TASKS_PATH:\s*Tooling/vi-analyzer/tasks\.linux\.json'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.container-contract\.outputs\.tag\s*}}'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_CONTAINER_CONTRACT_IMAGE:\s*\${{\s*needs\.container-contract\.outputs\.image\s*}}'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_CONTAINER_CONTRACT_OS:\s*\${{\s*needs\.container-contract\.outputs\.os\s*}}'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_CONTAINER_CONTRACT_LINUX_IMAGE:\s*\${{\s*needs\.container-contract\.outputs\.linux_image\s*}}'
        $ciViAnalyzerBlock | Should -Match 'Validate vi-analyzer container selection'
        $ciViAnalyzerBlock | Should -Match 'requires a linux container tag'
        $ciViAnalyzerBlock | Should -Match 'Run VI Analyzer tasks \(Linux container\)'
        $ciViAnalyzerBlock | Should -Match '(?m)^\s*LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.container-contract\.outputs\.year\s*}}'
        $ciViAnalyzerBlock | Should -Match 'image="\$\{LVIE_CONTAINER_CONTRACT_LINUX_IMAGE\}"'
        $ciViAnalyzerBlock | Should -Match 'run-vi-analyzer-linux\.sh'
        $ciViAnalyzerBlock | Should -Not -Match 'LV_RELEASE:\s*\${{\s*format\(''\{0\}q1'',\s*needs\.version-gate\.outputs\.year\)\s*}}'
        $ciContent | Should -Match '(?ms)publish-gate:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $ciContent | Should -Match '(?ms)pipeline-contract:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$'
        $ciContent | Should -Match '(?ms)\$requiredCommon\s*=\s*@\(\s*.*?''vi-analyzer'''

        $parityContent = Get-Content -Raw -Path $script:parityPath
        $parityContent | Should -Match '(?ms)^  vi-analyzer-linux:\s*$'
        $parityContent | Should -Match '(?ms)^  vi-analyzer-linux:\s*.*?name:\s*VI Analyzer Linux container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*}}'
        $parityContent | Should -Match '(?ms)^  vi-analyzer-linux:\s*.*?LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
        $parityContent | Should -Match '(?ms)^  vi-analyzer-linux:\s*.*?LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_year\s*}}'
        $parityContent | Should -Match '(?ms)^  vi-analyzer-linux:\s*.*?run-vi-analyzer-linux\.sh'
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
