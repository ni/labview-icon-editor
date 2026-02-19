#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW container release contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\LabVIEWContainerRelease.ps1'
        $script:snapshotPath = Join-Path $script:repoRoot 'Tooling\container-parity\labview-container-tags.snapshot.json'
    }

    It 'exposes the .lvcontainer resolver helper' {
        (Test-Path -LiteralPath $script:helperPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $script:snapshotPath -PathType Leaf) | Should -BeTrue
    }

    It 'resolves .lvcontainer contract from repo root (2026q1-linux)' {
        . $script:helperPath
        $info = Get-LabVIEWContainerReleaseInfo -RepoRoot $script:repoRoot -DisableLiveDiscovery

        $info.Raw | Should -Be '2026q1-linux'
        $info.Tag | Should -Be '2026q1-linux'
        $info.Os | Should -Be 'linux'
        $info.Year | Should -Be '2026'
        $info.MinorRevision | Should -Be 1
        $info.ReleaseTag | Should -Be '2026q1'
        $info.Image | Should -Be 'nationalinstruments/labview:2026q1-linux'
        $info.LinuxImage | Should -Be 'nationalinstruments/labview:2026q1-linux'
        $info.CatalogSource | Should -Be 'snapshot'
    }

    It 'accepts all seven snapshot tags' {
        . $script:helperPath
        $cases = @(
            @{ Tag = '2025q3-linux';          Os = 'linux';   Year = '2025'; Minor = 3; Release = '2025q3'; LinuxImage = 'nationalinstruments/labview:2025q3-linux' },
            @{ Tag = '2025q3patch1-linux';    Os = 'linux';   Year = '2025'; Minor = 3; Release = '2025q3'; LinuxImage = 'nationalinstruments/labview:2025q3patch1-linux' },
            @{ Tag = '2026q1-linux';          Os = 'linux';   Year = '2026'; Minor = 1; Release = '2026q1'; LinuxImage = 'nationalinstruments/labview:2026q1-linux' },
            @{ Tag = '2026q1-windows';        Os = 'windows'; Year = '2026'; Minor = 1; Release = '2026q1'; LinuxImage = '' },
            @{ Tag = '2026q1-windows-beta';   Os = 'windows'; Year = '2026'; Minor = 1; Release = '2026q1'; LinuxImage = '' },
            @{ Tag = 'latest-linux';          Os = 'linux';   Year = '2026'; Minor = 1; Release = '2026q1'; LinuxImage = 'nationalinstruments/labview:latest-linux' },
            @{ Tag = 'latest-windows';        Os = 'windows'; Year = '2026'; Minor = 1; Release = '2026q1'; LinuxImage = '' }
        )

        foreach ($case in $cases) {
            $info = Get-LabVIEWContainerReleaseInfo -VersionInput $case.Tag -CatalogSnapshotPath $script:snapshotPath -DisableLiveDiscovery
            $info.Tag | Should -Be $case.Tag
            $info.Os | Should -Be $case.Os
            $info.Year | Should -Be $case.Year
            $info.MinorRevision | Should -Be $case.Minor
            $info.ReleaseTag | Should -Be $case.Release
            $info.Image | Should -Be ("nationalinstruments/labview:{0}" -f $case.Tag)
            $info.LinuxImage | Should -Be $case.LinuxImage
            $info.CatalogSource | Should -Be 'snapshot'
        }
    }

    It 'falls back to snapshot when live discovery fails' {
        . $script:helperPath
        $info = Get-LabVIEWContainerReleaseInfo `
            -VersionInput 'latest-linux' `
            -CatalogSnapshotPath $script:snapshotPath `
            -DockerHubTagsApi 'http://127.0.0.1:9/unreachable'

        $info.Tag | Should -Be 'latest-linux'
        $info.CatalogSource | Should -Be 'snapshot'
    }

    It 'rejects unknown tags' {
        . $script:helperPath
        { Get-LabVIEWContainerReleaseInfo -VersionInput '2024q4-linux' -CatalogSnapshotPath $script:snapshotPath -DisableLiveDiscovery } | Should -Throw '*Unsupported .lvcontainer tag*'
    }
}
