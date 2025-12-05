<#
.SYNOPSIS
    Pester coverage for Build_Source_Distribution.ps1 with mocked g-cli invocations.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Build_Source_Distribution.ps1'

if (-not (Get-Command -Name robocopy -ErrorAction SilentlyContinue)) {
    function global:robocopy { param($Source, $Dest) }
}

function global:Ensure-TestDrives {
    if (-not (Get-PSDrive -Name C -ErrorAction SilentlyContinue)) {
        try { New-PSDrive -Name C -PSProvider FileSystem -Root '/mnt/c' -ErrorAction Stop | Out-Null } catch { }
    }
}

function global:New-TestRepo {
    param([string]$Name)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("bsd-test-{0}-{1}" -f $Name, [System.Guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $scriptsDir = Join-Path $root 'scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptsDir 'get-package-lv-version.ps1') -Value "param([string]`$RepositoryPath)`n'2025'" -Encoding ascii
    Set-Content -LiteralPath (Join-Path $scriptsDir 'get-package-lv-bitness.ps1') -Value "param([string]`$RepositoryPath)`n'64'" -Encoding ascii
    New-Item -ItemType Directory -Path (Join-Path $scriptsDir 'close-labview') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptsDir 'close-labview/Close_LabVIEW.ps1') -Value "param()" -Encoding ascii

    foreach ($rel in @(
        'configs/vscode',
        'configs',
        'scripts/vi-compare'
    )) {
        New-Item -ItemType Directory -Path (Join-Path $root $rel) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $root 'configs/vscode/task-schema.sample.json') -Value '{}' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'configs/vi-compare-run-request.sample.json') -Value '{}' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'configs/vi-compare-run-request.failure.json') -Value '{}' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'configs/vi-compare-run-request.disabled.json') -Value '{}' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'scripts/vi-compare/run-vi-history-suite-sd.ps1') -Value "param()" -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'scripts/vi-compare/RunViCompareReplay.ps1') -Value "param()" -Encoding ascii

    New-Item -ItemType Directory -Path (Join-Path $root 'vi.lib/LabVIEW Icon API/Nested') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'vi.lib/LabVIEW Icon API/Nested/payload.txt') -Value 'payload' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $root 'vi.lib/LabVIEW Icon API/extra.txt') -Value 'payload2' -Encoding ascii
    New-Item -ItemType Directory -Path (Join-Path $root 'resource/plugins/deep') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'resource/plugins/deep/addin.txt') -Value 'plugin' -Encoding ascii
    New-Item -ItemType Directory -Path (Join-Path $root 'Test/Unit tests') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'Test/Unit tests/sample.txt') -Value 'test' -Encoding ascii

    $distRoot = Join-Path $root 'builds/LabVIEWIconAPI'
    New-Item -ItemType Directory -Path (Join-Path $distRoot 'vi.lib/LabVIEW Icon API/Nested') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $distRoot 'vi.lib/LabVIEW Icon API/Nested/inner.txt') -Value 'built' -Encoding ascii
    New-Item -ItemType Directory -Path (Join-Path $distRoot 'resource/plugins/sub') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $distRoot 'resource/plugins/sub/tool.vi') -Value 'tool' -Encoding ascii

    New-Item -ItemType Directory -Path (Join-Path $root 'builds/cache') -Force | Out-Null
    $commitIndex = @{
        entries = @(
            @{
                path       = 'vi.lib/LabVIEW Icon API/Nested/inner.txt'
                commit     = 'abc123'
                author     = 'tester'
                date       = '2024-01-01'
                isContainer= $false
            },
            @{
                path       = 'resource/plugins/sub/tool.vi'
                commit     = 'def456'
                author     = 'tester'
                date       = '2024-01-02'
                isContainer= $false
            }
        )
        metadata = @{ head = 'abc123' }
    }
    ($commitIndex | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath (Join-Path $root 'builds/cache/commit-index.json') -Encoding ascii

    Set-Content -LiteralPath (Join-Path $root 'lv_icon_editor.lvproj') -Value '<Project/>' -Encoding ascii

    return @{
        Root     = $root
        DistRoot = $distRoot
    }
}

