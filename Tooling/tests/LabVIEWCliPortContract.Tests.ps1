#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'LabVIEW CLI port contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:contractPath = Join-Path $script:repoRoot 'Tooling\labviewcli-port-contract.json'
        $script:contract = Get-Content -LiteralPath $script:contractPath -Raw | ConvertFrom-Json -ErrorAction Stop
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
}

