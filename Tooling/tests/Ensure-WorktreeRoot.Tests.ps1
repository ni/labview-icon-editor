#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Ensure-WorktreeRoot contract' {
    BeforeAll {
        $script:toolingRoot = Split-Path -Parent $PSScriptRoot
        $script:repoRoot = (Resolve-Path -Path (Join-Path $script:toolingRoot '..')).Path
        $script:ensureScript = Join-Path $script:toolingRoot 'Ensure-WorktreeRoot.ps1'
        $script:runnerLockScript = Join-Path $script:toolingRoot 'RunnerLock.ps1'
        $script:savedWorktreeRoot = $env:LVIE_WORKTREE_ROOT

        function Get-ExpectedRepoDerivedRoot {
            param([string]$RepoRoot)

            $normalized = [System.IO.Path]::GetFullPath($RepoRoot)
            $separator = [System.IO.Path]::DirectorySeparatorChar
            $marker = "{0}worktrees{0}" -f $separator
            $index = $normalized.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
            if ($index -ge 0) {
                $prefix = $normalized.Substring(0, $index)
                if ([string]::IsNullOrWhiteSpace($prefix)) {
                    return "{0}worktrees" -f $separator
                }
                return Join-Path $prefix 'worktrees'
            }

            return Join-Path $normalized 'worktrees'
        }
    }

    AfterAll {
        if ($null -eq $script:savedWorktreeRoot) {
            Remove-Item -Path Env:LVIE_WORKTREE_ROOT -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_WORKTREE_ROOT = $script:savedWorktreeRoot
        }
    }

    It 'returns normalized explicit worktree root override' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-worktree-explicit-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        try {
            $resolved = & $script:ensureScript -WorktreeRoot $tempRoot
            $resolved | Should -Be ([System.IO.Path]::GetFullPath($tempRoot))
        } finally {
            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'honors LVIE_WORKTREE_ROOT when set' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-worktree-env-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        try {
            $env:LVIE_WORKTREE_ROOT = $tempRoot
            $resolved = & $script:ensureScript
            $resolved | Should -Be ([System.IO.Path]::GetFullPath($tempRoot))
        } finally {
            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            if ($null -eq $script:savedWorktreeRoot) {
                Remove-Item -Path Env:LVIE_WORKTREE_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:LVIE_WORKTREE_ROOT = $script:savedWorktreeRoot
            }
        }
    }

    It 'uses deterministic repo-derived fallback when override and env are unset' {
        Remove-Item -Path Env:LVIE_WORKTREE_ROOT -ErrorAction SilentlyContinue

        $expected = Get-ExpectedRepoDerivedRoot -RepoRoot $script:repoRoot
        $resolved = & $script:ensureScript

        $resolved | Should -Be ([System.IO.Path]::GetFullPath($expected))
        (Test-Path -Path $resolved -PathType Container) | Should -BeTrue
    }

    It 'removes hardcoded C:\\dev/C:\\w fallback from Ensure-WorktreeRoot' {
        $content = Get-Content -Path $script:ensureScript -Raw
        $content | Should -Not -Match 'C:\\\\dev'
        $content | Should -Not -Match 'C:\\\\w'
    }

    It 'removes hardcoded C:\\dev fallback from RunnerLock lock root resolution' {
        $content = Get-Content -Path $script:runnerLockScript -Raw
        $content | Should -Not -Match 'C:\\\\dev'
        $content | Should -Match 'Ensure-WorktreeRoot\.ps1'
    }
}
