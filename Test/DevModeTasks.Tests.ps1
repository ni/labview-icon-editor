$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VSCode Dev Mode Task wiring" {
    It "omits dev-mode tasks and inputs (CLI only)" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $json.inputs | Should -BeNullOrEmpty

        $labels = @(
            "Dev Mode Bind (check + run)",
            "Dev Mode Bind (force overwrite)",
            "Dev Mode (interactive bind/unbind)",
            "Revert Dev Mode (LabVIEW)",
            "Set Dev Mode (LabVIEW)"
        )

        foreach ($label in $labels) {
            $task = $json.tasks | Where-Object { $_.label -eq $label } | Select-Object -First 1
            $task | Should -BeNullOrEmpty
        }
    }
}
