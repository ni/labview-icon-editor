Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OriginalPath = $env:PATH
$script:GhopsShellPath = $null

if (-not $script:GhopsShellPath) {
    if (Get-Command powershell -ErrorAction SilentlyContinue) {
        $script:GhopsShellPath = (Get-Command powershell).Path
    } elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $script:GhopsShellPath = (Get-Command pwsh).Path
    } else {
        throw 'Neither powershell nor pwsh is available on PATH.'
    }
}

Describe 'ghops PowerShell wrappers (dry-run smoke)' {
    BeforeAll {
        $repoRoot = Resolve-Path "$PSScriptRoot/../../.."
        Push-Location $repoRoot
        $env:GITHUB_REPOSITORY = 'LabVIEW-Community-CI-CD/x-cli'
        $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "ghops-smoke-$(Get-Random)") -Force
        $bin = Join-Path $tmp 'shim-bin'
        if (-not (Test-Path $bin)) { New-Item -ItemType Directory -Path $bin -Force | Out-Null }
        $updatedPath = $false
        if (-not (Get-Command pre-commit -ErrorAction SilentlyContinue)) {
            $stub = "@echo off`r`nREM ghops smoke stub for pre-commit`r`nexit /b 0`r`n"
            Set-Content -Path (Join-Path $bin 'pre-commit.cmd') -Value $stub -Encoding ASCII
            $updatedPath = $true
        }
        if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
            $stub = "@echo off`r`nREM ghops smoke stub for ssh`r`necho ssh stub invoked >&2`r`nexit /b 0`r`n"
            Set-Content -Path (Join-Path $bin 'ssh.cmd') -Value $stub -Encoding ASCII
            $updatedPath = $true
        }
        if (-not $script:GhopsShellPath) {
            if (Get-Command powershell -ErrorAction SilentlyContinue) {
                $script:GhopsShellPath = (Get-Command powershell).Path
            } elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {
                $script:GhopsShellPath = (Get-Command pwsh).Path
            } else {
                throw 'Neither powershell nor pwsh is available on PATH.'
            }
        }
        if ($updatedPath) { $env:PATH = $bin + ';' + $script:OriginalPath }
    }
    AfterAll {
        Pop-Location
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        $env:PATH = $script:OriginalPath
    }

    It 'pr-create.ps1 supports -DryRun without gh/git' {
        $ps1 = 'scripts/ghops/pr-create.ps1'
        $out = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 test-branch "test title" -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '\[dry-run\]'
    }

    It 'run-watch.ps1 supports -DryRun' {
        $ps1 = 'scripts/ghops/run-watch.ps1'
        $out = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 build.yml --branch develop -ErrorAction Continue -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '\[dry-run\]'
    }

    It 'run-rerun.ps1 supports -DryRun' {
        $ps1 = 'scripts/ghops/run-rerun.ps1'
        $out = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 --workflow build.yml -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '\[dry-run\]'
    }

    It 'artifacts-download.ps1 supports -DryRun and creates out dir' {
        $ps1 = 'scripts/ghops/artifacts-download.ps1'
        $outDir = Join-Path $tmp 'out'
        $out = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 --workflow build.yml -o $outDir -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        Test-Path $outDir | Should -BeTrue
        ($out -join "`n") | Should -Match '\[dry-run\]'
    }

    It 'release-tag.ps1 supports -DryRun' {
        $ps1 = 'scripts/ghops/release-tag.ps1'
        $out = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 v0.0.0-ghops-smoke -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '\[dry-run\]'
    }
}

Describe 'ghops PowerShell wrappers (JSON mode smoke)' {
    BeforeAll {
        $repoRoot = Resolve-Path "$PSScriptRoot/../../.."
        Push-Location $repoRoot
        $env:GITHUB_REPOSITORY = 'LabVIEW-Community-CI-CD/x-cli'
    }
    AfterAll { Pop-Location }

    It 'pr-create.ps1 emits JSON with -Json' {
        $ps1 = 'scripts/ghops/pr-create.ps1'
        $json = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 test-json "test json" -DryRun -Json
        $obj = $json | ConvertFrom-Json
        $obj.branch | Should -Be 'test-json'
        $obj.commands.Count | Should -BeGreaterThan 0
    }

    It 'run-watch.ps1 emits JSON with -Json' {
        $ps1 = 'scripts/ghops/run-watch.ps1'
        $json = & "${script:GhopsShellPath}"  -NoProfile -File $ps1 build.yml -DryRun -Json
        $obj = $json | ConvertFrom-Json
        $obj.runId | Should -Be '<resolved-run-id>'
    }
}
