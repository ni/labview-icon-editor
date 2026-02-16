#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:RepoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
    $Script:HelperPath = Join-Path $Script:RepoRoot 'Tooling\support\DevModeNoLabVIEWSmoke.ps1'
    if (-not (Test-Path -Path $Script:HelperPath -PathType Leaf)) {
        throw "DevModeNoLabVIEWSmoke helper not found at $Script:HelperPath"
    }
    . $Script:HelperPath
}

Describe 'Get-DevModeNoLabVIEWSmokeSuite' {
    It 'returns the minimal suite with only DevMode.NoLabVIEW unit tests' {
        $suite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'minimal'

        $suite.Depth | Should -Be 'minimal'
        $suite.Tests | Should -HaveCount 1
        $suite.Tests[0].Path | Should -Be 'Test/Pester/DevMode.NoLabVIEW.Tests.ps1'
        $suite.Tests[0].Kind | Should -Be 'unit'
    }

    It 'returns the balanced suite with unit plus LUnit/missing-in-project integration smoke' {
        $suite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'balanced'

        $suite.Depth | Should -Be 'balanced'
        $suite.Tests | Should -HaveCount 3
        $suite.Tests[0].Path | Should -Be 'Test/Pester/DevMode.NoLabVIEW.Tests.ps1'
        $suite.Tests[1].Path | Should -Be 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1'
        $suite.Tests[2].Path | Should -Be 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'
        ($suite.Tests | Where-Object { $_.Kind -eq 'integration' }).Count | Should -Be 2
    }

    It 'returns the full suite with all no-LabVIEW integration smoke files' {
        $suite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'full'

        $suite.Depth | Should -Be 'full'
        $suite.Tests | Should -HaveCount 5
        $suite.Tests[0].Path | Should -Be 'Test/Pester/DevMode.NoLabVIEW.Tests.ps1'
        $suite.Tests[1].Path | Should -Be 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1'
        $suite.Tests[2].Path | Should -Be 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'
        $suite.Tests[3].Path | Should -Be 'Test/Pester/VerifyIEPaths.DevMode.Integration.Tests.ps1'
        $suite.Tests[4].Path | Should -Be 'Test/Pester/BuildLvlibp.DevMode.NoLabVIEW.Integration.Tests.ps1'
        ($suite.Tests | Where-Object { $_.Kind -eq 'integration' }).Count | Should -Be 4
    }
}

