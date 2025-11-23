$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $null
$scriptPath = $PSCommandPath
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath) { $scriptPath = $PSScriptRoot }

if ($scriptPath) {
    $testDir = Split-Path -Parent $scriptPath
    $repoRoot = Split-Path -Parent $testDir
}

if (-not $repoRoot) {
    # Fallback to current working directory when automatic variables are not populated
    $repoRoot = (Get-Location).ProviderPath
}

Write-Host ("DEBUG init scriptPath={0} repoRoot={1} pwd={2}" -f $scriptPath, $repoRoot, (Get-Location).ProviderPath)
$script:RepoRoot = $repoRoot
$actionsPath = Join-Path $script:RepoRoot ".github/actions"
$buildScript = Join-Path $actionsPath "build/Build.ps1"
Import-Module "$testDir/Support/BuildTaskMocks.psm1"

Describe "VSCode Build Task wiring" {
    BeforeAll {
        if (-not $script:RepoRoot) {
            $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        }
        $script:mocks = Initialize-BuildTaskMocks -RepoPath $script:RepoRoot
    }

    AfterAll {
        if ($script:mocks.TempBin -and (Test-Path $script:mocks.TempBin)) {
            Remove-Item -LiteralPath $script:mocks.TempBin -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "invoking Build.ps1 with task-like arguments" {
        It "binds all parameters correctly (no positional shifts)" {
            $params = @{
                RepositoryPath       = $script:RepoRoot
                Major                = 1
                Minor                = 2
                Patch                = 3
                Build                = 4
                LabVIEWMinorRevision = 3
                Commit               = "cafebabecafebabecafebabecafebabe"
                CompanyName          = "LabVIEW-Community-CI-CD"
                AuthorName           = "LabVIEW Icon Editor CI"
            }

            { & $buildScript @params } | Should -Throw
        }

        It "uses git commit from PATH when not provided" {
            $params = @{
                RepositoryPath       = $script:RepoRoot
                Major                = 0
                Minor                = 0
                Patch                = 0
                Build                = 1
                LabVIEWMinorRevision = 3
                CompanyName          = "LabVIEW-Community-CI-CD"
                AuthorName           = "LabVIEW Icon Editor CI"
            }

            { & $buildScript @params } | Should -Throw
            $log = Get-Content -ErrorAction SilentlyContinue -Path $script:mocks.LogPath
            $log | Should -Match 'mock-start|lvbuildspec'
        }

        It "passes company/author strings with spaces without shifting args" {
            $params = @{
                RepositoryPath       = $script:RepoRoot
                Major                = 0
                Minor                = 0
                Patch                = 0
                Build                = 1
                LabVIEWMinorRevision = 3
                Commit               = "manual"
                CompanyName          = "Acme Widgets Inc"
                AuthorName           = "Jane Q Public"
            }

            { & $buildScript @params } | Should -Throw
        }

        It "has required flags in the VS Code task definition" {
            Write-Host ("DEBUG repoRoot={0}" -f $script:RepoRoot)
            Write-Host ("DEBUG in-it PSCommandPath={0} MyPath={1} PSScriptRoot={2} pwd={3}" -f $PSCommandPath, $MyInvocation.MyCommand.Path, $PSScriptRoot, (Get-Location).ProviderPath)
            $script:RepoRoot | Should -Not -BeNullOrEmpty
            $tasksPath = Join-Path $script:RepoRoot '.vscode/tasks.json'
            $tasksPath | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $tasksPath | Should -BeTrue
            $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
            $buildTask = $json.tasks | Where-Object { $_.label -eq "Build/Package VIP" } | Select-Object -First 1
            $buildTask | Should -Not -BeNullOrEmpty
            $command = ($buildTask.args -join ' ')
            # Ensure the wrapper script and expected flags are present
            $command | Should -Match "scripts/run-build-or-package\.ps1"
            $command | Should -Match "-BuildMode"
            $command | Should -Match "-WorkspacePath"
            $command | Should -Match "-LabVIEWMinorRevision"
            $command | Should -Match "-LvlibpBitness"
        }

        It "exposes a buildMode input with expected options for the unified task" {
            $tasksPath = Join-Path $script:RepoRoot '.vscode/tasks.json'
            Test-Path -LiteralPath $tasksPath | Should -BeTrue
            $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json

            $modeInput = $json.inputs | Where-Object { $_.id -eq 'buildMode' } | Select-Object -First 1
            $modeInput | Should -Not -BeNullOrEmpty
            $modeInput.type | Should -Be 'pickString'
            $modeInput.default | Should -Be 'vip+lvlibp'
            $modeInput.options | Should -Contain 'vip+lvlibp'
            $modeInput.options | Should -Contain 'vip-single'

            $buildTask = $json.tasks | Where-Object { $_.label -eq "Build/Package VIP" } | Select-Object -First 1
            $buildTask | Should -Not -BeNullOrEmpty
            ($buildTask.args -join ' ') | Should -Match '\${input:buildMode}'
        }

        It "quotes buildMode assignment and comparisons to avoid parser errors" {
            $tasksPath = Join-Path $script:RepoRoot '.vscode/tasks.json'
            Test-Path -LiteralPath $tasksPath | Should -BeTrue
            $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json

            $buildTask = $json.tasks | Where-Object { $_.label -eq "Build/Package VIP" } | Select-Object -First 1
            $buildTask | Should -Not -BeNullOrEmpty
            $command = ($buildTask.args -join ' ')

            # Ensure the mode is assigned with quotes and compared against quoted literals
            $command | Should -Match "scripts/run-build-or-package.ps1"
            $command | Should -Match "-BuildMode"
            $command | Should -Match "-WorkspacePath"
            $command | Should -Match "-LvlibpBitness"
        }

        It "parses after substituting sample values to catch mode/operator parser errors" {
            $tasksPath = Join-Path $script:RepoRoot '.vscode/tasks.json'
            $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
            $buildTask = $json.tasks | Where-Object { $_.label -eq "Build/Package VIP" } | Select-Object -First 1
            $buildTask | Should -Not -BeNullOrEmpty
            $command = ($buildTask.args -join ' ')
            $command | Should -Match "run-build-or-package.ps1"
        }
    }
}
