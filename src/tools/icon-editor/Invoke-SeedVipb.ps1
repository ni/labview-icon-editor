#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('vipb2json','json2vipb')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    $scriptPath = $PSCommandPath
}
if (-not $scriptPath) {
    throw 'Unable to resolve the script path for Invoke-SeedVipb.ps1.'
}
$scriptDir = Split-Path -Parent (Resolve-Path -LiteralPath $scriptPath -ErrorAction Stop)
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..' '..' '..') -ErrorAction Stop).ProviderPath

if (-not $IsWindows) {
    throw 'Invoke-SeedVipb.ps1 is intended for Windows hosts. On non-Windows platforms, use the seed CLI wrappers under tools/seed-2.2.1/bin.'
}
$vipbToolProject = Join-Path $repoRoot 'tools\seed-2.2.1\src\VipbJsonTool\VipbJsonTool.csproj'
if (-not (Test-Path -LiteralPath $vipbToolProject -PathType Leaf)) {
    throw "VipbJsonTool project not found at '$vipbToolProject'. Ensure tools/seed-2.2.1 is vendored."
}

$inputResolved = (Resolve-Path -LiteralPath $InputPath -ErrorAction Stop).ProviderPath

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFull = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath $OutputPath))
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'dotnet'
$psi.ArgumentList.Add('run')
$psi.ArgumentList.Add('--project')
$psi.ArgumentList.Add($vipbToolProject)
$runtimeIdentifier = if ($IsWindows) { 'win-x64' } else { 'linux-x64' }
$psi.ArgumentList.Add('--runtime')
$psi.ArgumentList.Add($runtimeIdentifier)
$psi.ArgumentList.Add('--no-self-contained')
$psi.ArgumentList.Add('--')
$psi.ArgumentList.Add($Mode)
$psi.ArgumentList.Add($inputResolved)
$psi.ArgumentList.Add($outputFull)
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::Start($psi)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($stdout) {
    Write-Host $stdout.TrimEnd()
}
if ($stderr) {
    Write-Host $stderr.TrimEnd()
}

if ($process.ExitCode -ne 0) {
    throw "VipbJsonTool '$Mode' invocation failed with exit code $($process.ExitCode)."
}

Write-Host ("[seed] VipbJsonTool {0} completed: {1} -> {2}" -f $Mode, $inputResolved, $outputFull)
