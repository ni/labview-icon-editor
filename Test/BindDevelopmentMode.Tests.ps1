$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "BindDevelopmentMode.ps1 JSON output and requirement coverage" {
    BeforeAll {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\.github\actions\bind-development-mode\BindDevelopmentMode.ps1')).Path
        $repoRoot = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'scripts') -Force | Out-Null
        # Provide a stub version script so bind helper can resolve LV version
        $versionScript = @"
param([string]`$RepositoryPath)
'2021'
"@
        Set-Content -LiteralPath (Join-Path $repoRoot 'scripts\get-package-lv-version.ps1') -Value $versionScript -Encoding UTF8
        # Minimal lvproj so expected path resolves to lvproj parent
        New-Item -ItemType File -Path (Join-Path $repoRoot 'lv_icon_editor.lvproj') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'Tooling\deployment') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $repoRoot 'Tooling\deployment\Create_LV_INI_Token.vi') -Force | Out-Null

        $script:IniPath = Join-Path $TestDrive 'LabVIEW.ini'
    }

    AfterEach {
        Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:TEST_LV_INI_PATH -ErrorAction SilentlyContinue
        Remove-Item function:g-cli -ErrorAction SilentlyContinue
    }

    It "emits JSON with required fields in status mode" {
        Set-Content -LiteralPath $IniPath -Value @("LocalHost.LibraryPaths1=$repoRoot")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $env:TEST_LV_INI_PATH = $IniPath
        $jsonOut = Join-Path $TestDrive 'dev-mode-bind.json'

        & $scriptPath -RepositoryPath $repoRoot -Mode status -Bitness 64 -JsonOutputPath $jsonOut
        $LASTEXITCODE | Should -Be 0

        Test-Path $jsonOut | Should -BeTrue
        $data = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $data | Should -Not -BeNullOrEmpty
        $data[0].bitness     | Should -Be '64'
        $data[0].expected_path | Should -Be $repoRoot
        $data[0].current_path  | Should -Be $repoRoot
        $data[0].post_path     | Should -Be $repoRoot
        $data[0].action      | Should -Be 'status'
        $data[0].status      | Should -Be 'success'
    }

    It "binds when packed libraries exist even if the token matches (dry run)" {
        $repoPacked = Join-Path $TestDrive 'repo-packed'
        New-Item -ItemType Directory -Path (Join-Path $repoPacked 'scripts') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repoPacked 'scripts\get-package-lv-version.ps1') -Value $versionScript -Encoding UTF8
        New-Item -ItemType File -Path (Join-Path $repoPacked 'lv_icon_editor.lvproj') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $repoPacked 'Tooling\deployment') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $repoPacked 'Tooling\deployment\Create_LV_INI_Token.vi') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $repoPacked 'resource\plugins') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $repoPacked 'resource\plugins\lv_icon.lvlibp') -Force | Out-Null

        $iniPathPacked = Join-Path $TestDrive 'LabVIEW_packed.ini'
        Set-Content -LiteralPath $iniPathPacked -Value @("LocalHost.LibraryPaths1=$repoPacked")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $env:TEST_LV_INI_PATH = $iniPathPacked
        $jsonOut = Join-Path $TestDrive 'dev-mode-bind-packed.json'

        function global:g-cli { param([Parameter(ValueFromRemainingArguments = $true)][object[]]$args) $global:LASTEXITCODE = 0 }
        Mock -CommandName Get-Command -MockWith { [pscustomobject]@{ Name = 'g-cli'; Source = 'mock://g-cli' } }

        & $scriptPath -RepositoryPath $repoPacked -Mode bind -Bitness 64 -DryRun -JsonOutputPath $jsonOut
        $LASTEXITCODE | Should -Be 0

        $data = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $data[0].status       | Should -Be 'dry-run'
        $data[0].action       | Should -Be 'bind'
        $data[0].current_path | Should -Be $repoPacked
        $data[0].message      | Should -Match 'Dry run'
    }

    It "fails unbind without Force when token points elsewhere and reports in JSON" {
        Set-Content -LiteralPath $IniPath -Value @("LocalHost.LibraryPaths1=C:\other\repo")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $env:TEST_LV_INI_PATH = $IniPath
        $jsonOut = Join-Path $TestDrive 'dev-mode-bind-fail.json'

        function global:g-cli { param([Parameter(ValueFromRemainingArguments = $true)][object[]]$args) $global:LASTEXITCODE = 0 }
        Mock -CommandName Get-Command -MockWith { [pscustomobject]@{ Name = 'g-cli'; Source = 'mock://g-cli' } }

        & $scriptPath -RepositoryPath $repoRoot -Mode unbind -Bitness 64 -JsonOutputPath $jsonOut
        $LASTEXITCODE | Should -Be 1

        $data = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $data[0].status  | Should -Be 'fail'
        $data[0].action  | Should -Be 'unbind'
        $data[0].message | Should -Match 'use -Force'
        $data[0].current_path | Should -Match 'other'
    }

    It "forces unbind to clear mismatched token and succeeds" {
        Set-Content -LiteralPath $IniPath -Value @("LocalHost.LibraryPaths1=C:\other\repo")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $env:TEST_LV_INI_PATH = $IniPath
        $jsonOut = Join-Path $TestDrive 'dev-mode-bind-force.json'

        function global:g-cli { param([Parameter(ValueFromRemainingArguments = $true)][object[]]$args) $global:LASTEXITCODE = 0 }
        Mock -CommandName Get-Command -MockWith { [pscustomobject]@{ Name = 'g-cli'; Source = 'mock://g-cli' } }

        & $scriptPath -RepositoryPath $repoRoot -Mode unbind -Bitness 64 -JsonOutputPath $jsonOut -Force
        $LASTEXITCODE | Should -Be 0

        $data = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $data[0].status | Should -Be 'success'
        $data[0].post_path | Should -Be ''
    }
}
