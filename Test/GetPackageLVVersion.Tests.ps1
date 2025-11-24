$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "get-package-lv-version.ps1" {
    BeforeAll {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { $scriptPath = $PSScriptRoot }

        $repoRoot = $null
        if ($scriptPath) {
            $testDir = Split-Path -Parent $scriptPath
            $repoRoot = Split-Path -Parent $testDir
        }
        if (-not $repoRoot) {
            $repoRoot = (Get-Location).ProviderPath
        }

        $script:RepoRoot = $repoRoot
        $script:Subject = (Resolve-Path (Join-Path $repoRoot 'scripts/get-package-lv-version.ps1')).Path
        Test-Path -LiteralPath $script:Subject | Should -BeTrue

        $script:TempRoot = Join-Path $repoRoot 'Test/tmp/get-package-lv-version'
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:TempRoot -and (Test-Path $script:TempRoot)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
        }
    }

    It "returns the normalized LabVIEW version from the repository VIPB" {
        $result = & $script:Subject -RepositoryPath $script:RepoRoot
        $result | Should -Match '^\d{4}$'

        $vipb = Get-ChildItem -Path $script:RepoRoot -Filter *.vipb -File -Recurse | Select-Object -First 1
        $vipb | Should -Not -BeNullOrEmpty

        [xml]$vipbXml = Get-Content -LiteralPath $vipb.FullName -Raw
        $raw = [string]$vipbXml.VI_Package_Builder_Settings.Library_General_Settings.Package_LabVIEW_Version
        $raw | Should -Not -BeNullOrEmpty

        $match = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
        $match.Success | Should -BeTrue

        $expectedMaj = [int]($match.Groups['majmin'].Value.Split('.')[0])
        $expected = if ($expectedMaj -ge 20) { "20$expectedMaj" } else { $expectedMaj.ToString() }

        $result | Should -Be $expected
    }

    It "fails when the VIPB is missing VI_Package_Builder_Settings even if Package_LabVIEW_Version exists" {
        $badVipb = Join-Path $script:TempRoot 'missing-root.vipb'
        @"
<Broken>
  <Package_LabVIEW_Version>21.0 (64-bit)</Package_LabVIEW_Version>
</Broken>
"@ | Set-Content -LiteralPath $badVipb -Encoding utf8

        try {
            & $script:Subject -RepositoryPath $script:TempRoot
            throw "Expected get-package-lv-version.ps1 to throw on malformed VIPB."
        }
        catch {
            $_.Exception.Message | Should -Match 'VI_Package_Builder_Settings'
        }
    }
}
