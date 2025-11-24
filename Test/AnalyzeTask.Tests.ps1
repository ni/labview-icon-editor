$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VSCode Analyze task wiring" {
    It "Analyze VI Package task contains required flags and analyzer script" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $task = $json.tasks | Where-Object { $_.label -eq "Analyze VI Package (Pester)" } | Select-Object -First 1
        $task | Should -Not -BeNullOrEmpty

        $command = ($task.args -join ' ')
        $command | Should -Match "-NoProfile"
        $command | Should -Match "-File"
        $command | Should -Match "analyze-vi-package/run-local.ps1"
        $command | Should -Match "-VipArtifactPath"
        $command | Should -Match "-MinLabVIEW"
    }
}
