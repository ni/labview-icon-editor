#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW CLI port contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:contractPath = Join-Path $script:repoRoot 'Tooling\labviewcli-port-contract.json'
        $script:contract = Get-Content -LiteralPath $script:contractPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\LabVIEWCliPortContract.ps1'
        . $script:helperPath
    }

    It 'has schema_version 1.0 and labview_cli_ports node' {
        (Test-Path -LiteralPath $script:contractPath -PathType Leaf) | Should -BeTrue
        $script:contract.schema_version | Should -Be '1.0'
        $script:contract.PSObject.Properties.Name | Should -Contain 'labview_cli_ports'
    }

    It 'defines required years and bitness ports' {
        $ports = $script:contract.labview_cli_ports
        $ports.PSObject.Properties.Name | Should -Contain '2020'
        $ports.PSObject.Properties.Name | Should -Contain '2026'

        ([int]$ports.'2020'.'32') | Should -Be 3365
        ([int]$ports.'2020'.'64') | Should -Be 3366
        ([int]$ports.'2026'.'32') | Should -Be 3364
        ([int]$ports.'2026'.'64') | Should -Be 3363
    }

    It 'uses valid TCP port ranges for all defined year/bitness entries' {
        $ports = $script:contract.labview_cli_ports
        foreach ($yearProp in $ports.PSObject.Properties) {
            foreach ($bitnessProp in $yearProp.Value.PSObject.Properties) {
                $port = 0
                [int]::TryParse([string]$bitnessProp.Value, [ref]$port) | Should -BeTrue
                $port | Should -BeGreaterThan 0
                $port | Should -BeLessThan 65536
            }
        }
    }

    It 'keeps strict mode as default when remediation is not requested' {
        $tempRepo = Join-Path $TestDrive 'repo-strict'
        $toolingRoot = Join-Path $tempRepo 'Tooling'
        $labviewDir = Join-Path $tempRepo 'LabVIEW'
        New-Item -Path $toolingRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $labviewDir -ItemType Directory -Force | Out-Null

        @(
            '{'
            '  "schema_version": "1.0",'
            '  "labview_cli_ports": {'
            '    "2020": {'
            '      "64": 3366'
            '    }'
            '  }'
            '}'
        ) | Set-Content -LiteralPath (Join-Path $toolingRoot 'labviewcli-port-contract.json') -Encoding utf8

        Set-Content -LiteralPath (Join-Path $labviewDir 'LabVIEW.exe') -Value '' -Encoding ascii
        @(
            'server.tcp.enabled=true'
            'server.tcp.port=1234'
        ) | Set-Content -LiteralPath (Join-Path $labviewDir 'LabVIEW.ini') -Encoding ascii

        {
            Resolve-LabVIEWCliPortFromContract `
                -RepoRoot $tempRepo `
                -LabVIEWVersion '20.0' `
                -Bitness '64' `
                -LabVIEWExecutablePath (Join-Path $labviewDir 'LabVIEW.exe')
        } | Should -Throw '*mismatch*'
    }

    It 'remediates server.tcp.enabled and server.tcp.port when explicitly enabled' {
        $tempRepo = Join-Path $TestDrive 'repo-remediate'
        $toolingRoot = Join-Path $tempRepo 'Tooling'
        $labviewDir = Join-Path $tempRepo 'LabVIEW'
        New-Item -Path $toolingRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $labviewDir -ItemType Directory -Force | Out-Null

        @(
            '{'
            '  "schema_version": "1.0",'
            '  "labview_cli_ports": {'
            '    "2020": {'
            '      "64": 3366'
            '    }'
            '  }'
            '}'
        ) | Set-Content -LiteralPath (Join-Path $toolingRoot 'labviewcli-port-contract.json') -Encoding utf8

        Set-Content -LiteralPath (Join-Path $labviewDir 'LabVIEW.exe') -Value '' -Encoding ascii
        @(
            'server.tcp.enabled=false'
            'server.tcp.port=1234'
        ) | Set-Content -LiteralPath (Join-Path $labviewDir 'LabVIEW.ini') -Encoding ascii

        $result = Resolve-LabVIEWCliPortFromContract `
            -RepoRoot $tempRepo `
            -LabVIEWVersion '20.0' `
            -Bitness '64' `
            -LabVIEWExecutablePath (Join-Path $labviewDir 'LabVIEW.exe') `
            -EnableRemediation

        $result.PortNumber | Should -Be 3366
        $result.RemediationEnabled | Should -BeTrue
        $result.RemediationApplied | Should -BeTrue

        $iniContent = Get-Content -LiteralPath (Join-Path $labviewDir 'LabVIEW.ini') -Raw
        $iniContent | Should -Match 'server\.tcp\.enabled=true'
        $iniContent | Should -Match 'server\.tcp\.port=3366'
    }
}

