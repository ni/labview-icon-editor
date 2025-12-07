$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "Invoke-TelemetryPipeline.ps1 parameter forwarding" {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:telemetryScript = Join-Path $script:repoRoot 'scripts/telemetry/Invoke-TelemetryPipeline.ps1'
        
        # Use cross-platform temp directory with GUID for uniqueness
        $tmpBase = [System.IO.Path]::GetTempPath()
        $script:tmpDir = New-Item -ItemType Directory -Path (Join-Path $tmpBase "telemetry-pipeline-tests-$([System.Guid]::NewGuid().ToString())") -Force
        
        # Create minimal artifacts directory
        $script:artifactsDir = Join-Path $script:tmpDir 'artifacts'
        New-Item -ItemType Directory -Path $script:artifactsDir -Force | Out-Null
        
        # Create minimal telemetry directory
        $script:telemetryDir = Join-Path $script:tmpDir 'telemetry'
        New-Item -ItemType Directory -Path $script:telemetryDir -Force | Out-Null
    }
    
    AfterAll {
        if ($script:tmpDir -and (Test-Path $script:tmpDir)) { 
            Remove-Item -Recurse -Force $script:tmpDir -ErrorAction SilentlyContinue
        }
    }

    It "correctly forwards --output parameter to x-cli without binding error" {
        # This test verifies that --output is passed to x-cli rather than being
        # interpreted as a parameter of invoke-repo-cli.ps1
        
        $eventsPath = Join-Path $script:artifactsDir 'test-telemetry.jsonl'
        $summaryPath = Join-Path $script:telemetryDir 'test-summary.json'
        $historyPath = Join-Path $script:telemetryDir 'test-history.jsonl'
        
        # Run with minimal required parameters
        # If --output is incorrectly bound to the wrapper, this will fail with:
        # "A parameter cannot be found that matches parameter name '-output'"
        { 
            & pwsh -NoProfile -File $script:telemetryScript `
                -Step 'test-step' `
                -Status 'pass' `
                -RepositoryPath $script:repoRoot `
                -EventsPath $eventsPath `
                -SummaryPath $summaryPath `
                -HistoryPath $historyPath `
                -DurationMs 100 `
                -MaxFailures 0 `
                -IncludeGitMeta:$false `
                -ErrorAction Stop
        } | Should -Not -Throw
        
        # Verify x-cli actually ran and created the output files
        Test-Path $eventsPath | Should -BeTrue -Because "x-cli should create events file at --output path"
        Test-Path $summaryPath | Should -BeTrue -Because "x-cli should create summary file"
    }

    It "handles custom output paths with dashes" {
        # Test that paths with dashes work correctly
        $customEventsPath = Join-Path $script:artifactsDir 'my-custom-telemetry-output.jsonl'
        $customSummaryPath = Join-Path $script:telemetryDir 'my-custom-summary.json'
        $customHistoryPath = Join-Path $script:telemetryDir 'my-custom-history.jsonl'
        
        { 
            & pwsh -NoProfile -File $script:telemetryScript `
                -Step 'custom-test' `
                -Status 'pass' `
                -RepositoryPath $script:repoRoot `
                -EventsPath $customEventsPath `
                -SummaryPath $customSummaryPath `
                -HistoryPath $customHistoryPath `
                -DurationMs 50 `
                -MaxFailures 0 `
                -IncludeGitMeta:$false `
                -ErrorAction Stop
        } | Should -Not -Throw
        
        Test-Path $customEventsPath | Should -BeTrue
        Test-Path $customSummaryPath | Should -BeTrue
    }
}
