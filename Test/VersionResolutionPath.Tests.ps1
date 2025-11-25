$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "LabVIEW version resolution wiring" {
    BeforeAll {
        # Import module and resolve repo paths within the run phase to avoid discovery/run split issues
        Import-Module powershell-yaml -ErrorAction Stop

        $repoRoot = $null
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { $scriptPath = $PSScriptRoot }

        if ($scriptPath) {
            $testDir = Split-Path -Parent $scriptPath
            $repoRoot = Split-Path -Parent $testDir
        }

        if (-not $repoRoot) {
            # Fallback for environments that do not populate script metadata
            $repoRoot = (Get-Location).ProviderPath
        }

        $script:repoRoot = $repoRoot
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:actionPath = Join-Path $script:repoRoot 'scripts/run-unit-tests/RunUnitTests.ps1'

        Test-Path -LiteralPath $script:workflowPath | Should -BeTrue
        Test-Path -LiteralPath $script:actionPath   | Should -BeTrue

        $script:Workflow = Get-Content -LiteralPath $script:workflowPath -Raw | ConvertFrom-Yaml
    }

    Context "resolve-labview-version job" {
        It "invokes get-package-lv-version.ps1 from the workspace root" {
            $job = $script:Workflow.jobs.'resolve-labview-version'
            $job | Should -Not -BeNullOrEmpty

            $readStep = @($job.steps) | Where-Object { $_.id -eq 'read' }
            $readStep | Should -Not -BeNullOrEmpty

            $readStep.run | Should -Match '\$env:GITHUB_WORKSPACE/scripts/get-package-lv-version\.ps1'
        }
    }

    Context "unit-test jobs" {
        BeforeAll {
            $script:ExpectedVersionExpr = '${{ needs.resolve-labview-version.outputs.minimum_supported_lv_version }}'
        }

        It "propagates the resolved version into both x64 and x86 runs" {
            foreach ($jobKey in 'test-x64', 'test-x86') {
                $job = $script:Workflow.jobs.$jobKey
                $job | Should -Not -BeNullOrEmpty

                $job.env.LABVIEW_VERSION | Should -Be $script:ExpectedVersionExpr

                $runs = @($job.steps | ForEach-Object { $_.run }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $runs | Should -Not -BeNullOrEmpty

                $unitRuns = $runs | Where-Object { $_ -match 'run-unit-tests/RunUnitTests\.ps1' }
                $unitRuns | Should -Not -BeNullOrEmpty

                $pattern = '-Package_LabVIEW_Version\s+"?\${{ needs\.resolve-labview-version\.outputs\.minimum_supported_lv_version }}"?'
                ($unitRuns | Where-Object { $_ -match $pattern }) | Should -Not -BeNullOrEmpty
            }
        }
    }

}
