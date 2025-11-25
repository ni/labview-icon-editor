$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VSCode Analyze task wiring" {
    It "does not expose a VS Code task (CLI only)" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $task = $json.tasks | Where-Object { $_.label -eq "Analyze VI Package (Pester)" } | Select-Object -First 1
        $task | Should -BeNullOrEmpty
    }
}
