Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'telemetry-publish.ps1 (dry-run and formatting)' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
        Push-Location $repoRoot
        $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "telemetry-publish-tests-$(Get-Random)") -Force
        $hist = New-Item -ItemType Directory -Path (Join-Path $tmp 'history') -Force
        $curr = Join-Path $tmp 'summary.json'
        $man  = Join-Path $tmp 'manifest.json'
        # Force env for URL composition
        $env:GITHUB_SERVER_URL = 'https://github.com'
        $env:GITHUB_REPOSITORY = 'LabVIEW-Community-CI-CD/x-cli'
    }
    AfterAll {
        Pop-Location
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    }

    It 'composes message with interpolation (braces-safe) and establishes baseline' {
        # Write manifest with commit containing braces to exercise interpolation safety
        $manifestObj = @{ schema = 'pipeline.manifest/v1'; run = @{ workflow='ci.yml'; run_id='12345'; commit='dead{beef}'; ts='2025-01-01T00:00:00Z' } }
        $manifestObj | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8NoBOM -FilePath $man
        # Write a current summary
        $summary = @{
            pass = 10; fail = 1; skipped = 2; duration_seconds = 3.14;
            total = 13;
            by_category = @{ unit = 8; integration = 5 }
        } | ConvertTo-Json -Depth 4
        $summary | Out-File -Encoding utf8NoBOM -FilePath $curr

        $ps1 = 'scripts/telemetry-publish.ps1'
        $out = & pwsh -NoProfile -File $ps1 -Current $curr -Discord 'http://localhost:1' -HistoryDir $hist -Manifest $man -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'X-CLI CI Summary'
        ($out -join "`n") | Should -Match '\*\*run:\*\* 12345   \*\*commit:\*\* dead\{beef\}'
        Test-Path (Join-Path $hist 'summary-latest.json') | Should -BeTrue
        Test-Path (Join-Path $hist 'diff-latest.json')    | Should -BeTrue
        ((Get-ChildItem -LiteralPath $hist -Filter 'summary-*.json' | Where-Object { $_.Name -ne 'summary-latest.json' }).Count) | Should -Be 1
        ((Get-ChildItem -LiteralPath $hist -Filter 'diff-*.json'    | Where-Object { $_.Name -ne 'diff-latest.json' }).Count)    | Should -Be 1
    }

    It 'produces comparison with deltas on subsequent run' {
        # Update summary to trigger deltas
        $summary2 = @{
            pass = 11; fail = 1; skipped = 2; duration_seconds = 4.14; total = 14;
            by_category = @{ unit = 9; integration = 5 }
        } | ConvertTo-Json -Depth 4
        $curr | Out-Null
        $summary2 | Out-File -Encoding utf8NoBOM -FilePath $curr -Force

        $ps1 = 'scripts/telemetry-publish.ps1'
        $out = & pwsh -NoProfile -File $ps1 -Current $curr -Discord 'http://localhost:1' -HistoryDir $hist -Manifest $man -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'Comparison vs previous'
        ($out -join "`n") | Should -Match 'pass: 11 \(Δ 1\)'
        Test-Path (Join-Path $hist 'summary-latest.json') | Should -BeTrue
        Test-Path (Join-Path $hist 'diff-latest.json')    | Should -BeTrue
    }
}

