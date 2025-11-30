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
$actionsPath = Join-Path $script:RepoRoot "scripts"
$buildScript = Join-Path $actionsPath "build/Build.ps1"
Import-Module "$testDir/Support/BuildTaskMocks.psm1"

Describe "VSCode Build Task wiring" {
    BeforeAll {
        if (-not (Get-Variable -Name RepoRoot -Scope Script -ErrorAction SilentlyContinue)) {
            Set-Variable -Name RepoRoot -Scope Script -Value $null
        }
        if (-not $script:RepoRoot) {
            $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        }

        if (-not (Get-Variable -Name mocks -Scope Script -ErrorAction SilentlyContinue)) {
            Set-Variable -Name mocks -Scope Script -Value $null
        }
        $script:mocks = Initialize-BuildTaskMocks -RepoPath $script:RepoRoot
    }

    AfterAll {
        $mocksVar = Get-Variable -Name mocks -Scope Script -ErrorAction SilentlyContinue
        if ($mocksVar) {
            $mocks = $mocksVar.Value
            if ($mocks -and $mocks.TempBin -and (Test-Path $mocks.TempBin)) {
                Remove-Item -LiteralPath $mocks.TempBin -Recurse -Force -ErrorAction SilentlyContinue
            }
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

        It "exposes only the Build LVAddon task with expected defaults" {
            Write-Host ("DEBUG repoRoot={0}" -f $script:RepoRoot)
            $myPath = $MyInvocation.MyCommand | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
            Write-Host ("DEBUG in-it PSCommandPath={0} MyPath={1} PSScriptRoot={2} pwd={3}" -f $PSCommandPath, $myPath, $PSScriptRoot, (Get-Location).ProviderPath)
            $script:RepoRoot | Should -Not -BeNullOrEmpty

            $tasksPath = Join-Path $script:RepoRoot '.vscode/tasks.json'
            Test-Path -LiteralPath $tasksPath | Should -BeTrue

            $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
            $json.tasks.Count | Should -BeGreaterThan 1

            $depsTask = $json.tasks | Where-Object { $_.label -eq "01 Verify / Apply dependencies" } | Select-Object -First 1
            $depsTask | Should -Not -BeNullOrEmpty
            $depsCommand = ($depsTask.args -join ' ')
            $depsCommand | Should -Match "task-verify-apply-dependencies"
            $depsCommand | Should -BeLike "*-SupportedBitness both*"
            $depsCommand | Should -BeLike "*-VipcPath runner_dependencies.vipc*"

            $buildTask = $json.tasks | Where-Object { $_.label -eq "02 Build LVAddon (VI Package)" } | Select-Object -First 1
            $buildTask | Should -Not -BeNullOrEmpty

            $command = ($buildTask.args -join ' ')
            $command | Should -Match "scripts/ie\.ps1"
            $command | Should -Match "-Command\s+build-worktree"
            $command | Should -Match "-RepositoryPath"
            $command | Should -Match "-SupportedBitness\s+64"
            $command | Should -Match "-LvlibpBitness\s+both"
            $command | Should -Match "-Major\s+0\s+-Minor\s+1\s+-Patch\s+0\s+-Build\s+1"
        }
    }
}
