#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'VI Analyzer composite contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $actionPath = Join-Path $repoRoot '.github/actions/vi-analyzer-ci/action.yml'
        $tasksLinuxPath = Join-Path $repoRoot 'Tooling/vi-analyzer/tasks.linux.json'
        $tasksDefaultPath = Join-Path $repoRoot 'Tooling/vi-analyzer/tasks.json'
        $singleConfigPath = Join-Path $repoRoot 'lv_icon_editor.viancfg'
        if (-not (Test-Path -LiteralPath $actionPath -PathType Leaf)) {
            throw "Composite action not found: $actionPath"
        }
        if (-not (Test-Path -LiteralPath $tasksLinuxPath -PathType Leaf)) {
            throw "VI Analyzer linux task registry not found: $tasksLinuxPath"
        }
        if (-not (Test-Path -LiteralPath $tasksDefaultPath -PathType Leaf)) {
            throw "VI Analyzer default task registry not found: $tasksDefaultPath"
        }
        if (-not (Test-Path -LiteralPath $singleConfigPath -PathType Leaf)) {
            throw "Expected VI Analyzer config not found: $singleConfigPath"
        }

        $script:content = Get-Content -LiteralPath $actionPath -Raw
        $script:tasksLinux = Get-Content -LiteralPath $tasksLinuxPath -Raw | ConvertFrom-Json
        $script:tasksDefault = Get-Content -LiteralPath $tasksDefaultPath -Raw | ConvertFrom-Json
    }

    It 'defines required inputs and outputs for VI Analyzer runtime contract' {
        foreach ($token in @(
            'container_tag:',
            'image_repository:',
            'tasks_path:',
            'labview_year:',
            'reports_root:',
            'logs_root:',
            'status_path:'
        )) {
            $script:content | Should -Match ([regex]::Escape($token))
        }

        foreach ($outputToken in @('status:', 'container_image:', 'status_path:', 'reports_root:', 'logs_root:')) {
            $script:content | Should -Match ([regex]::Escape($outputToken))
        }
    }

    It 'pulls container image and runs Linux VI Analyzer worker with deterministic paths' {
        $script:content | Should -Match 'docker pull'
        $script:content | Should -Match 'run-vi-analyzer-linux\.sh'
        $script:content | Should -Match 'LVIE_VI_ANALYZER_TASKS_PATH'
        $script:content | Should -Match 'source-sync-manifest-vi-analyzer-linux\.json'
        $script:content | Should -Match '/workspace/labview-icon-editor'
        $script:content | Should -Match 'LVIE_VI_ANALYZER_SYNC_TO_INSTALL=false'
        $script:content | Should -Match 'LVIE_VI_ANALYZER_ENABLE_MASSCOMPILE=false'
    }

    It 'includes ownership normalization and deterministic failure path' {
        $script:content | Should -Match 'sudo chown -R'
        $script:content | Should -Match 'if \(\$status -eq ''fail''\)'
        $script:content | Should -Match 'throw "VI Analyzer composite gate failed'
    }

    It 'records per-task config evidence in status artifact and step summary' {
        $script:content | Should -Match 'vi_analyzer_tasks'
        $script:content | Should -Match 'task_id'
        $script:content | Should -Match 'resolved_config_path_container'
        $script:content | Should -Match 'VI Analyzer Task Config Evidence'
    }

    It 'uses lv_icon_editor.viancfg as the only VI Analyzer configuration' {
        $script:tasksLinux.tasks.Count | Should -Be 1
        $script:tasksDefault.tasks.Count | Should -Be 1
        $script:tasksLinux.tasks[0].id | Should -Be 'labview-icon-editor'
        $script:tasksDefault.tasks[0].id | Should -Be 'labview-icon-editor'
        $script:tasksLinux.tasks[0].config_path | Should -Be 'lv_icon_editor.viancfg'
        $script:tasksDefault.tasks[0].config_path | Should -Be 'lv_icon_editor.viancfg'
    }
}
