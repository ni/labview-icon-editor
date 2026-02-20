#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

BeforeAll {
    $Script:RepoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
    $Script:ToolingRoot = Join-Path $Script:RepoRoot 'Tooling'
    $Script:GuardScript = Join-Path $Script:ToolingRoot 'Test-SolutionContract.ps1'
}

Describe 'Test-SolutionContract.ps1' {

    It 'exists in Tooling' {
        (Test-Path -LiteralPath $Script:GuardScript -PathType Leaf) | Should -BeTrue
    }

    It 'passes for the repository solution contract' {
        { & $Script:GuardScript -RepoRoot $Script:RepoRoot } | Should -Not -Throw
    }

    It 'fails when solution file is missing' {
        $tempRepo = Join-Path $TestDrive 'repo-missing-sln'
        New-Item -Path $tempRepo -ItemType Directory -Force | Out-Null

        { & $Script:GuardScript -RepoRoot $tempRepo } | Should -Throw '*missing-solution-file*'
    }

    It 'fails when solution contains a project path outside repo root' {
        $tempRepo = Join-Path $TestDrive 'repo-outside-project'
        New-Item -Path $tempRepo -ItemType Directory -Force | Out-Null
        foreach ($relativePath in @(
                'Tooling\runner-cli\RunnerCli\RunnerCli.csproj',
                'Tooling\runner-cli\RunnerCli.Tests\RunnerCli.Tests.csproj'
            )) {
            $fullPath = Join-Path $tempRepo $relativePath
            New-Item -Path (Split-Path -Path $fullPath -Parent) -ItemType Directory -Force | Out-Null
            Set-Content -LiteralPath $fullPath -Value '<Project Sdk="Microsoft.NET.Sdk" />' -Encoding utf8
        }

        $solutionContent = @(
            'Microsoft Visual Studio Solution File, Format Version 12.00'
            '# Visual Studio Version 17'
            'VisualStudioVersion = 17.5.2.0'
            'MinimumVisualStudioVersion = 10.0.40219.1'
            'Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "RunnerCli", "Tooling\runner-cli\RunnerCli\RunnerCli.csproj", "{11111111-1111-1111-1111-111111111111}"'
            'EndProject'
            'Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "RunnerCli.Tests", "Tooling\runner-cli\RunnerCli.Tests\RunnerCli.Tests.csproj", "{22222222-2222-2222-2222-222222222222}"'
            'EndProject'
            'Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Bad", "..\external\Bad.csproj", "{33333333-3333-3333-3333-333333333333}"'
            'EndProject'
            'Global'
            'EndGlobal'
        ) -join [Environment]::NewLine
        Set-Content -LiteralPath (Join-Path $tempRepo 'labview-icon-editor.sln') -Value $solutionContent -Encoding utf8

        { & $Script:GuardScript -RepoRoot $tempRepo } | Should -Throw '*solution-project-outside-repo*'
    }

    It 'fails when required runner-cli projects are not listed in solution' {
        $tempRepo = Join-Path $TestDrive 'repo-missing-required-entry'
        New-Item -Path $tempRepo -ItemType Directory -Force | Out-Null
        foreach ($relativePath in @(
                'Tooling\runner-cli\RunnerCli\RunnerCli.csproj',
                'Tooling\runner-cli\RunnerCli.Tests\RunnerCli.Tests.csproj'
            )) {
            $fullPath = Join-Path $tempRepo $relativePath
            New-Item -Path (Split-Path -Path $fullPath -Parent) -ItemType Directory -Force | Out-Null
            Set-Content -LiteralPath $fullPath -Value '<Project Sdk="Microsoft.NET.Sdk" />' -Encoding utf8
        }

        $toolingProjectPath = Join-Path $tempRepo 'Tooling\other\Other.csproj'
        New-Item -Path (Split-Path -Path $toolingProjectPath -Parent) -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $toolingProjectPath -Value '<Project Sdk="Microsoft.NET.Sdk" />' -Encoding utf8

        $solutionContent = @(
            'Microsoft Visual Studio Solution File, Format Version 12.00'
            '# Visual Studio Version 17'
            'VisualStudioVersion = 17.5.2.0'
            'MinimumVisualStudioVersion = 10.0.40219.1'
            'Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Other", "Tooling\other\Other.csproj", "{44444444-4444-4444-4444-444444444444}"'
            'EndProject'
            'Global'
            'EndGlobal'
        ) -join [Environment]::NewLine
        Set-Content -LiteralPath (Join-Path $tempRepo 'labview-icon-editor.sln') -Value $solutionContent -Encoding utf8

        { & $Script:GuardScript -RepoRoot $tempRepo } | Should -Throw '*missing-required-solution-project*'
    }
}
