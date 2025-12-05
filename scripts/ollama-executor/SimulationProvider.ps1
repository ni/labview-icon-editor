<#
.SYNOPSIS
  Simulation provider for Ollama executor - simulates PowerShell command execution without running real LabVIEW tools.

.DESCRIPTION
  This provider simulates execution of build scripts for cross-compilation scenarios where target platforms
  (LabVIEW versions/bitnesses) may not be installed. It produces realistic output and can create stub artifacts.

.ENVIRONMENT VARIABLES
  OLLAMA_SIM_FAIL         - If 'true', force simulated commands to fail (default: false)
  OLLAMA_SIM_EXIT         - Exit code for simulated commands (default: 0, overridden by FAIL=true -> 1)
  OLLAMA_SIM_DELAY_MS     - Artificial delay in milliseconds (default: 100)
  OLLAMA_SIM_CREATE_ARTIFACTS - If 'true', create stub artifact files (default: false)
  OLLAMA_SIM_PLATFORMS    - Comma-separated list of simulated platforms, e.g., "2021-32,2021-64,2025-64"

.PARAMETER Command
  The PowerShell command to simulate (e.g., "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 ...")

.PARAMETER WorkingDirectory
  The working directory where the command would execute (default: current directory)

.OUTPUTS
  Returns a PSCustomObject with:
  - ExitCode: Integer exit code
  - StdOut: Simulated stdout content
  - StdErr: Simulated stderr content  
  - Duration: Time taken in milliseconds

.EXAMPLE
  $env:OLLAMA_SIM_DELAY_MS = 500
  $result = & scripts/ollama-executor/SimulationProvider.ps1 -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"
  Write-Host "Exit: $($result.ExitCode), Duration: $($result.Duration)ms"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    
    [string]$WorkingDirectory = "."
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Parse environment variables
$shouldFail = ($env:OLLAMA_SIM_FAIL -eq 'true')
$exitCode = if ($env:OLLAMA_SIM_EXIT) { [int]$env:OLLAMA_SIM_EXIT } elseif ($shouldFail) { 1 } else { 0 }
$delayMs = if ($env:OLLAMA_SIM_DELAY_MS) { [int]$env:OLLAMA_SIM_DELAY_MS } else { 100 }
$createArtifacts = ($env:OLLAMA_SIM_CREATE_ARTIFACTS -eq 'true')
$platforms = if ($env:OLLAMA_SIM_PLATFORMS) { $env:OLLAMA_SIM_PLATFORMS -split ',' } else { @("2021-32", "2021-64", "2025-64") }

$startTime = Get-Date

# Parse command to determine what type of build is being simulated
$commandLower = $Command.ToLower()
$scriptName = ""
$labviewVersion = "2021"
$bitness = "64"
$repoPath = $WorkingDirectory

# Resolve to absolute path
if (Test-Path $repoPath) {
    $repoPath = (Resolve-Path -LiteralPath $repoPath).Path
}

# Extract script name
if ($Command -match 'scripts[\\/]([\w\-]+)[\\/]([\w\-]+\.ps1)') {
    $scriptName = $matches[2]
}

# Extract LabVIEW version
if ($Command -match '-Package_LabVIEW_Version\s+(\d+)') {
    $labviewVersion = $matches[1]
}

# Extract bitness
if ($Command -match '-SupportedBitness\s+(\d+)') {
    $bitness = $matches[1]
}

# Extract repository path
if ($Command -match '-RepositoryPath\s+([^\s]+)') {
    $repoPath = $matches[1]
}

# Simulate delay
if ($delayMs -gt 0) {
    Start-Sleep -Milliseconds $delayMs
}

# Generate simulated output based on script type
$stdout = ""
$stderr = ""
$artifactPath = ""

switch -Regex ($scriptName) {
    '^Build_Source_Distribution\.ps1$' {
        $artifactName = "LabVIEW_Icon_Editor_SourceDist_LV${labviewVersion}_${bitness}bit.zip"
        $artifactPath = Join-Path $repoPath "builds\source-distribution\$artifactName"
        
        $stdout = @"
[SIMULATION MODE] Building Source Distribution
LabVIEW Version: $labviewVersion
Bitness: ${bitness}-bit
Repository: $repoPath
Target Platform: LV$labviewVersion-$bitness (simulated)

Starting build process...
  - Collecting VIs and dependencies
  - Creating source distribution structure
  - Generating manifest
  - Compressing to ZIP

Build completed successfully!
Artifact: $artifactPath
"@
        
        if ($createArtifacts) {
            $buildDir = Join-Path $repoPath "builds\source-distribution"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
            
            # Create a minimal ZIP file structure - use cross-platform temp directory
            $tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
            $tempDir = Join-Path $tempBase "sim-sd-$(New-Guid)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $manifestContent = @"
{
  "name": "LabVIEW Icon Editor Source Distribution",
  "version": "0.1.0-sim",
  "labview_version": "$labviewVersion",
  "bitness": "$bitness",
  "simulation": true,
  "generated": "$(Get-Date -Format 'o')"
}
"@
            Set-Content -Path (Join-Path $tempDir "manifest.json") -Value $manifestContent
            Set-Content -Path (Join-Path $tempDir "README.txt") -Value "This is a simulated source distribution artifact."
            
            Compress-Archive -Path "$tempDir\*" -DestinationPath $artifactPath -Force
            Remove-Item $tempDir -Recurse -Force
        }
    }
    
    '^Build_Ppl_From_SourceDistribution\.ps1$' {
        $artifactName = "LabVIEW_Icon_Editor_LV${labviewVersion}_${bitness}bit.lvlibp"
        $artifactPath = Join-Path $repoPath "builds\ppl\$artifactName"
        
        $stdout = @"
[SIMULATION MODE] Building PPL from Source Distribution
LabVIEW Version: $labviewVersion
Bitness: ${bitness}-bit
Repository: $repoPath
Target Platform: LV$labviewVersion-$bitness (simulated)

Starting PPL build...
  - Extracting source distribution
  - Loading LabVIEW project (simulated)
  - Compiling PPL
  - Verifying output

Build completed successfully!
Artifact: $artifactPath
"@
        
        if ($createArtifacts) {
            $buildDir = Join-Path $repoPath "builds\ppl"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
            Set-Content -Path $artifactPath -Value "SIMULATED PPL FILE - Not a valid LabVIEW packed library"
        }
    }
    
    default {
        $stdout = @"
[SIMULATION MODE] Generic Build Command
Command: $scriptName
Working Directory: $repoPath
Platform: LV$labviewVersion-$bitness (simulated)

Simulated execution completed.
Exit code: $exitCode
"@
    }
}

# Add failure message if simulating failure
if ($shouldFail) {
    $stderr = @"
[SIMULATION MODE] Simulated Failure
This command was configured to fail via OLLAMA_SIM_FAIL=true

Error Details:
  Exit Code: $exitCode
  Platform: LV$labviewVersion-$bitness
  Script: $scriptName
"@
    $stdout += "`n`n*** BUILD FAILED (Simulated) ***"
}

# Calculate duration
$endTime = Get-Date
$duration = [int]($endTime - $startTime).TotalMilliseconds

# Add simulation indicator to stdout
$stdout = "[SIMULATION MODE ACTIVE]`n" + $stdout

# Return result object
return [PSCustomObject]@{
    ExitCode = $exitCode
    StdOut   = $stdout
    StdErr   = $stderr
    Duration = $duration
}
