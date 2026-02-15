$ErrorActionPreference = 'Stop'

Describe 'LabVIEW 2020 canonical migration contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path

        $script:activeContractFiles = @(
            '.github/workflows/ci.yml',
            '.github/workflows/ci-composite.yml',
            'Tooling/support/LabVIEWStage.ps1',
            'Tooling/container-parity/runlabview-linux.sh',
            'Tooling/container-parity/runlabview-windows.ps1',
            'AGENTS.md',
            'README.md',
            'docs/ci-workflows.md',
            'docs/powershell-dependency-scripts.md',
            'docs/powershell-cli-github-action-instructions.md',
            'docs/ci/actions/runner-setup-guide.md',
            'docs/automated-setup.md',
            'docs/ci/troubleshooting-faq.md',
            'docs/ci/actions/development-mode-toggle.md',
            'docs/ci/actions/injecting-repo-org-to-vi-package.md'
        ) | ForEach-Object { Join-Path $script:repoRoot $_ }

        $script:historicalDocsAllowList = @(
            'docs/vip-prerelease-requirements-v1-acceptance.md',
            'docs/runner-cli-requirements-v5-acceptance.md',
            'docs/runner-cli-requirements-v4-to-v5-trace.md',
            'docs/ci-phase-tracker.md'
        ) | ForEach-Object { (Join-Path $script:repoRoot $_).ToLowerInvariant() }
    }

    It '.lvversion is pinned to 20.0' {
        $lvversionPath = Join-Path $script:repoRoot '.lvversion'
        (Test-Path -LiteralPath $lvversionPath -PathType Leaf) | Should -BeTrue

        $raw = (Get-Content -LiteralPath $lvversionPath -Raw).Trim()
        $raw | Should -Be '20.0'
    }

    It 'active workflow/script/docs surfaces do not reintroduce zip codex asset contract' {
        $matchList = @()
        foreach ($filePath in $script:activeContractFiles) {
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                continue
            }
            $matchList += Select-String -Path $filePath -Pattern 'lvie-codex-skill-layer\.zip' -SimpleMatch:$false
        }

        $matchList.Count | Should -Be 0
    }

    It 'active workflow/script/docs surfaces avoid legacy 2021/2026 canonical defaults' {
        $legacyPatterns = @(
            'LabVIEW 2021',
            '21\.0',
            'CONTAINER_PARITY_LABVIEW_VERSION=2026',
            'LabVIEW 2026\\',
            'LabVIEW-2026-64',
            '2026q1-(linux|windows)'
        )

        $matchList = @()
        foreach ($filePath in $script:activeContractFiles) {
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                continue
            }
            foreach ($pattern in $legacyPatterns) {
                $matchList += Select-String -Path $filePath -Pattern $pattern -SimpleMatch:$false
            }
        }

        $matchList.Count | Should -Be 0
    }

    It 'non-historical docs do not claim LabVIEW 2021 as canonical baseline' {
        $docRoot = Join-Path $script:repoRoot 'docs'
        $matchList = @()
        $docFiles = Get-ChildItem -Path $docRoot -Recurse -File -Filter *.md
        foreach ($doc in $docFiles) {
            if ($script:historicalDocsAllowList -contains $doc.FullName.ToLowerInvariant()) {
                continue
            }
            $matchList += Select-String -Path $doc.FullName -Pattern 'LabVIEW 2021|21\.0' -SimpleMatch:$false
        }

        $matchList.Count | Should -Be 0
    }

    It 'canonical guidance documents explicitly call out LabVIEW 2020 baseline' {
        $guidanceFiles = @(
            (Join-Path $script:repoRoot 'AGENTS.md'),
            (Join-Path $script:repoRoot 'docs/ci-workflows.md'),
            (Join-Path $script:repoRoot 'docs/ci/actions/runner-setup-guide.md')
        )
        foreach ($filePath in $guidanceFiles) {
            (Test-Path -LiteralPath $filePath -PathType Leaf) | Should -BeTrue
            $content = Get-Content -LiteralPath $filePath -Raw
            $content | Should -Match 'LabVIEW 2020 \(20\.0\)'
        }
    }
}
