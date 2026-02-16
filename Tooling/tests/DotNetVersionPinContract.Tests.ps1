#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Dotnet version pin contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:pinnedVersion = '8.0.418'
        $script:activeWorkflowFiles = @(
            '.github/workflows/ci.yml'
            '.github/workflows/labview-parity.yml'
            '.github/workflows/runner-cli.yml'
            '.github/workflows/runner-cli-reusable.yml'
        )
    }

    It 'pins setup-dotnet to an exact version in active workflows' {
        foreach ($relativePath in $script:activeWorkflowFiles) {
            $fullPath = Join-Path $script:repoRoot $relativePath
            Test-Path -Path $fullPath -PathType Leaf | Should -BeTrue -Because ("Expected workflow file is missing: {0}" -f $relativePath)

            $content = Get-Content -Path $fullPath -Raw
            $matches = [regex]::Matches($content, "(?im)dotnet-version:\s*'([^']+)'")
            $matches.Count | Should -BeGreaterThan 0 -Because ("No dotnet-version pins found in {0}" -f $relativePath)

            foreach ($match in $matches) {
                $version = [string]$match.Groups[1].Value
                $version | Should -Be $script:pinnedVersion -Because ("Unexpected dotnet-version in {0}" -f $relativePath)
            }
        }
    }

    It 'forbids wildcard setup-dotnet versions in workflow files' {
        $workflowRoot = Join-Path $script:repoRoot '.github/workflows'
        $workflowFiles = @(Get-ChildItem -Path $workflowRoot -Filter '*.yml' -File -ErrorAction Stop)
        foreach ($workflowFile in $workflowFiles) {
            $content = Get-Content -Path $workflowFile.FullName -Raw
            if ($content -match '(?im)uses:\s*actions/setup-dotnet@') {
                $content | Should -Not -Match "(?im)dotnet-version:\s*['""]?\d+\.\d+\.x['""]?" -Because ("Wildcard dotnet-version is forbidden in {0}" -f $workflowFile.Name)
            }
        }
    }
}
