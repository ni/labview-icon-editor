$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VSCode Dev Mode Task wiring" {
    It "exposes a bitness input for dev-mode tasks" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $bitnessInput = $json.inputs | Where-Object { $_.id -eq 'devModeBitness' } | Select-Object -First 1
        $bitnessInput | Should -Not -BeNullOrEmpty
        $bitnessInput.type | Should -Be 'pickString'
        $bitnessInput.default | Should -Be '64'
        $bitnessInput.options | Should -Contain '32'
        $bitnessInput.options | Should -Contain '64'
        $bitnessInput.options | Should -Not -Contain 'both'
    }

    It "Set/ Revert Dev Mode tasks contain required flags to avoid quoting errors" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $labels = @("Set Dev Mode (LabVIEW)", "Revert Dev Mode (LabVIEW)")
        foreach ($label in $labels) {
            $task = $json.tasks | Where-Object { $_.label -eq $label } | Select-Object -First 1
            $task | Should -Not -BeNullOrEmpty
            $task.args | Should -Contain "-SupportedBitness"
            $task.args | Should -Contain '${input:devModeBitness}'
            $command = ($task.args -join ' ')
            $command | Should -Match "-NoProfile"
            $command | Should -Match "-File"
            $command | Should -Match "run-dev-mode.ps1"
            # Ensure no inline -Command usage for these wrappers
            $command | Should -Not -Match "-Command"
            # Ensure we don't embed accidental g-cli flag fragments (e.g., double-dash in the wrapper args)
            $command | Should -Not -Match "--lv-ver"
            $command | Should -Not -Match "--arch"
        }
    }
}
