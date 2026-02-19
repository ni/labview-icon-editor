#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:ResolverScript = Join-Path $Script:ToolingRoot 'Resolve-GitHubRepo.ps1'
    $Script:CiDebtScript = Join-Path $Script:ToolingRoot 'Invoke-CiDebtAnalysis.ps1'
    $Script:FixturePath = Join-Path $Script:ToolingRoot 'tests/fixtures/ci-debt/run-21840801109.json'
    $Script:LayerRoot = Join-Path $Script:ToolingRoot 'tests/fixtures/codex-skill-layer'
    $Script:OriginalLayerRoot = $env:LVIE_CODEX_SKILL_LAYER_ROOT
    $env:LVIE_CODEX_SKILL_LAYER_ROOT = $Script:LayerRoot

    . $Script:CiDebtScript
}

AfterAll {
    if ($null -eq $Script:OriginalLayerRoot) {
        Remove-Item Env:LVIE_CODEX_SKILL_LAYER_ROOT -ErrorAction SilentlyContinue
    } else {
        $env:LVIE_CODEX_SKILL_LAYER_ROOT = $Script:OriginalLayerRoot
    }
}

Describe 'Resolve-GitHubRepo' {
    It 'resolves owner/name from origin when GH_REPO is not set' {
        $repoPath = Join-Path $TestDrive 'repo-origin'
        New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
        git -C $repoPath init | Out-Null
        git -C $repoPath remote add origin https://github.com/example-owner/example-repo.git

        $oldGhRepo = $env:GH_REPO
        try {
            Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            $resolved = & $Script:ResolverScript -RepoRoot $repoPath
        } finally {
            if ($null -eq $oldGhRepo) {
                Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            } else {
                $env:GH_REPO = $oldGhRepo
            }
        }

        $resolved.Trim() | Should -Be 'example-owner/example-repo'
    }

    It 'prefers GH_REPO override over origin' {
        $repoPath = Join-Path $TestDrive 'repo-override'
        New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
        git -C $repoPath init | Out-Null
        git -C $repoPath remote add origin https://github.com/example-owner/example-repo.git

        $oldGhRepo = $env:GH_REPO
        try {
            $env:GH_REPO = 'override-owner/override-repo'
            $resolved = & $Script:ResolverScript -RepoRoot $repoPath
        } finally {
            if ($null -eq $oldGhRepo) {
                Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            } else {
                $env:GH_REPO = $oldGhRepo
            }
        }

        $resolved.Trim() | Should -Be 'override-owner/override-repo'
    }

    It 'fails when origin cannot be parsed to owner/name' {
        $repoPath = Join-Path $TestDrive 'repo-unparseable'
        New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
        git -C $repoPath init | Out-Null
        git -C $repoPath remote add origin https://example.com/not-github.git

        $oldGhRepo = $env:GH_REPO
        try {
            Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            { & $Script:ResolverScript -RepoRoot $repoPath } | Should -Throw '*was not in owner/name or GitHub URL format*'
        } finally {
            if ($null -eq $oldGhRepo) {
                Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            } else {
                $env:GH_REPO = $oldGhRepo
            }
        }
    }
}

Describe 'Invoke-CiDebtAnalysis repository resolution' {
    It 'uses deterministic resolver path and not gh repo view fallback' {
        $scriptContent = Get-Content -Path $Script:CiDebtScript -Raw
        $scriptContent | Should -Match 'CodexSkillLayer\.ps1'
        $scriptContent | Should -Not -Match 'gh repo view --json nameWithOwner --jq \.nameWithOwner'
    }

    It 'respects GH_REPO override when Repo parameter is omitted' {
        $outJson = Join-Path $TestDrive 'analysis.json'
        $outMarkdown = Join-Path $TestDrive 'analysis.md'
        $oldGhRepo = $env:GH_REPO

        try {
            $env:GH_REPO = 'override-owner/override-repo'
            $result = Invoke-CiDebtAnalysis `
                -RunId 21840801109 `
                -FixturePath $Script:FixturePath `
                -OutJson $outJson `
                -OutMarkdown $outMarkdown
        } finally {
            if ($null -eq $oldGhRepo) {
                Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
            } else {
                $env:GH_REPO = $oldGhRepo
            }
        }

        $result.Repo | Should -Be 'override-owner/override-repo'
    }
}
