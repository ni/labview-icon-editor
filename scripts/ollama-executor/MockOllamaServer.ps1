<#
.SYNOPSIS
  Mock Ollama HTTP server for testing Ollama executor without a real Ollama instance.

.DESCRIPTION
  Provides a lightweight HTTP server that simulates Ollama API endpoints (/api/chat, /api/tags).
  Supports configurable scenarios via JSON files for deterministic testing.

.PARAMETER Port
  Port to listen on (default: 11436 to avoid conflict with real Ollama on 11435)

.PARAMETER ScenarioFile
  Path to JSON file defining conversation scenario (optional)

.PARAMETER ResponseDelay
  Artificial delay in milliseconds before responding (default: 10)

.EXAMPLE
  # Start mock server on default port
  $server = Start-Job -ScriptBlock { & scripts/ollama-executor/MockOllamaServer.ps1 }
  # ... run tests ...
  Stop-Job $server; Remove-Job $server

.EXAMPLE
  # Start with specific scenario
  & scripts/ollama-executor/MockOllamaServer.ps1 -ScenarioFile scenarios/successful-build.json -Port 11436
#>

[CmdletBinding()]
param(
    [int]$Port = 11436,
    [string]$ScenarioFile = "",
    [int]$ResponseDelay = 10,
    [int]$MaxRequests = 100  # Stop after this many requests (safety limit)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Load scenario if provided
$scenario = $null
$scenarioTurn = 0
if ($ScenarioFile -and (Test-Path $ScenarioFile)) {
    $scenario = Get-Content $ScenarioFile | ConvertFrom-Json
    Write-Host "[MockOllama] Loaded scenario from $ScenarioFile" -ForegroundColor Cyan
}

# Default model list response
$defaultModels = @{
    models = @(
        @{ name = "llama3-8b-local:latest"; size = 4661211648; modified_at = (Get-Date -Format 'o') }
        @{ name = "llama3-8b-local"; size = 4661211648; modified_at = (Get-Date -Format 'o') }
    )
}

# Default chat responses if no scenario loaded
$defaultResponses = @(
    @{ role = "assistant"; content = '{"run":"pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"}' }
    @{ role = "assistant"; content = '{"done":true,"summary":"Build completed successfully"}' }
)

function Get-ChatResponse {
    param([object]$RequestBody)
    
    if ($scenario -and $scenarioTurn -lt $scenario.turns.Count) {
        $turn = $scenario.turns[$scenarioTurn]
        $script:scenarioTurn++
        return @{
            model   = $RequestBody.model
            created_at = Get-Date -Format 'o'
            message = @{
                role    = "assistant"
                content = $turn.response
            }
            done = $true
        }
    }
    else {
        # Use default responses
        $turnIndex = $scenarioTurn % $defaultResponses.Count
        $script:scenarioTurn++
        return @{
            model   = $RequestBody.model
            created_at = Get-Date -Format 'o'
            message = $defaultResponses[$turnIndex]
            done = $true
        }
    }
}

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "[MockOllama] Listening on http://localhost:$Port" -ForegroundColor Green
Write-Host "[MockOllama] Max requests: $MaxRequests" -ForegroundColor Yellow

$requestCount = 0

try {
    while ($listener.IsListening -and $requestCount -lt $MaxRequests) {
        # Use async pattern with timeout to allow graceful shutdown
        $contextTask = $listener.GetContextAsync()
        
        # Wait with timeout (1 second intervals to check for shutdown)
        $waitTimeout = 1000  # 1 second
        while (-not $contextTask.Wait($waitTimeout)) {
            # Check if we should stop (e.g., max requests reached externally)
            if (-not $listener.IsListening) {
                break
            }
        }
        
        if (-not $listener.IsListening) {
            break
        }
        
        if ($contextTask.IsFaulted) {
            Write-Host "[MockOllama] Listener error, stopping" -ForegroundColor Yellow
            break
        }
        
        $context = $contextTask.Result
        $request = $context.Request
        $response = $context.Response
        
        $requestCount++
        $path = $request.Url.PathAndQuery
        Write-Host "[MockOllama] Request $requestCount : $($request.HttpMethod) $path" -ForegroundColor Gray
        
        # Add artificial delay if configured
        if ($ResponseDelay -gt 0) {
            Start-Sleep -Milliseconds $ResponseDelay
        }
        
        try {
            if ($path -eq "/api/tags") {
                # Return model list
                $responseBody = $defaultModels | ConvertTo-Json -Depth 5
                $response.StatusCode = 200
            }
            elseif ($path -eq "/api/chat") {
                # Parse request body
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $requestBody = $reader.ReadToEnd() | ConvertFrom-Json
                $reader.Close()
                
                # Generate chat response
                $chatResponse = Get-ChatResponse -RequestBody $requestBody
                $responseBody = $chatResponse | ConvertTo-Json -Depth 5
                $response.StatusCode = 200
            }
            else {
                # Unknown endpoint
                $responseBody = '{"error":"Not found"}'
                $response.StatusCode = 404
            }
            
            # Send response
            $response.ContentType = "application/json"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
            
            Write-Host "[MockOllama] Response: $($response.StatusCode)" -ForegroundColor Gray
        }
        catch {
            Write-Host "[MockOllama] Error handling request: $_" -ForegroundColor Red
            try { $response.StatusCode = 500; $response.Close() } catch {}
        }
    }
}
catch {
    # Listener was stopped externally
    Write-Host "[MockOllama] Listener stopped: $_" -ForegroundColor Yellow
}
finally {
    try { $listener.Stop() } catch {}
    try { $listener.Close() } catch {}
    Write-Host "[MockOllama] Stopped after $requestCount requests" -ForegroundColor Yellow
}
