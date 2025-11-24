$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\build-meta-utils.psm1')).Path
Import-Module $modulePath -Force

Describe "Get-RepoOwner" {
    It "parses owner from https origin" {
        Mock -CommandName git -ModuleName build-meta-utils -MockWith { "https://github.com/example-owner/repo.git" }
        $owner = Get-RepoOwner -RepoPath $TestDrive
        $owner | Should -Be "example-owner"
    }

    It "parses owner from ssh origin" {
        Mock -CommandName git -ModuleName build-meta-utils -MockWith { "git@github.com:owner-ssh/repo.git" }
        $owner = Get-RepoOwner -RepoPath $TestDrive
        $owner | Should -Be "owner-ssh"
    }

    It "falls back to folder name when git fails" {
        $fakeRepo = Join-Path $TestDrive 'myrepo'
        New-Item -ItemType Directory -Path $fakeRepo | Out-Null
        Mock -CommandName git -ModuleName build-meta-utils -MockWith { throw "no remote" }
        $owner = Get-RepoOwner -RepoPath $fakeRepo
        $owner | Should -Be "myrepo"
    }
}

Describe "Resolve-CompanyName" {
    It "uses provided name when not placeholder" {
        $result = Resolve-CompanyName -CompanyName "CustomCo" -RepoPath $TestDrive
        $result | Should -Be "CustomCo"
    }

    It "falls back to owner when placeholder" {
        Mock -CommandName git -ModuleName build-meta-utils -MockWith { "https://github.com/fallback-co/repo.git" }
        $result = Resolve-CompanyName -CompanyName "LabVIEW-Community-CI-CD" -RepoPath $TestDrive
        $result | Should -Be "fallback-co"
    }
}

Describe "Resolve-AuthorName" {
    It "uses provided name when not placeholder" {
        $result = Resolve-AuthorName -AuthorName "Jane Dev" -RepoPath $TestDrive
        $result | Should -Be "Jane Dev"
    }

    It "falls back to owner when placeholder" {
        Mock -CommandName git -ModuleName build-meta-utils -MockWith { "git@github.com:author-handle/repo.git" }
        $result = Resolve-AuthorName -AuthorName "Local Developer" -RepoPath $TestDrive
        $result | Should -Be "author-handle"
    }
}
