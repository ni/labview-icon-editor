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

        $vipb = Join-Path $script:RepoRoot 'Tooling/deployment/seed.vipb'
        Test-Path -LiteralPath $vipb | Should -BeTrue

        [xml]$vipbXml = Get-Content -LiteralPath $vipb -Raw
        $settings = $vipbXml.SelectSingleNode('/VI_Package_Builder_Settings')
        if (-not $settings) { $settings = $vipbXml.SelectSingleNode('/Package') }
        $raw = ([string]$settings.Library_General_Settings.Package_LabVIEW_Version).Trim()
        $raw | Should -Match '(?i)LabVIEW'

        $match = [regex]::Match($raw, '(?i)LabVIEW\s*(?:>=\s*)?(?<ver>\d{2,4})(?:\.\d+)?')
        $match.Success | Should -BeTrue

        $expectedMaj = [int]$match.Groups['ver'].Value
        if ($expectedMaj -lt 100) { $expectedMaj += 2000 }

        $result | Should -Be $expectedMaj.ToString()
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

    Context "Normalization matrix" {
        $cases = @(
            @{ Id = 'case1'; Name = 'LabVIEW>=major.minor'; Value = 'LabVIEW>=23.5 (64-bit)'; Expected = '2023' },
            @{ Id = 'case2'; Name = 'LabVIEW label with SP'; Value = 'LabVIEW 2025 SP1 64-bit'; Expected = '2025' },
            @{ Id = 'case3'; Name = 'LabVIEW short year'; Value = 'LabVIEW 23.0'; Expected = '2023' },
            @{ Id = 'case4'; Name = 'LabVIEW>=short year'; Value = 'LabVIEW>=23.0'; Expected = '2023' }
        )

        It "normalizes <Name>" -TestCases $cases {
            param($Id, $Name, $Value, $Expected)

            $baseVipbPath = Join-Path $script:RepoRoot 'Tooling/deployment/seed.vipb'
            $baseVipbContent = Get-Content -LiteralPath $baseVipbPath -Raw

            $repo = Join-Path $script:TempRoot ("matrix-$Id")
            $vipbDir = Join-Path $repo 'Tooling/deployment'
            New-Item -ItemType Directory -Path $vipbDir -Force | Out-Null
            $vipbPath = Join-Path $vipbDir 'seed.vipb'
            $updated = [regex]::Replace(
                $baseVipbContent,
                '<Package_LabVIEW_Version>.*?</Package_LabVIEW_Version>',
                ("<Package_LabVIEW_Version>{0}</Package_LabVIEW_Version>" -f $Value),
                [System.Text.RegularExpressions.RegexOptions]::Singleline
            )
            Set-Content -LiteralPath $vipbPath -Value $updated -Encoding utf8

            $result = & $script:Subject -RepositoryPath $repo
            $result | Should -Be $Expected
        }
    }

        It "fails when Package_LabVIEW_Version lacks the LabVIEW label" {
                $repo = Join-Path $script:TempRoot 'missing-label'
                $vipbDir = Join-Path $repo 'Tooling/deployment'
                New-Item -ItemType Directory -Path $vipbDir -Force | Out-Null
                $vipbPath = Join-Path $vipbDir 'seed.vipb'
                @"
<VI_Package_Builder_Settings>
    <Library_General_Settings>
        <Package_LabVIEW_Version>21.0 (64-bit)</Package_LabVIEW_Version>
    </Library_General_Settings>
</VI_Package_Builder_Settings>
"@ | Set-Content -LiteralPath $vipbPath -Encoding utf8

            try {
                & $script:Subject -RepositoryPath $repo
                throw "Expected get-package-lv-version.ps1 to fail when LabVIEW label is missing."
            }
            catch {
                $_.Exception.Message | Should -Match 'LabVIEW'
            }
        }

        It "fails when Package_LabVIEW_Version label lacks a numeric year" {
                $repo = Join-Path $script:TempRoot 'missing-numeric'
                $vipbDir = Join-Path $repo 'Tooling/deployment'
                New-Item -ItemType Directory -Path $vipbDir -Force | Out-Null
                $vipbPath = Join-Path $vipbDir 'seed.vipb'
                @"
<VI_Package_Builder_Settings>
    <Library_General_Settings>
        <Package_LabVIEW_Version>LabVIEW>=X.Y (64-bit)</Package_LabVIEW_Version>
    </Library_General_Settings>
</VI_Package_Builder_Settings>
"@ | Set-Content -LiteralPath $vipbPath -Encoding utf8

            try {
                & $script:Subject -RepositoryPath $repo
                throw "Expected get-package-lv-version.ps1 to fail when numeric version is missing."
            }
            catch {
                $_.Exception.Message | Should -Match 'numeric LabVIEW version'
            }
        }
}
