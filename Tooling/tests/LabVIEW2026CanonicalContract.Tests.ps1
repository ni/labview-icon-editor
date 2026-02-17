$ErrorActionPreference = 'Stop'

Describe 'LabVIEW 2026 canonical migration contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path

        $script:activeContractFiles = @(
            '.github/workflows/ci.yml',
            'Tooling/support/LabVIEWStage.ps1',
            'Tooling/container-parity/runlabview-linux.sh',
            'Tooling/container-parity/runlabview-windows.ps1',
            'AGENTS.md',
            'README.md',
            'INSTALL.md',
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

    It '.lvversion is pinned to 26.1' {
        $lvversionPath = Join-Path $script:repoRoot '.lvversion'
        (Test-Path -LiteralPath $lvversionPath -PathType Leaf) | Should -BeTrue

        $raw = (Get-Content -LiteralPath $lvversionPath -Raw).Trim()
        $raw | Should -Be '26.1'
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

    It 'canonical workflow/scripts do not use 2020 fallback defaults' {
        $fallbackChecks = @(
            @{
                Path    = Join-Path $script:repoRoot 'Tooling/support/LabVIEWStage.ps1'
                Pattern = "resolvedVersion = '2020'"
            },
            @{
                Path    = Join-Path $script:repoRoot 'Tooling/container-parity/runlabview-linux.sh'
                Pattern = 'LV_YEAR:-2020'
            },
            @{
                Path    = Join-Path $script:repoRoot 'Tooling/container-parity/runlabview-windows.ps1'
                Pattern = "'2020'"
            }
        )

        $matchList = @()
        foreach ($check in $fallbackChecks) {
            if (-not (Test-Path -LiteralPath $check.Path -PathType Leaf)) {
                continue
            }
            $matchList += Select-String -Path $check.Path -Pattern $check.Pattern -SimpleMatch:$true
        }

        $matchList.Count | Should -Be 0
    }

    It 'active workflows do not use temporary LV unit-test override env vars' {
        $workflowFiles = @(
            (Join-Path $script:repoRoot '.github/workflows/ci.yml')
        )

        $matchList = @()
        foreach ($filePath in $workflowFiles) {
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                continue
            }
            $matchList += Select-String -Path $filePath -Pattern 'LVIE_UNIT_TEST_TARGET_YEAR|LVIE_UNIT_TEST_TARGET_LVVERSION' -SimpleMatch:$false
        }

        $matchList.Count | Should -Be 0
    }

    It 'non-historical docs do not claim LabVIEW 2020/2021 as canonical baseline' {
        $docRoot = Join-Path $script:repoRoot 'docs'
        $matchList = @()
        $docFiles = Get-ChildItem -Path $docRoot -Recurse -File -Filter *.md
        foreach ($doc in $docFiles) {
            if ($script:historicalDocsAllowList -contains $doc.FullName.ToLowerInvariant()) {
                continue
            }

            $legacyMentions = @(Select-String -Path $doc.FullName -Pattern 'LabVIEW 2020 \(20\.0\)|LabVIEW 2021|21\.0' -SimpleMatch:$false)
            foreach ($mention in $legacyMentions) {
                $line = [string]$mention.Line
                $is2020Reference = $line -match 'LabVIEW 2020 \(20\.0\)'
                $allowedFormatContext = $is2020Reference -and ($line -match '(?i)source.*saved|saved.*format|file format')
                if (-not $allowedFormatContext) {
                    $matchList += $mention
                }
            }
        }

        $matchList.Count | Should -Be 0
    }

    It 'canonical guidance documents explicitly call out LabVIEW 2026 baseline' {
        $guidanceFiles = @(
            (Join-Path $script:repoRoot 'AGENTS.md'),
            (Join-Path $script:repoRoot 'docs/ci-workflows.md'),
            (Join-Path $script:repoRoot 'docs/ci/actions/runner-setup-guide.md')
        )
        foreach ($filePath in $guidanceFiles) {
            (Test-Path -LiteralPath $filePath -PathType Leaf) | Should -BeTrue
            $content = Get-Content -LiteralPath $filePath -Raw
            $content | Should -Match 'LabVIEW 2026 \(26\.1\)'
        }
    }
}

