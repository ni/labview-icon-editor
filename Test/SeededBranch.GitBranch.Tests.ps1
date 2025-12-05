$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "Git Branch Operations" {
    BeforeAll {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TempRepo -Force | Out-Null
        
        Push-Location $script:TempRepo
        git init --initial-branch=main 2>&1 | Out-Null
        git config user.email "test@test.com" 2>&1 | Out-Null
        git config user.name "Test" 2>&1 | Out-Null
        "init" | Set-Content README.md
        git add . 2>&1 | Out-Null
        git commit -m "init" 2>&1 | Out-Null
        git checkout -b develop 2>&1 | Out-Null
        Pop-Location
    }

    AfterAll {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "creates seed branch from develop" {
        Push-Location $script:TempRepo
        git checkout -b "seed/lv2025q3-64bit-test" develop 2>&1 | Out-Null
        $result = git branch --list "seed/lv2025q3-64bit-test"
        $result | Should -Not -BeNullOrEmpty
        git checkout develop 2>&1 | Out-Null
        git branch -D "seed/lv2025q3-64bit-test" 2>&1 | Out-Null
        Pop-Location
    }

    It "lists seed branches with pattern" {
        Push-Location $script:TempRepo
        git checkout -b "seed/lv2025q3-64bit-a" develop 2>&1 | Out-Null
        git checkout develop 2>&1 | Out-Null
        git checkout -b "seed/lv2024q1-32bit-b" develop 2>&1 | Out-Null
        git checkout develop 2>&1 | Out-Null
        
        $branches = git for-each-ref --format='%(refname:short)' 'refs/heads/seed/*'
        ($branches | Measure-Object).Count | Should -Be 2
        
        git branch -D "seed/lv2025q3-64bit-a" 2>&1 | Out-Null
        git branch -D "seed/lv2024q1-32bit-b" 2>&1 | Out-Null
        Pop-Location
    }

    It "handles multiple timestamps for same version" {
        Push-Location $script:TempRepo
        git checkout -b "seed/lv2025q3-64bit-ts1" develop 2>&1 | Out-Null
        git checkout develop 2>&1 | Out-Null
        git checkout -b "seed/lv2025q3-64bit-ts2" develop 2>&1 | Out-Null
        git checkout develop 2>&1 | Out-Null
        
        $branches = git branch --list "seed/lv2025q3-64bit-*"
        ($branches | Measure-Object).Count | Should -Be 2
        
        git branch -D "seed/lv2025q3-64bit-ts1" 2>&1 | Out-Null
        git branch -D "seed/lv2025q3-64bit-ts2" 2>&1 | Out-Null
        Pop-Location
    }
}
