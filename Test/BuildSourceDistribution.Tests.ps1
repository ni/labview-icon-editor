$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Global:Get-HeadCommitInfo {
    param($RepositoryPath)
    return [pscustomobject]@{ Commit = 'head'; Author = 'head'; Date = (Get-Date).ToString('o') }
}

$global:BuildSourceDistributionScript = Join-Path $PSScriptRoot '../scripts/build-source-distribution/Build_Source_Distribution.ps1'

function Global:New-TempRepoFixture {
    param(
        [switch]$WithOverride,
        [switch]$EmptyDist
    )

    $root = Join-Path ([IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $null = New-Item -ItemType Directory -Path $root -Force

    # Minimal project + stub helpers consumed by the script
    Set-Content -LiteralPath (Join-Path $root 'lv_icon_editor.lvproj') -Value '<Project/>' -Encoding utf8
    $scriptsDir = Join-Path $root 'scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptsDir 'get-package-lv-version.ps1') -Value @'
param([string]$RepositoryPath)
'2025'
'@ -Encoding utf8
    Set-Content -LiteralPath (Join-Path $scriptsDir 'get-package-lv-bitness.ps1') -Value @'
param([string]$RepositoryPath)
'64'
'@ -Encoding utf8

    # Support files referenced during copy (keep warnings quiet)
    $support = @(
        'configs/vscode/task-schema.sample.json',
        'configs/vi-compare-run-request.sample.json',
        'configs/vi-compare-run-request.failure.json',
        'configs/vi-compare-run-request.disabled.json',
        'scripts/vi-compare/run-vi-history-suite-sd.ps1',
        'scripts/vi-compare/RunViCompareReplay.ps1'
    )
    foreach ($rel in $support) {
        $path = Join-Path $root $rel
        $dir = Split-Path -Parent $path
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath $path -Value '#' -Encoding utf8
    }

    # Icon API sources used for payload zip/hash
    $viLib = Join-Path $root 'vi.lib/LabVIEW Icon API'
    New-Item -ItemType Directory -Path $viLib -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $viLib 'api.txt') -Value 'icon-api' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $viLib 'api2.txt') -Value 'icon-api-extra' -Encoding utf8

    $plugins = Join-Path $root 'resource/plugins/nested'
    New-Item -ItemType Directory -Path $plugins -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $plugins 'plugin.txt') -Value 'plugin' -Encoding utf8

    $unitTests = Join-Path $root 'Test/Unit tests'
    New-Item -ItemType Directory -Path $unitTests -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $unitTests 'test.txt') -Value 'unit' -Encoding utf8

    # Dist root used post-build
    $distRoot = if ($WithOverride) { Join-Path $root 'custom/dist' } else { Join-Path $root 'builds/LabVIEWIconAPI' }
    New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
    if (-not $EmptyDist) {
        $distPlugins = Join-Path $distRoot 'resource/plugins/nested'
        New-Item -ItemType Directory -Path $distPlugins -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $distPlugins 'plugin.txt') -Value 'plugin-dist' -Encoding utf8
        $distApi = Join-Path $distRoot 'vi.lib/LabVIEW Icon API'
        New-Item -ItemType Directory -Path $distApi -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $distApi 'api.txt') -Value 'api-dist' -Encoding utf8
    }

    # Commit index covering files in the dist root
    $commitIndexPath = Join-Path $root 'builds/cache/mock-index.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $commitIndexPath) -Force | Out-Null
    $entries = @(
        @{ path = 'resource/plugins/nested/plugin.txt'; commit = 'c1'; author = 'dev'; date = '2024-01-01T00:00:00Z'; isContainer = $false },
        @{ path = 'vi.lib/LabVIEW Icon API/api.txt'; commit = 'c2'; author = 'dev'; date = '2024-01-02T00:00:00Z'; isContainer = $false },
        @{ path = 'vi.lib/LabVIEW Icon API/api2.txt'; commit = 'c3'; author = 'dev'; date = '2024-01-03T00:00:00Z'; isContainer = $false }
    )
    @{ entries = $entries; metadata = @{ generated = (Get-Date).ToString('o') } } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $commitIndexPath -Encoding utf8

    $gcliStub = Join-Path $root 'mock-g-cli.cmd'
    Set-Content -LiteralPath $gcliStub -Value '@echo mock g-cli' -Encoding Ascii
    return [pscustomobject]@{
        Root = $root
        DistRoot = $distRoot
        CommitIndex = $commitIndexPath
        GcliPath = $gcliStub
    }
}

