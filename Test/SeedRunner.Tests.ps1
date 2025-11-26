# Seed runner wiring tests (docker commands mocked)

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

function New-MockDockerExecutable {
    param(
        [string]$BinDir,
        [string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }

    $script = @"
#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromRemainingArguments = \$true)]
    \$Args
)

\$log = '$LogPath'
if (-not (Test-Path -LiteralPath \$log)) { New-Item -ItemType File -Path \$log -Force | Out-Null }
Add-Content -LiteralPath \$log -Value (\$Args -join ' ')

if ((\$Args.Count -gt 0) -and \$Args[0] -eq 'buildx' -and \$env:MOCK_BUILDX_THROW -eq '1') {
    throw 'buildx missing'
}

exit 0
"@

    $dockerPath = Join-Path $BinDir 'docker'
    Set-Content -LiteralPath $dockerPath -Value $script -Encoding UTF8
    if (-not $IsWindows) {
        chmod +x $dockerPath
    }

    return $dockerPath
}

Describe "run-seed-runner.ps1" {
    BeforeAll {
        $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:ScriptPath = Join-Path $RepoRoot 'scripts/run-seed-runner.ps1'

        $script:TempBin = Join-Path ([System.IO.Path]::GetTempPath()) ("seedrunner-mocks-{0}" -f ([guid]::NewGuid().ToString('N')))
        $script:LogPath = Join-Path $TempBin 'docker.log'
        $script:OriginalPath = $env:PATH
        New-MockDockerExecutable -BinDir $TempBin -LogPath $LogPath | Out-Null
        $env:PATH = "$TempBin$([IO.Path]::PathSeparator)$env:PATH"
    }

    AfterEach {
        # reset env flags between tests
        Remove-Item env:MOCK_BUILDX_THROW -ErrorAction SilentlyContinue
        Remove-Item env:SEED_OFFLINE -ErrorAction SilentlyContinue
        Remove-Item env:SKIP_SEED_BUILD -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $LogPath) { Clear-Content -LiteralPath $LogPath }
    }

    AfterAll {
        $env:PATH = $script:OriginalPath
        if (Test-Path -LiteralPath $TempBin) {
            Remove-Item -LiteralPath $TempBin -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "uses buildx compose flow when buildx is available" {
        Remove-Item env:MOCK_BUILDX_THROW -ErrorAction SilentlyContinue
        & $script:ScriptPath
        $LASTEXITCODE | Should -Be 0

        $lines = Get-Content -LiteralPath $LogPath
        $lines | Should -Contain 'buildx version'
        ($lines -join ' ') | Should -Match 'compose .* build .*seed-runner'
        ($lines -join ' ') | Should -Match 'compose .* run .* --rm .*seed-runner'
    }

    It "falls back to docker build and compose --no-build when buildx is unavailable" {
        $env:MOCK_BUILDX_THROW = '1'
        & $script:ScriptPath
        $LASTEXITCODE | Should -Be 0

        $lines = Get-Content -LiteralPath $LogPath
        $lines | Should -Contain 'buildx version'
        ($lines -join ' ') | Should -Match 'build -f .*Dockerfile .* -t seed-runner:latest'
        ($lines -join ' ') | Should -Match 'compose .* run .* --no-build .*seed-runner'
    }

    It "passes SEED_OFFLINE into compose run environment" {
        $env:SEED_OFFLINE = '1'
        & $script:ScriptPath
        $LASTEXITCODE | Should -Be 0

        $lines = Get-Content -LiteralPath $LogPath
        ($lines -join ' ') | Should -Match '-e SEED_OFFLINE=1'
    }
}
