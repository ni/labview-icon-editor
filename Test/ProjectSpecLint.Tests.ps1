$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "LabVIEWIconAPI build spec lint" {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $projectPath = Join-Path $repoRoot 'lv_icon_editor.lvproj'

        $project = [xml](Get-Content -LiteralPath $projectPath -Raw)
        $specNode = $project.SelectSingleNode("//Item[@Type='Source Distribution' and @Name='LabVIEWIconAPI']")
        if (-not $specNode) {
            throw "Build spec 'LabVIEWIconAPI' not found in $projectPath"
        }

        $SpecProps = @{}
        foreach ($p in $specNode.Property) {
            $SpecProps[$p.Name] = $p.'#text'
        }

        $containerIndices = foreach ($key in $SpecProps.Keys) {
            if ($key -match '^Source\[(\d+)\]\.type$' -and $SpecProps[$key] -eq 'Container') {
                [int]$matches[1]
            }
        }

        $ContainerItemIds = $containerIndices |
            Sort-Object |
            ForEach-Object { ($SpecProps["Source[$_].itemID"] -replace '\\/', '/') }

        $SpecName = $SpecProps['Bld_buildSpecName']
    }

    It "anchors output under builds/LabVIEWIconAPI" {
        $SpecProps['Bld_localDestDir'] | Should -Be '../builds/LabVIEWIconAPI'
        $SpecProps['Destination[0].path'] | Should -Be '../builds/LabVIEWIconAPI'
        $SpecProps['Destination[1].path'] | Should -Be '../builds/LabVIEWIconAPI/data'
    }

    It "applies the approved exclusion set" {
        $expected = @('vi.lib','resource/objmgr','/C/ProgramData/National Instruments/InstCache/21.0','instr.lib','user.lib','resource/dialog')
        $actual = $SpecProps.Keys |
            Where-Object { $_ -match '^Bld_excludedDirectory\[\d+\]$' } |
            Sort-Object |
            ForEach-Object { $SpecProps[$_] }

        $SpecProps['Bld_excludedDirectoryCount'] | Should -Be $expected.Count
        @($actual | Sort-Object) | Should -Be (@($expected | Sort-Object))
    }

    It "limits sources to vi.lib, resource/plugins, and unit tests" {
        $containers = $ContainerItemIds
        $expected = @(
            '/My Computer/vi.lib/LabVIEW Icon API',
            '/My Computer/resource/plugins',
            '/My Computer/Unit tests'
        )

        $SpecProps['SourceCount'] | Should -Be $expected.Count
        @($containers | Sort-Object) | Should -Be (@($expected | Sort-Object))
    }
}

Describe "LabVIEWIconAPI automation alignment" {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
        $buildScriptPath = Join-Path $repoRoot 'scripts/build-source-distribution/Build_Source_Distribution.ps1'
        $orchestrationPath = Join-Path $repoRoot 'Tooling/dotnet/OrchestrationCli/Program.cs'
        $vipbPath = Join-Path $repoRoot 'Tooling/deployment/seed.vipb'

        $project = [xml](Get-Content -LiteralPath (Join-Path $repoRoot 'lv_icon_editor.lvproj') -Raw)
        $specNode = $project.SelectSingleNode("//Item[@Type='Source Distribution' and @Name='LabVIEWIconAPI']")
        if (-not $specNode) {
            throw "Build spec 'LabVIEWIconAPI' not found in lv_icon_editor.lvproj"
        }

        $SpecName = $specNode.Property | Where-Object { $_.Name -eq 'Bld_buildSpecName' } | Select-Object -First 1 -ExpandProperty '#text'
    }

    It "keeps the spec name aligned with Build_Source_Distribution.ps1" {
        $content = Get-Content -LiteralPath $buildScriptPath -Raw
        $pattern = "-b['`"]\s*,\s*['`"]$([regex]::Escape($SpecName))['`"]"
        $content -match $pattern | Should -BeTrue
    }

    It "keeps the spec name aligned with OrchestrationCli" {
        $content = Get-Content -LiteralPath $orchestrationPath -Raw
        $pattern = '"--name"\s*,\s*"' + [regex]::Escape($SpecName) + '"'
        $content -match $pattern | Should -BeTrue
    }

    It "keeps VIPB source and output folders stable" {
        $vipb = [xml](Get-Content -LiteralPath $vipbPath -Raw)
        ($vipb.SelectSingleNode('//Library_General_Settings/Library_Source_Folder')).InnerText | Should -Be '..\..'
        ($vipb.SelectSingleNode('//Library_General_Settings/Library_Output_Folder')).InnerText | Should -Be '..\..\builds\VI Package'
    }
}
