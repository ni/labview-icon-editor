$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VIPB uniqueness guard" {
    It "fails when more than one repo .vipb is present" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $vipbs = Get-ChildItem -Path $repoRoot -Filter *.vipb -File -Recurse |
            Where-Object {
                $_.FullName -notmatch '\\\.tmp-tests\\' -and
                $_.FullName -notmatch '\\builds(-isolated(-tests)?)?\\' -and
                $_.FullName -notmatch '\\temp_telemetry\\' -and
                $_.FullName -notmatch '\\artifacts\\'
            }

        $vipbs.Count | Should -Be 1
        $vipbs[0].FullName | Should -Match 'Tooling[\\/]+deployment[\\/]seed\.vipb$'
    }
}
