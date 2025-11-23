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
        $script:actionPath = Join-Path $script:repoRoot '.github/actions/run-unit-tests/action.yml'

        Test-Path -LiteralPath $script:workflowPath | Should -BeTrue
        Test-Path -LiteralPath $script:actionPath   | Should -BeTrue

        $script:Workflow = Get-Content -LiteralPath $script:workflowPath -Raw | ConvertFrom-Yaml
        $script:Action   = Get-Content -LiteralPath $script:actionPath -Raw   | ConvertFrom-Yaml
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

                $unitStep = @($job.steps) | Where-Object { $_.uses -eq './.github/actions/run-unit-tests' }
                $unitStep | Should -Not -BeNullOrEmpty
                $unitStep.with.labview_version | Should -Be $script:ExpectedVersionExpr
            }
        }
    }

    Context "run-unit-tests composite action" {
        It "relies on provided labview_version input or LABVIEW_VERSION env and passes it to RunUnitTests.ps1" {
            $runStep = @($script:Action.runs.steps) | Where-Object { $_.name -eq 'Run RunUnitTests.ps1' }
            $runStep | Should -Not -BeNullOrEmpty

            $scriptBlock = $runStep.run
            $scriptBlock | Should -Match '\$Env:LABVIEW_VERSION'
            $scriptBlock | Should -Match '-Package_LabVIEW_Version \$lvVer'
            $scriptBlock | Should -Not -Match 'get-package-lv-version\.ps1'
        }
    }
}
