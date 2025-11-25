# Round‑trip golden‑sample tests for VIPB & LVPROJ
$Root      = Split-Path $PSScriptRoot -Parent
$Samples   = Join-Path $PSScriptRoot "Samples"
$WorkRoot  = Join-Path $PSScriptRoot "RoundTripTestOutput"

function New‑CleanDir ([string]$Path) {
    if (Test-Path $Path) { Remove-Item $Path -Recurse -Force }
    New-Item $Path -ItemType Directory | Out-Null
}

Describe "VIPB golden sample round‑trip" {

    $vipbFiles = Get-ChildItem $Samples -Filter '*.vipb' -File
    It "has .vipb samples to test" { $vipbFiles.Count | Should -BeGreaterThan 0 }

    foreach ($file in $vipbFiles) {
        It "round‑trips $($file.Name) with no JSON diff" -TestCases @($file) {
            param($vipb)

            $caseDir         = Join-Path $WorkRoot $vipb.BaseName
            New‑CleanDir $caseDir

            $jsonOrig        = Join-Path $caseDir 'orig.json'
            $vipbRound       = Join-Path $caseDir 'rt.vipb'
            $jsonRound       = Join-Path $caseDir 'rt.json'

            $vipb2json = (Get-Command vipb2json -ErrorAction Stop).Path
            $json2vipb = (Get-Command json2vipb -ErrorAction Stop).Path

            & $vipb2json --input $vipb.FullName --output $jsonOrig
            & $json2vipb --input $jsonOrig    --output $vipbRound
            & $vipb2json --input $vipbRound   --output $jsonRound

            Get-Content $jsonOrig -Raw |
              Should -BeExactly (Get-Content $jsonRound -Raw) `
              -Because "$($vipb.Name) JSON changed after round‑trip"
        }
    }
}

Describe "LVPROJ golden sample round‑trip" {

    $projFiles = Get-ChildItem $Samples -Filter '*.lvproj' -File
    It "has .lvproj samples to test" { $projFiles.Count | Should -BeGreaterThan 0 }

    foreach ($file in $projFiles) {
        It "round‑trips $($file.Name) with no JSON diff" -TestCases @($file) {
            param($proj)

            $caseDir        = Join-Path $WorkRoot $proj.BaseName
            New‑CleanDir $caseDir

            $jsonOrig       = Join-Path $caseDir 'orig.json'
            $projRound      = Join-Path $caseDir 'rt.lvproj'
            $jsonRound      = Join-Path $caseDir 'rt.json'

            $proj2json = (Get-Command lvproj2json -ErrorAction Stop).Path
            $json2proj = (Get-Command json2lvproj -ErrorAction Stop).Path

            & $proj2json --input $proj.FullName --output $jsonOrig
            & $json2proj --input $jsonOrig     --output $projRound
            & $proj2json --input $projRound    --output $jsonRound

            Get-Content $jsonOrig -Raw |
              Should -BeExactly (Get-Content $jsonRound -Raw) `
              -Because "$($proj.Name) JSON changed after round‑trip"
        }
    }
}
