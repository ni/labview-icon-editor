param(
    [ValidateSet('2021')]
    [string]$LabVIEWVersion = '2021',

    [ValidateSet('32', '64', 'both', 'all', 'auto')]
    [string]$LabVIEWBitness = '64',

    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000,

    [switch]$RunDevModeTests,

    [switch]$CI
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
$env:LABVIEW_VERSION = $LabVIEWVersion
$env:LABVIEW_BITNESS = $LabVIEWBitness
$env:LABVIEW_CONNECT_TIMEOUT_MS = $ConnectTimeoutMs.ToString()
$env:LABVIEW_PROCESS_TIMEOUT_MS = $ProcessTimeoutMs.ToString()
if ($PSBoundParameters.ContainsKey('RunDevModeTests')) {
    if ($RunDevModeTests) {
        $env:RUN_DEV_MODE_TESTS = '1'
    } else {
        Remove-Item Env:RUN_DEV_MODE_TESTS -ErrorAction SilentlyContinue
    }
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'

if ($CI) {
    $resultsDir = Join-Path $repoRoot 'TestResults'
    if (-not (Test-Path -Path $resultsDir)) {
        New-Item -Path $resultsDir -ItemType Directory | Out-Null
    }

    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = (Join-Path $resultsDir ("pester-devmode-$LabVIEWVersion-$LabVIEWBitness.xml"))
}

$results = Invoke-Pester -Configuration $configuration
if ($results.FailedCount -gt 0) {
    exit 1
}