Describe 'Build_Source_Distribution.ps1' {
    Context 'parameter validation' {
        It 'requires RepositoryPath and g-cli presence' {
            $sut = Join-Path $PSScriptRoot 'Build_Source_Distribution.ps1'
            Ensure-TestDrives
            $repo = New-TestRepo -Name 'nogcli'
            { & $sut -RepositoryPath $repo.Root -Package_LabVIEW_Version 2025 -SupportedBitness 64 -SkipAssetIsolation -GcliPath 'nonexistent-g-cli.exe' } | Should -Throw
            { & $sut -RepositoryPath (Join-Path $repo.Root 'missing') -Package_LabVIEW_Version 2025 -SupportedBitness 64 -SkipAssetIsolation -GcliPath 'pwsh' } | Should -Throw

            Remove-Item -LiteralPath $repo.Root -Recurse -Force
        }
    }

    Context 'g-cli invocation and manifest' {
        It 'invokes g-cli with LabVIEWIconAPI build spec and emits commit metadata for nested payloads' {
            $sut = Join-Path $PSScriptRoot 'Build_Source_Distribution.ps1'
            Ensure-TestDrives
            $repo = New-TestRepo -Name 'cli-manifest'
            $global:capturedArgs = $null
            Mock -CommandName Join-Path -ParameterFilter { $Path -like 'C:\\Program Files\\National Instruments*' } -MockWith {
                return "/tmp/$ChildPath"
            }
            Mock -CommandName Start-Process -MockWith {
                param($FilePath, $ArgumentList, $PassThru, $NoNewWindow)
                $script:LASTEXITCODE = 0
                $global:LASTEXITCODE = 0
                $global:capturedArgs = $ArgumentList
                [pscustomobject]@{ Id = 9999; ExitCode = 0 }
            }
            Mock -CommandName Wait-Process -MockWith {
                param($Id)
            }
            Mock -CommandName Compress-Archive -MockWith {
                param($Path, $DestinationPath, [switch]$Force)
                New-Item -ItemType File -Path $DestinationPath -Force | Out-Null
            }
            $global:robocopyCalls = @()
            Set-Item -Path Function:global:robocopy -Value {
                param($Source, $Dest, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
                $global:LASTEXITCODE = 0
                $global:robocopyCalls += ,@($args)
            }

            & $sut -RepositoryPath $repo.Root -Package_LabVIEW_Version 2025 -SupportedBitness 64 -SkipAssetIsolation -GcliPath 'pwsh' | Out-Null

            $localCapturedArgs = $global:capturedArgs
            $localCapturedArgs | Should -Not -BeNullOrEmpty
            $joinedArgs = ($localCapturedArgs -join ' ')
            $joinedArgs | Should -Match '--lv-ver\s+2025'
            $joinedArgs | Should -Match '--arch\s+64'
            $joinedArgs | Should -Match '-b\s+LabVIEWIconAPI'

            $manifestPath = Join-Path $repo.DistRoot 'manifest.json'
            Test-Path $manifestPath | Should -BeTrue
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $entry = $manifest | Where-Object { $_.path -eq 'vi.lib/LabVIEW Icon API/Nested/inner.txt' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.last_commit | Should -Be 'abc123'
            $entry.commit_source | Should -Be 'index'

            $csvPath = Join-Path $repo.DistRoot 'manifest.csv'
            Test-Path $csvPath | Should -BeTrue
            (Get-Content -LiteralPath $csvPath -Raw) | Should -Match 'vi.lib/LabVIEW Icon API/Nested/inner.txt'

            Remove-Item -LiteralPath $repo.Root -Recurse -Force
        }
    }

    Context 'OverrideOutputRoot and isolated mirror handling' {
        It 'honors override output paths and mirrors to builds-isolated' {
            $sut = Join-Path $PSScriptRoot 'Build_Source_Distribution.ps1'
            Ensure-TestDrives
            $repo = New-TestRepo -Name 'override'
            $override = Join-Path $repo.Root 'custom-dist'
            New-Item -ItemType Directory -Path (Join-Path $override 'vi.lib/LabVIEW Icon API/Nested') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $override 'vi.lib/LabVIEW Icon API/Nested/inner.txt') -Value 'built' -Encoding ascii

            $robocopyCalls = @()
            Mock -CommandName Start-Process -MockWith {
                param($FilePath, $ArgumentList, $PassThru, $NoNewWindow)
                $global:LASTEXITCODE = 0
                [pscustomobject]@{ Id = 42; ExitCode = 0 }
            }
            Mock -CommandName Wait-Process -MockWith {
                param($Id)
            }
            Mock -CommandName Compress-Archive -MockWith {
                param($Path, $DestinationPath, [switch]$Force)
                New-Item -ItemType File -Path $DestinationPath -Force | Out-Null
            }
            Mock -CommandName Join-Path -ParameterFilter { $Path -like 'C:\\Program Files\\National Instruments*' } -MockWith {
                return "/tmp/$ChildPath"
            }
            $global:robocopyCalls = @()
            Set-Item -Path Function:global:robocopy -Value {
                param($Source, $Dest, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
                $global:LASTEXITCODE = 0
                $global:robocopyCalls += ,@($args)
            }

            & $sut -RepositoryPath $repo.Root -Package_LabVIEW_Version 2025 -SupportedBitness 64 -SkipAssetIsolation -OverrideOutputRoot $override -GcliPath 'pwsh' | Out-Null

            $overrideManifest = Join-Path $override 'manifest.json'
            Test-Path $overrideManifest | Should -BeTrue
            $manifestEntries = Get-Content -LiteralPath $overrideManifest -Raw | ConvertFrom-Json
            $manifestEntries.Count | Should -BeGreaterThan 0
            Test-Path (Join-Path $repo.Root 'builds/artifacts/labview-icon-api.zip') | Should -BeTrue

            Remove-Item -LiteralPath $repo.Root -Recurse -Force
        }
    }
}
