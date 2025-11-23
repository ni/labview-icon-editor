$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VIPB LabVIEW version parsing" {
    It "detects Package_LabVIEW_Version and derives the 4-digit year" {
        $vipb = Get-ChildItem -Path $PSScriptRoot/.. -Filter *.vipb -File -Recurse | Select-Object -First 1
        $vipb | Should -Not -BeNullOrEmpty

        $text = Get-Content -LiteralPath $vipb.FullName -Raw
        $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
        $match.Success | Should -BeTrue

        $raw = $match.Groups['ver'].Value
        $raw | Should -Match '^\d{2}\.\d'

        $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
        $verMatch.Success | Should -BeTrue

        $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
        $derived = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }

        # Current VIPB targets LabVIEW 2021 (21.x) for dev-mode prep.
        $derived | Should -Be '2021'
    }
}

Describe "run-dev-mode.ps1" {
    $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\.github\actions\set-development-mode\run-dev-mode.ps1')).Path
    $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    It "fails fast and surfaces g-cli --help errors" {
        function global:g-cli { }
        Mock -CommandName Get-Command -MockWith { [pscustomobject]@{ Name = 'g-cli'; Source = 'mock://g-cli' } }
        Mock -CommandName g-cli -MockWith { $global:LASTEXITCODE = 99 }
        $ex = $null
        try {
            & $scriptPath -RepositoryPath $repoRoot
        } catch {
            $ex = $_
        }

        $ex | Should -Not -BeNullOrEmpty
        $ex.Exception.Message | Should -Match 'exit code 99|pipeline element'
        Remove-Item function:g-cli -ErrorAction SilentlyContinue
    }
}

Describe "AddTokenToLabVIEW guard" {
    It "removes stale double-rooted LocalHost.LibraryPaths entries and warns" {
        $helperPath = Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1'
        . $helperPath

        $iniPath = Join-Path $TestDrive 'LabVIEW.ini'
        $iniContent = @(
            'LocalHost.LibraryPaths1=C:\actions-runner\_work\actions-runner\_work\labview-icon-editor\labview-icon-editor',
            'LocalHost.LibraryPaths2=C:\valid\repo',
            'Other=keep'
        )
        Set-Content -LiteralPath $iniPath -Value $iniContent

        # Override resolver to point at our test ini
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))

        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '64' -RepositoryRoot 'C:\repo' } 3>&1

        $updated = Get-Content -LiteralPath $iniPath
        ($updated -join "`n") | Should -Not -Match 'actions-runner\\_work\\actions-runner\\_work'
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\valid\repo'
        $updated | Should -Contain 'Other=keep'
        $warnings | Where-Object { $_ -like '*Removed*LocalHost.LibraryPaths entries*' } | Should -Not -BeNullOrEmpty
    }
}