Describe 'telemetry-publish.ps1 (Discord error handling)' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
        Push-Location $repoRoot
        $tmp2 = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "telemetry-publish-tests-err-$(Get-Random)") -Force
        $hist2 = New-Item -ItemType Directory -Path (Join-Path $tmp2 'history') -Force
        $curr2 = Join-Path $tmp2 'summary.json'
        $man2  = Join-Path $tmp2 'manifest.json'
        @{ schema='pipeline.manifest/v1'; run=@{ workflow='ci.yml'; run_id='999'; commit='abc'; ts='2025-01-01T00:00:00Z' } } | ConvertTo-Json -Depth 4 | 
            Out-File -Encoding utf8NoBOM -FilePath $man2
        @{ pass = 1; fail = 0; skipped = 0; duration_seconds = 0.1; total = 1 } | ConvertTo-Json | 
            Out-File -Encoding utf8NoBOM -FilePath $curr2
    }
    AfterAll {
        Pop-Location
        if (Test-Path $tmp2) { Remove-Item -Recurse -Force $tmp2 }
    }

    It 'catches Discord post errors and suggests remediation' {
        $ps1 = 'scripts/telemetry-publish.ps1'
        # Use an invalid local endpoint to force a fast failure without external network
        $out = & pwsh -NoProfile -File $ps1 -Current $curr2 -Discord 'http://localhost:1' -HistoryDir $hist2 -Manifest $man2 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'Failed to post to Discord webhook'
        ($out -join "`n") | Should -Match 'Remediation:'
        # History still saved
        Test-Path (Join-Path $hist2 'summary-latest.json') | Should -BeTrue
        Test-Path (Join-Path $hist2 'diff-latest.json')    | Should -BeTrue
    }

    It 'falls back to DryRun when Discord secret is missing' {
        $ps1 = 'scripts/telemetry-publish.ps1'
        $out = & pwsh -NoProfile -File $ps1 -Current $curr2 -Discord '' -HistoryDir $hist2 -Manifest $man2 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'Discord webhook URL not set; falling back to dry-run'
        ($out -join "`n") | Should -Match 'Dry-run: not posting to Discord'
        # History still saved
        Test-Path (Join-Path $hist2 'summary-latest.json') | Should -BeTrue
        Test-Path (Join-Path $hist2 'diff-latest.json')    | Should -BeTrue
    }
}

Describe 'telemetry-publish.ps1 (attachment & diagnostics, dry-run)' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
        Push-Location $repoRoot
        $tmp3 = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "telemetry-publish-tests-attach-$(Get-Random)") -Force
        $hist3 = New-Item -ItemType Directory -Path (Join-Path $tmp3 'history') -Force
        $curr3 = Join-Path $tmp3 'summary.json'
        $man3  = Join-Path $tmp3 'manifest.json'
        @{ schema='pipeline.manifest/v1'; run=@{ workflow='ci.yml'; run_id='777'; commit='xyz'; ts='2025-01-01T00:00:00Z' } } | ConvertTo-Json -Depth 4 |
            Out-File -Encoding utf8NoBOM -FilePath $man3
        # Create an oversized summary to force attachment/diagnostics; 3000+ chars
        $big = 'A' * 2500 + "`n" + ('B' * 600)
        @{ pass = 1; fail = 0; skipped = 0; duration_seconds = 0.1; total = 1; note = $big } | ConvertTo-Json -Depth 4 |
            Out-File -Encoding utf8NoBOM -FilePath $curr3
    }
    AfterAll {
        Pop-Location
        if (Test-Path $tmp3) { Remove-Item -Recurse -Force $tmp3 }
    }
    It 'emits attachment dry-run notice, chunk diagnostics, and comment.md' {
        $ps1 = 'scripts/telemetry-publish.ps1'
        $comment = Join-Path $hist3 'comment.md'
        $out = & pwsh -NoProfile -File $ps1 -Current $curr3 -Discord '' -HistoryDir $hist3 -Manifest $man3 -PreferAttachment -EmitChunkDiagnostics -CommentPath $comment 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'Dry-run/attachment: would upload file telemetry-summary.txt'
        ($out -join "`n") | Should -Match 'CHUNK_DIAGNOSTICS:'
        $diagLatest = Join-Path $hist3 'chunk-diagnostics-latest.json'
        Test-Path $diagLatest | Should -BeTrue
        $diag = Get-Content -Raw -Path $diagLatest | ConvertFrom-Json
        $diag.mode | Should -Be 'dry-run'
        $diag.strategy | Should -Be 'attachment'
        $diag.attachment | Should -BeTrue
        [int]$diag.chunks | Should -Be 1
        # comment.md exists and includes summary
        Test-Path $comment | Should -BeTrue
        ($content = Get-Content -Raw -Path $comment)
        $content | Should -Match '# X-CLI CI Summary'
        $content | Should -Match '```'
        $content | Should -Match 'Chunk diagnostics'
    }
}
