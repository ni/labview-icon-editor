Import-Module Pester -Force -ErrorAction Stop
dotnet restore src/VipbJsonTool/VipbJsonTool.csproj -ErrorAction Stop
dotnet build src/VipbJsonTool/VipbJsonTool.csproj -c Release --no-restore -ErrorAction Stop
$result = Invoke-Pester -Configuration @{
    Run        = @{ Path = 'tests/RoundTrip.GoldenSample.Tests.ps1'; PassThru = $true }
    TestResult = @{ Enabled = $true; OutputFormat = 'NUnitXml'; OutputPath = 'golden-sample-results.xml' }
}
Write-Host "`nPester finished. Passed=$($result.PassedCount)  Failed=$($result.FailedCount)`n"
if ($result.FailedCount -gt 0) { exit 1 }
