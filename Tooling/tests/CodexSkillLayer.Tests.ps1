#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:toolingRoot = Split-Path -Parent $PSScriptRoot
    $script:supportScript = Join-Path $script:toolingRoot 'support/CodexSkillLayer.ps1'
    . $script:supportScript

    function script:New-MinimalLayerContent {
        param(
            [Parameter(Mandatory = $true)]
            [string]$VersionRoot,

            [Parameter(Mandatory = $true)]
            [string[]]$RequiredFiles,

            [Parameter(Mandatory = $true)]
            [string]$License
        )

        foreach ($relative in $RequiredFiles) {
            $targetPath = Join-Path $VersionRoot $relative
            $parent = Split-Path -Parent $targetPath
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -Path $parent -PathType Container)) {
                New-Item -Path $parent -ItemType Directory -Force | Out-Null
            }

            if ($relative -eq 'manifest.json') {
                $manifest = [ordered]@{
                    name = 'lvie-codex-skill-layer'
                    version = '0.4.1'
                    license_spdx = $License
                }
                $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $targetPath -Encoding utf8
            } elseif ($relative.EndsWith('.json')) {
                Set-Content -Path $targetPath -Value '{}' -Encoding utf8
            } else {
                Set-Content -Path $targetPath -Value '# fixture' -Encoding utf8
            }
        }
    }
}

Describe 'Codex skill layer helpers' {
    It 'fails when layer root is missing' {
        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot (Join-Path $TestDrive 'missing-layer-root')
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Throw '*not installed*'
    }

    It 'fails when manifest license_spdx is missing or wrong' {
        $layerRoot = Join-Path $TestDrive 'layer'
        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot $layerRoot
        New-MinimalLayerContent -VersionRoot $state.VersionRoot -RequiredFiles @($state.Lock.required_files) -License 'MIT'
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Throw '*license mismatch*'
    }

    It 'succeeds when layer contains required files and 0BSD manifest' {
        $layerRoot = Join-Path $TestDrive 'layer-ok'
        $state = Get-CodexSkillLayerState -RepoRoot (Split-Path -Parent $script:toolingRoot) -LayerRoot $layerRoot
        New-MinimalLayerContent -VersionRoot $state.VersionRoot -RequiredFiles @($state.Lock.required_files) -License '0BSD'
        { Test-CodexSkillLayerVersionRoot -State $state } | Should -Not -Throw
    }

    It 'fails install when downloaded asset hash does not match lock' {
        $assetExe = Join-Path $TestDrive 'lvie-codex-skill-layer-installer.exe'
        Set-Content -Path $assetExe -Value 'dummy-installer' -Encoding ascii

        $state = [pscustomobject]@{
            RepoRoot = (Split-Path -Parent $script:toolingRoot)
            LockPath = Join-Path (Split-Path -Parent $script:toolingRoot) 'Tooling/codex-skill-layer.lock.json'
            Lock = [pscustomobject]@{
                repo = 'example/repo'
                tag = 'v1.0.0'
                asset_name = 'lvie-codex-skill-layer-installer.exe'
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
            VersionRoot = Join-Path (Join-Path $TestDrive 'installed') 'v1.0.0'
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
                Copy-Item -Path $assetExe -Destination (Join-Path $destDir $pattern) -Force
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
