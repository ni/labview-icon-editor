#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:toolingRoot = Split-Path -Parent $PSScriptRoot
    $script:supportScript = Join-Path $script:toolingRoot 'support/CodexSkillLayer.ps1'
    $script:fixtureLayerRoot = Join-Path $script:toolingRoot 'tests/fixtures/codex-skill-layer'
    . $script:supportScript
}

Describe 'Codex skill layer helpers' {
    It 'fails when layer root is missing' {
        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot (Join-Path $TestDrive 'missing-layer-root')
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Throw '*not installed*'
    }

    It 'fails when manifest license_spdx is missing or wrong' {
        $layerRoot = Join-Path $TestDrive 'layer'
        $versionRoot = Join-Path $layerRoot 'v0.1.0'
        New-Item -Path (Join-Path $versionRoot 'ci-debt') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $versionRoot 'manifest.json') -Value '{"license_spdx":"MIT"}' -Encoding utf8
        Set-Content -Path (Join-Path $versionRoot 'LICENSE') -Value 'placeholder' -Encoding utf8
        Set-Content -Path (Join-Path $versionRoot 'ci-debt/Invoke-CiDebtAnalysis.ps1') -Value '# fixture' -Encoding utf8
        Set-Content -Path (Join-Path $versionRoot 'ci-debt/Test-CiDebtPolicyGate.ps1') -Value '# fixture' -Encoding utf8
        Set-Content -Path (Join-Path $versionRoot 'ci-debt/signatures.json') -Value '{"signatures":[]}' -Encoding utf8
        Set-Content -Path (Join-Path $versionRoot 'ci-debt/playbook.md') -Value '# fixture' -Encoding utf8
        New-Item -Path (Join-Path $versionRoot 'ci-debt/fixtures') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $versionRoot 'ci-debt/fixtures/run-21840801109.json') -Value '{}' -Encoding utf8

        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot $layerRoot
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Throw '*license mismatch*'
    }

    It 'succeeds when fixture layer contains required files and 0BSD manifest' {
        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot $script:fixtureLayerRoot
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Not -Throw
    }

    It 'fails install when downloaded asset hash does not match lock' {
        $assetSourceRoot = Join-Path $TestDrive 'asset-src'
        $assetVersionRoot = Join-Path $assetSourceRoot 'v0.1.0'
        New-Item -Path (Join-Path $assetVersionRoot 'ci-debt/fixtures') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $assetVersionRoot 'manifest.json') -Value '{"license_spdx":"0BSD"}' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'LICENSE') -Value '0BSD' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'ci-debt/Invoke-CiDebtAnalysis.ps1') -Value '# fixture' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'ci-debt/Test-CiDebtPolicyGate.ps1') -Value '# fixture' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'ci-debt/signatures.json') -Value '{"signatures":[{"id":"x","job":"x","containsAny":["x"]}]}' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'ci-debt/playbook.md') -Value '# fixture' -Encoding utf8
        Set-Content -Path (Join-Path $assetVersionRoot 'ci-debt/fixtures/run-21840801109.json') -Value '{}' -Encoding utf8

        $assetZip = Join-Path $TestDrive 'lvie-codex-skill-layer.zip'
        Compress-Archive -Path (Join-Path $assetVersionRoot '*') -DestinationPath $assetZip -Force

        $state = [pscustomobject]@{
            RepoRoot = (Split-Path -Parent $script:toolingRoot)
            LockPath = Join-Path (Split-Path -Parent $script:toolingRoot) 'Tooling/codex-skill-layer.lock.json'
            Lock = [pscustomobject]@{
                repo = 'example/repo'
                tag = 'v0.1.0'
                asset_name = 'lvie-codex-skill-layer.zip'
                sha256 = 'deadbeef'
                license_spdx = '0BSD'
                required_files = @(
                    'ci-debt/Invoke-CiDebtAnalysis.ps1',
                    'ci-debt/Test-CiDebtPolicyGate.ps1',
                    'ci-debt/signatures.json',
                    'ci-debt/playbook.md',
                    'ci-debt/fixtures/run-21840801109.json',
                    'manifest.json',
                    'LICENSE'
                )
            }
            LayerRoot = Join-Path $TestDrive 'installed'
            VersionRoot = Join-Path (Join-Path $TestDrive 'installed') 'v0.1.0'
        }

        function global:gh {
            param([Parameter(ValueFromRemainingArguments = $true)] [string[]]$Args)
            if ($Args[0] -eq 'release' -and $Args[1] -eq 'download') {
                $dirIndex = [Array]::IndexOf($Args, '--dir')
                $patternIndex = [Array]::IndexOf($Args, '--pattern')
                if ($dirIndex -lt 0 -or $patternIndex -lt 0) {
                    throw 'Missing --dir or --pattern in gh stub.'
                }
                $destDir = $Args[$dirIndex + 1]
                $pattern = $Args[$patternIndex + 1]
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                Copy-Item -Path $assetZip -Destination (Join-Path $destDir $pattern) -Force
                $global:LASTEXITCODE = 0
                return
            }

            throw ("Unexpected gh command in test stub: {0}" -f ($Args -join ' '))
        }

        try {
            { Install-CodexSkillLayerInternal -State $state -Force } | Should -Throw '*SHA256 mismatch*'
        } finally {
            Remove-Item Function:\global:gh -ErrorAction SilentlyContinue
        }
    }
}
