$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helperPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\log-stash\Write-LogStashEntry.ps1')).Path
$cleanupPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\log-stash\Cleanup-LogStash.ps1')).Path

Describe "Write-LogStashEntry" {
    It "creates a bundle with manifest and copied log/attachment" {
        $repo = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path (Join-Path $repo 'builds/logs') -Force | Out-Null
        $log = Join-Path $repo 'builds/logs/build-transcript.log'
        $attach = Join-Path $repo 'artifact.json'
        "hello" | Set-Content -LiteralPath $log -Encoding utf8
        '{"ok":true}' | Set-Content -LiteralPath $attach -Encoding utf8

        $start = Get-Date
        & $helperPath `
            -RepositoryPath $repo `
            -Category 'build' `
            -Label 'unit' `
            -LogPaths @($log) `
            -AttachmentPaths @($attach) `
            -Status 'success' `
            -Commit 'abc1234' `
            -LabVIEWVersion '2021' `
            -Bitness @('64') `
            -ProducerScript 'scripts/build/Build.ps1' `
            -ProducerTask 'Build.ps1' `
            -StartedAtUtc $start `
            -DurationMs 1200

        $manifestPath = Get-ChildItem -Path (Join-Path $repo 'builds/log-stash') -Recurse -Filter manifest.json | Select-Object -First 1
        $manifestPath | Should -Not -BeNullOrEmpty
        $manifest = Get-Content -LiteralPath $manifestPath.FullName -Raw | ConvertFrom-Json

        $manifest.type | Should -Be 'log'
        $manifest.category | Should -Be 'build'
        $manifest.commit | Should -Be 'abc1234'
        $manifest.labview_version | Should -Be '2021'
        $manifest.bitness | Should -Contain '64'
        $manifest.files.logs.Count | Should -Be 1
        $manifest.files.attachments.Count | Should -Be 1

        $copiedLog = Join-Path $repo $manifest.files.logs[0]
        Test-Path -LiteralPath $copiedLog | Should -BeTrue
        (Get-Content -LiteralPath $copiedLog -Raw) | Should -Be 'hello'

        $indexPath = Join-Path $repo 'builds/log-stash/index.json'
        Test-Path -LiteralPath $indexPath | Should -BeTrue
        $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
        $index[0].bundle | Should -Match 'builds\\log-stash\\abc1234\\build\\'
    }
}

Describe "Cleanup-LogStash" {
    It "removes old bundles per limits" {
        $repo = Join-Path $TestDrive 'repo'
        $stash = Join-Path $repo 'builds/log-stash/abc/build'
        $old = Join-Path $stash '20240101-old'
        $new = Join-Path $stash '20250101-new'
        New-Item -ItemType Directory -Path (Join-Path $old 'logs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $new 'logs') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $old 'manifest.json') -Value '{}' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $new 'manifest.json') -Value '{}' -Encoding utf8
        (Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-30)
        (Get-Item -LiteralPath $new).LastWriteTime = Get-Date

        & $cleanupPath -RepositoryPath $repo -MaxPerCategory 1 -MaxAgeDays 7

        Test-Path -LiteralPath $old | Should -BeFalse
        Test-Path -LiteralPath $new | Should -BeTrue
    }
}
