<#
# Legacy external validator shim (archived)
# Retains original environment variables for historical reference.
#>

param(
  [ValidateSet("validate","ingest")]
  [string]$Mode = $(if ($env:JARVIS_SHIM_MODE) { $env:JARVIS_SHIM_MODE } else { "validate" }),
  [string]$Root = $env:JARVIS_SHIM_ROOT,
  [string]$Zip = $env:JARVIS_SHIM_ZIP,
  [string]$ProjectPath = $(if ($env:PROJECT_PATH) { $env:PROJECT_PATH } else { "src/Jarvis/Jarvis.csproj" }),
  [string]$OutJson = $(if ($env:OUT_JSON) { $env:OUT_JSON } else { "jarvis-result.json" })
)

if ($Mode -notin @("validate","ingest")) {
  Write-Error "JARVIS_SHIM_MODE must be validate or ingest"; exit 2
}
$cmd = @("dotnet","run","--project",$ProjectPath,"--",$Mode)
if ($Root) { $cmd += @("--root",$Root) }
elseif ($Zip) { $cmd += @("--zip",$Zip) }
else { Write-Error "Provide JARVIS_SHIM_ROOT or JARVIS_SHIM_ZIP"; exit 2 }
$cmd += @("--json")

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $cmd[0]
$psi.Arguments = ($cmd[1..($cmd.Length-1)] -join " ")
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
$code = $p.ExitCode

$stdout | Out-File -LiteralPath $OutJson -Encoding utf8 -NoNewline
# Parse JSON
try {
  $json = Get-Content -Raw -LiteralPath $OutJson | ConvertFrom-Json
  $overall = $false
  if ($json.PSObject.Properties.Name -contains "overallPassed") { $overall = [bool]$json.overallPassed }
  elseif ($json.PSObject.Properties.Name -contains "isValid") { $overall = [bool]$json.isValid }
  $ingested = $false
  if ($json.PSObject.Properties.Name -contains " ingested") { $ingested = [bool]$json.ingested }
} catch { $overall = $false; $ingested = $false }

# GITHUB_OUTPUT
if ($env:GITHUB_OUTPUT) {
  Add-Content -LiteralPath $env:GITHUB_OUTPUT "JARVIS_OVERALL=$overall"
  Add-Content -LiteralPath $env:GITHUB_OUTPUT "JARVIS_INGESTED=$ingested"
  Add-Content -LiteralPath $env:GITHUB_OUTPUT "JARVIS_JSON=$OutJson"
}

exit $code