Describe 'Build_Source_Distribution' {
    AfterEach {
        if ($script:repoRoot -and (Test-Path -LiteralPath $script:repoRoot)) {
            Remove-Item -LiteralPath $script:repoRoot -Recurse -Force -ErrorAction SilentlyContinue
            $script:repoRoot = $null
        }
        Remove-Item -LiteralPath Env:LC_ALL -ErrorAction SilentlyContinue
    }

    It 'fails when repository path is missing' {
        try {
            & $global:BuildSourceDistributionScript -RepositoryPath 'C:/does/not/exist'
            throw 'Expected script to throw when repository path is invalid'
        } catch {
            $_.Exception.Message | Should -Match 'does not exist'
        }
    }

    It 'fails when g-cli cannot be resolved' {
        $fixture = New-TempRepoFixture
        $script:repoRoot = $fixture.Root

        try {
            & $global:BuildSourceDistributionScript -RepositoryPath $fixture.Root -GcliPath 'missing-g-cli' -CommitIndexPath $fixture.CommitIndex -SkipAssetIsolation
            throw 'Expected script to throw when g-cli is missing'
        } catch {
            $_.Exception.Message | Should -Match 'g-cli is required'
        }
    }

    It 'invokes g-cli with the expected build spec and arguments' {
        $fixture = New-TempRepoFixture
        $script:repoRoot = $fixture.Root
        $global:capturedStartProcessCalls = @()
        Mock -CommandName Start-Process -MockWith {
            param($FilePath, $ArgumentList, $PassThru, $NoNewWindow)
            $global:capturedStartProcessCalls += [pscustomobject]@{
                FilePath     = $FilePath
                ArgumentList = @($ArgumentList)
            }
            [pscustomobject]@{ Id = 42; ExitCode = 0 }
        }
        Mock -CommandName Wait-Process -MockWith { param($Id) }

        $null = & $global:BuildSourceDistributionScript -RepositoryPath $fixture.Root -CommitIndexPath $fixture.CommitIndex -SkipAssetIsolation -GcliPath $fixture.GcliPath

        $global:capturedStartProcessCalls | ForEach-Object {
            Write-Host "Captured Start-Process: $($_.FilePath) -> $($_.ArgumentList -join ',')"
        }

        $gcliCall = $global:capturedStartProcessCalls |
            Where-Object { $_.FilePath -eq $fixture.GcliPath } |
            Select-Object -First 1
        $gcliCall | Should -Not -BeNullOrEmpty
        $projectPath = Join-Path $fixture.Root 'lv_icon_editor.lvproj'
        $gcliCall.ArgumentList | Should -Contain '-b'
        $gcliCall.ArgumentList | Should -Contain 'LabVIEWIconAPI'
        $gcliCall.ArgumentList | Should -Contain 'lvbuildspec'
        $gcliCall.ArgumentList | Should -Contain '-p'
        $gcliCall.ArgumentList | Should -Contain $projectPath
    }

    It 'writes manifest JSON/CSV with commit metadata for nested files' {
        $fixture = New-TempRepoFixture
        $script:repoRoot = $fixture.Root

        Mock -CommandName Start-Process -MockWith { [pscustomobject]@{ Id = 7; ExitCode = 0 } }
        Mock -CommandName Wait-Process -MockWith { param($Id) }
        Mock -CommandName Get-HeadCommitInfo -MockWith { return [pscustomobject]@{ Commit='head'; Author='head'; Date='2024-01-03' } }

        $null = & $global:BuildSourceDistributionScript -RepositoryPath $fixture.Root -CommitIndexPath $fixture.CommitIndex -SkipAssetIsolation -GcliPath $fixture.GcliPath

        $manifestPath = Join-Path $fixture.DistRoot 'manifest.json'
        $csvPath = Join-Path $fixture.DistRoot 'manifest.csv'
        Test-Path $manifestPath | Should -BeTrue
        Test-Path $csvPath | Should -BeTrue

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $plugin = $manifest | Where-Object { $_.path -eq 'resource/plugins/nested/plugin.txt' }
        $api = $manifest | Where-Object { $_.path -eq 'vi.lib/LabVIEW Icon API/api.txt' }
        $plugin.commit_source | Should -Be 'index'
        $plugin.last_commit | Should -Be 'c1'
        $api.commit_source | Should -Be 'index'
        $api.last_commit | Should -Be 'c2'
        $manifest.Count | Should -Be 2

        (Get-Content -LiteralPath $csvPath) -join '' | Should -Match 'resource/plugins/nested/plugin.txt'
    }

    It 'honors OverrideOutputRoot and writes artifacts under the override path' {
        $fixture = New-TempRepoFixture -WithOverride
        $script:repoRoot = $fixture.Root

        Mock -CommandName Start-Process -MockWith { [pscustomobject]@{ Id = 9; ExitCode = 0 } }
        Mock -CommandName Wait-Process -MockWith { param($Id) }

        $null = & $global:BuildSourceDistributionScript -RepositoryPath $fixture.Root -CommitIndexPath $fixture.CommitIndex -SkipAssetIsolation -GcliPath $fixture.GcliPath -OverrideOutputRoot $fixture.DistRoot

        Test-Path (Join-Path $fixture.DistRoot 'manifest.json') | Should -BeTrue
        Test-Path (Join-Path $fixture.DistRoot 'manifest.csv') | Should -BeTrue
    }
}
