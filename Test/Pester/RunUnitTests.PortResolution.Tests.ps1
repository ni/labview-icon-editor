$ErrorActionPreference = 'Stop'

Describe 'RunUnitTests port resolution' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:scriptPath = Join-Path $script:repoRoot '.github\actions\run-unit-tests\RunUnitTests.ps1'
        if (-not (Test-Path -Path $script:scriptPath -PathType Leaf)) {
            throw "RunUnitTests.ps1 not found at $script:scriptPath"
        }

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw ("Failed to parse RunUnitTests.ps1: {0}" -f $errors[0].Message)
        }

        $requiredFunctions = @(
            'ConvertTo-LUnitPortNumber',
            'Get-LabVIEWIniTcpSettings',
            'Resolve-LUnitPort'
        )

        foreach ($functionName in $requiredFunctions) {
            $functionAst = $ast.Find(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
                },
                $true
            )
            if (-not $functionAst) {
                throw "Function '$functionName' not found in RunUnitTests.ps1"
            }
            Invoke-Expression $functionAst.Extent.Text
        }
    }

    BeforeEach {
        $script:previousBitnessPort = $env:LVIE_LUNIT_PORT_64
        $script:previousGenericPort = $env:LVIE_LUNIT_PORT
        Remove-Item Env:LVIE_LUNIT_PORT_64 -ErrorAction SilentlyContinue
        Remove-Item Env:LVIE_LUNIT_PORT -ErrorAction SilentlyContinue

        $script:testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("lvie-port-test-" + [Guid]::NewGuid().ToString('N'))
        New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null
        $script:labviewExe = Join-Path $script:testRoot 'LabVIEW.exe'
        New-Item -Path $script:labviewExe -ItemType File -Force | Out-Null
        $script:iniPath = Join-Path $script:testRoot 'LabVIEW.ini'
    }

    AfterEach {
        if ($null -eq $script:previousBitnessPort) {
            Remove-Item Env:LVIE_LUNIT_PORT_64 -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_LUNIT_PORT_64 = $script:previousBitnessPort
        }

        if ($null -eq $script:previousGenericPort) {
            Remove-Item Env:LVIE_LUNIT_PORT -ErrorAction SilentlyContinue
        } else {
            $env:LVIE_LUNIT_PORT = $script:previousGenericPort
        }

        if (Test-Path -Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force
        }
    }

    It 'prefers bitness-specific environment override' {
        $env:LVIE_LUNIT_PORT_64 = '3377'
        $env:LVIE_LUNIT_PORT = '3399'

        $resolved = Resolve-LUnitPort -Bitness '64' -LabVIEWExecutablePath $script:labviewExe

        $resolved.PortNumber | Should -Be 3377
        $resolved.Source | Should -Be '$env:LVIE_LUNIT_PORT_64'
        $resolved.HasEnvOverride | Should -BeTrue
    }

    It 'uses generic environment override when bitness-specific is absent' {
        $env:LVIE_LUNIT_PORT = '3399'

        $resolved = Resolve-LUnitPort -Bitness '64' -LabVIEWExecutablePath $script:labviewExe

        $resolved.PortNumber | Should -Be 3399
        $resolved.Source | Should -Be '$env:LVIE_LUNIT_PORT'
        $resolved.HasEnvOverride | Should -BeTrue
    }

    It 'uses LabVIEW.ini server.tcp.port when no environment override is set' {
        @(
            'server.tcp.enabled=true',
            'server.tcp.port=3370'
        ) | Set-Content -Path $script:iniPath -Encoding ascii

        $resolved = Resolve-LUnitPort -Bitness '64' -LabVIEWExecutablePath $script:labviewExe

        $resolved.PortNumber | Should -Be 3370
        $resolved.Source | Should -Be "$script:iniPath (server.tcp.port)"
        $resolved.ViServerEnabled | Should -BeTrue
    }

    It 'ignores invalid environment override and falls through to LabVIEW.ini' {
        $env:LVIE_LUNIT_PORT_64 = 'not-a-number'
        'server.tcp.port=3370' | Set-Content -Path $script:iniPath -Encoding ascii

        $resolved = Resolve-LUnitPort -Bitness '64' -LabVIEWExecutablePath $script:labviewExe

        $resolved.PortNumber | Should -Be 3370
        $resolved.Source | Should -Be "$script:iniPath (server.tcp.port)"
    }

    It 'defaults to 3363 when no valid source is available' {
        $resolved = Resolve-LUnitPort -Bitness '64' -LabVIEWExecutablePath $script:labviewExe

        $resolved.PortNumber | Should -Be 3363
        $resolved.Source | Should -Be 'default:3363'
    }
}