Describe "read-library-paths guidance" {
    It "warns when entries do not point to the current repo" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

        $iniPath = Join-Path $TestDrive 'LabVIEW.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=C:\some\other\path',
            ('LocalHost.LibraryPaths2={0}' -f (Join-Path $repoRoot 'other'))
        )

        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $warnings = & { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 -IniPath $iniPath 3>&1 } 2>$null
        Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        $warnings | Where-Object { $_ -like '*do not point to this repo*' } | Should -Not -BeNullOrEmpty
        $warnings | Where-Object { $_ -like '*Revert Dev Mode*Set Dev Mode*' } | Should -Not -BeNullOrEmpty
    }

    It "hard-stops on non-canonical ini path when overrides are not allowed" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW.ini'
        Set-Content -LiteralPath $iniPath -Value @('LocalHost.LibraryPaths1=C:\other')

        { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 -IniPath $iniPath } | Should -Throw
    }

    It "throws when FailOnMissing is set and no entries exist" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW_empty.ini'
        Set-Content -LiteralPath $iniPath -Value @("Some=thing")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        try {
            { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 -IniPath $iniPath -FailOnMissing } | Should -Throw
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "exits successfully when entries point to the repo" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW_repo.ini'
        Set-Content -LiteralPath $iniPath -Value @("LocalHost.LibraryPaths1=$repoRoot")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        try {
            { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 -IniPath $iniPath } | Should -Not -Throw
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "throws when canonical ini is missing" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 } | Should -Throw
    }

    It "emits hint text when missing entries and FailOnMissing is set" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW_missing.ini'
        Set-Content -LiteralPath $iniPath -Value @("Other=keep")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        try {
            { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 32 -IniPath $iniPath -FailOnMissing } | Should -Throw
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "ignores blank or malformed lines" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW_blank.ini'
        Set-Content -LiteralPath $iniPath -Value @("", "LocalHost.LibraryPaths1=$repoRoot", "nonsense")
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        try {
            { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 64 -IniPath $iniPath } | Should -Not -Throw
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "handles multiple repo entries without error" {
        $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\read-library-paths.ps1')).Path
        $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $iniPath = Join-Path $TestDrive 'LabVIEW_multi_repo.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            "LocalHost.LibraryPaths1=$repoRoot",
            "LocalHost.LibraryPaths2=$repoRoot"
        )
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        try {
            { & $scriptPath -RepositoryPath $repoRoot -SupportedBitness 32 -IniPath $iniPath } | Should -Not -Throw
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }
}

Describe "LocalhostLibraryPaths helpers" {
    BeforeAll {
        $helperPath = Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1'
        . $helperPath
    }

    It "deduplicates and removes repo and double-rooted entries" {
        $iniPath = Join-Path $TestDrive 'LabVIEW.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=C:\actions-runner\_work\actions-runner\_work\repo',
            'LocalHost.LibraryPaths2=C:\repo',
            'LocalHost.LibraryPaths3=C:\repo',
            'LocalHost.LibraryPaths4=C:\keepme',
            'Other=keep'
        )

        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '64' -RepositoryRoot 'C:\repo' } 3>&1

        $updated = Get-Content -LiteralPath $iniPath
        ($updated -join "`n") | Should -Not -Match 'actions-runner\\_work\\actions-runner\\_work'
        # Keep a single repo entry, drop duplicates
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\repo'
        ($updated -join "`n") | Should -Not -Match 'LocalHost.LibraryPaths3=C:\\repo'
        $updated | Should -Contain 'LocalHost.LibraryPaths4=C:\keepme'
        $warnings | Where-Object { $_ -like '*Removed*LocalHost.LibraryPaths entries*' } | Should -Not -BeNullOrEmpty
    }

    It "preserves unique non-repo entries" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_unique.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=C:\other1',
            'LocalHost.LibraryPaths2=C:\other2'
        )
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '32' -RepositoryRoot 'C:\repo' } 3>&1
        $updated = Get-Content -LiteralPath $iniPath
        $updated | Should -Contain 'LocalHost.LibraryPaths1=C:\other1'
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\other2'
        $warnings.Count | Should -Be 0
    }

    It "throws on non-canonical ini when overrides are disabled" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_noncanonical.ini'
        Set-Content -LiteralPath $iniPath -Value @('LocalHost.LibraryPaths1=C:\foo')
        Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
        $env:TEST_LV_INI_PATH = $iniPath
        try {
            # re-import to restore canonical Resolve-LVIniPath after prior overrides
            . (Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1')
            { Resolve-LVIniPath -LvVersion '2021' -Arch '64' } | Should -Throw
        }
        finally {
            Remove-Item Env:TEST_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "allows custom ini when overrides are enabled" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_custom.ini'
        Set-Content -LiteralPath $iniPath -Value @('LocalHost.LibraryPaths1=C:\foo')
        $env:ALLOW_NONCANONICAL_LV_INI_PATH = '1'
        $env:TEST_LV_INI_PATH = $iniPath
        try {
            . (Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1')
            $resolved = Resolve-LVIniPath -LvVersion '2021' -Arch '64'
            $resolved | Should -Be $iniPath
        }
        finally {
            Remove-Item Env:ALLOW_NONCANONICAL_LV_INI_PATH -ErrorAction SilentlyContinue
            Remove-Item Env:TEST_LV_INI_PATH -ErrorAction SilentlyContinue
        }
    }

    It "deduplicates identical non-repo entries" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_dupe.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=C:\other',
            'LocalHost.LibraryPaths2=C:\other',
            'LocalHost.LibraryPaths3=C:\keep'
        )
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '32' -RepositoryRoot 'C:\repo' } 3>&1
        $updated = Get-Content -LiteralPath $iniPath
        ($updated -join "`n") | Should -Match 'LocalHost.LibraryPaths1=C:\\other|LocalHost.LibraryPaths2=C:\\other'
        ($updated -join "`n") | Should -Not -Match 'LocalHost.LibraryPaths3=C:\\other'
        $updated | Should -Contain 'LocalHost.LibraryPaths3=C:\keep'
        $warnings | Where-Object { $_ -like '*Removed*LocalHost.LibraryPaths entries*' } | Should -Not -BeNullOrEmpty
    }

    It "ignores empty LocalHost lines when cleaning" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_empty_lines.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=',
            'LocalHost.LibraryPaths2= ',
            'LocalHost.LibraryPaths3=C:\keep'
        )
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '64' -RepositoryRoot 'C:\repo' } 3>&1
        $updated = Get-Content -LiteralPath $iniPath
        $updated | Should -Contain 'LocalHost.LibraryPaths3=C:\keep'
        $warnings | Where-Object { $_ -like '*Removed*LocalHost.LibraryPaths entries*' } | Should -Not -BeNullOrEmpty
    }

    It "retains entries for other repos" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_other_repo.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=C:\repoA',
            'LocalHost.LibraryPaths2=C:\repoB'
        )
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '64' -RepositoryRoot 'C:\another' } 3>&1
        $updated = Get-Content -LiteralPath $iniPath
        $updated | Should -Contain 'LocalHost.LibraryPaths1=C:\repoA'
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\repoB'
        $warnings.Count | Should -Be 0
    }

    It "removes entries matching current repo path regardless of case" {
        $iniPath = Join-Path $TestDrive 'LabVIEW_case.ini'
        Set-Content -LiteralPath $iniPath -Value @(
            'LocalHost.LibraryPaths1=c:\Repo\Path',
            'LocalHost.LibraryPaths2=C:\KEEP'
        )
        Set-Item -Path Function:Resolve-LVIniPath -Value ([scriptblock]::Create("param([string]`$LvVersion,[string]`$Arch) return '$iniPath'"))
        $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '32' -RepositoryRoot 'C:\repo\path' } 3>&1
        $updated = Get-Content -LiteralPath $iniPath
        # Repo entry is retained (cleanup is deferred to revert)
        $updated | Should -Contain 'LocalHost.LibraryPaths1=c:\Repo\Path'
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\KEEP'
        # No warning expected for retained repo entry
        $warnings | Where-Object { $_ -like '*Removed*LocalHost.LibraryPaths entries*' } | Should -BeNullOrEmpty
    }
}
