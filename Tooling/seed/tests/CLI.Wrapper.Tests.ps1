$cliCommands = @(
    "vipb2json","json2vipb",
    "lvproj2json","json2lvproj",
    "buildspec2json","json2buildspec"
)

Describe "CLI wrapper scripts basic behavior" {

    It "exists and is executable: <cmd>" -TestCases $cliCommands {
        param($cmd)
        (Get-Command $cmd -ErrorAction SilentlyContinue) | Should -Not -Be $null
    }

    It "displays help for <cmd> when --help is given" -TestCases $cliCommands {
        param($cmd)
        $exe = (Get-Command $cmd -ErrorAction Stop).Path
        & $exe --help 2>$null
        $LASTEXITCODE | Should -Be 0
    }

    It "exits with error on unknown flag for <cmd>" -TestCases $cliCommands {
        param($cmd)
        $exe = (Get-Command $cmd -ErrorAction Stop).Path
        & $exe --bogus 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It "requires --input and --output parameters" {
        $exe = (Get-Command vipb2json -ErrorAction Stop).Path
        & $exe 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