Describe 'Test-DevModeNoLabVIEWSmokeCoverage' {
    It 'fails when integration smoke files are fully skipped' {
        $suite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'balanced'
        $integrationPaths = @(
            [System.IO.Path]::GetFullPath((Join-Path $Script:RepoRoot 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1')),
            [System.IO.Path]::GetFullPath((Join-Path $Script:RepoRoot 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'))
        )

        $pesterResult = [pscustomobject]@{
            Tests = @(
                [pscustomobject]@{ ScriptBlock = [pscustomobject]@{ File = $integrationPaths[0] }; Result = 'Skipped' },
                [pscustomobject]@{ ScriptBlock = [pscustomobject]@{ File = $integrationPaths[1] }; Result = 'Skipped' }
            )
        }

        $coverage = Test-DevModeNoLabVIEWSmokeCoverage -PesterResult $pesterResult -Suite $suite

        $coverage.Passed | Should -BeFalse
        $coverage.Messages.Count | Should -Be 2
        ($coverage.Messages -join ' ') | Should -Match 'fully skipped'
    }

    It 'passes when integration smoke executes at least one test per integration file' {
        $suite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'balanced'
        $integrationPaths = @(
            [System.IO.Path]::GetFullPath((Join-Path $Script:RepoRoot 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1')),
            [System.IO.Path]::GetFullPath((Join-Path $Script:RepoRoot 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'))
        )

        $pesterResult = [pscustomobject]@{
            Tests = @(
                [pscustomobject]@{ ScriptBlock = [pscustomobject]@{ File = $integrationPaths[0] }; Result = 'Passed' },
                [pscustomobject]@{ ScriptBlock = [pscustomobject]@{ File = $integrationPaths[0] }; Result = 'Skipped' },
                [pscustomobject]@{ ScriptBlock = [pscustomobject]@{ File = $integrationPaths[1] }; Result = 'Passed' }
            )
        }

        $coverage = Test-DevModeNoLabVIEWSmokeCoverage -PesterResult $pesterResult -Suite $suite

        $coverage.Passed | Should -BeTrue
        @($coverage.Messages).Count | Should -Be 0
        $coverage.Details | Should -HaveCount 2
    }
}

Describe 'Assert-DevModeNoLabVIEWProjectFileClean' {
    It 'passes when project status output is empty' {
        {
            Assert-DevModeNoLabVIEWProjectFileClean `
                -RepoRoot $Script:RepoRoot `
                -ProjectRelativePath 'lv_icon_editor.lvproj' `
                -StatusLines @()
        } | Should -Not -Throw
    }

    It 'fails when project status output indicates a dirty file' {
        {
            Assert-DevModeNoLabVIEWProjectFileClean `
                -RepoRoot $Script:RepoRoot `
                -ProjectRelativePath 'lv_icon_editor.lvproj' `
                -StatusLines @(' M lv_icon_editor.lvproj')
        } | Should -Throw "'lv_icon_editor.lvproj' must be clean before smoke/parity. Clear it, then rerun."
    }
}

Describe 'Resolve-DevModeNoLabVIEWSmokeSuiteForBitness' {
    BeforeEach {
        $script:prevAclDowngrade = $env:LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE
        $script:prevWarnOnly = $env:LVIE_RUNNER_ACL_WARN_ONLY
    }

    AfterEach {
        if ($null -eq $script:prevAclDowngrade) {
            Remove-Item Env:LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE = $script:prevAclDowngrade
        }
        if ($null -eq $script:prevWarnOnly) {
            Remove-Item Env:LVIE_RUNNER_ACL_WARN_ONLY -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_RUNNER_ACL_WARN_ONLY = $script:prevWarnOnly
        }
    }

    It 'keeps requested depth when install path is writable' {
        Mock Get-LabVIEWInstallRootForSmoke { 'C:\LabVIEW 2021' }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*LabVIEW Icon API*' -and $PathType -eq 'Container' }
        Mock Test-SmokeDirectoryWriteAccess { $true }

        $resolved = Resolve-DevModeNoLabVIEWSmokeSuiteForBitness -Depth full -LabVIEWVersion '2021' -Bitness '32'

        $resolved.RequestedDepth | Should -Be 'full'
        $resolved.EffectiveDepth | Should -Be 'full'
        $resolved.Downgraded | Should -BeFalse
        $resolved.AccessWritable | Should -BeTrue
    }

    It 'downgrades to minimal when install path is not writable and policy allows downgrade' {
        $env:LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE = '1'
        Mock Get-LabVIEWInstallRootForSmoke { 'C:\LabVIEW 2021' }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*LabVIEW Icon API*' -and $PathType -eq 'Container' }
        Mock Test-SmokeDirectoryWriteAccess { $false }

        $resolved = Resolve-DevModeNoLabVIEWSmokeSuiteForBitness -Depth full -LabVIEWVersion '2021' -Bitness '32'

        $resolved.RequestedDepth | Should -Be 'full'
        $resolved.EffectiveDepth | Should -Be 'minimal'
        $resolved.Downgraded | Should -BeTrue
        $resolved.AccessWritable | Should -BeFalse
        $resolved.AccessReason | Should -Match 'No write access'
    }

    It 'throws when install path is not writable and downgrade policy is disabled' {
        $env:LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE = '0'
        $env:LVIE_RUNNER_ACL_WARN_ONLY = '0'
        Mock Get-LabVIEWInstallRootForSmoke { 'C:\LabVIEW 2021' }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*LabVIEW Icon API*' -and $PathType -eq 'Container' }
        Mock Test-SmokeDirectoryWriteAccess { $false }

        {
            Resolve-DevModeNoLabVIEWSmokeSuiteForBitness -Depth full -LabVIEWVersion '2021' -Bitness '32'
        } | Should -Throw '*Set LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE=1*'
    }
}
