<#
.SYNOPSIS
  Drives a lightweight Ollama executor loop: Ollama proposes PowerShell commands as JSON, this script runs them and feeds results back.

.USAGE
  pwsh -NoProfile -File scripts/ollama-executor/Drive-Ollama-Executor.ps1 `
    -Model llama3-8b-local `
    -RepoPath . `
    -Goal "Build Source Distribution LV2025 64-bit" `
    -MaxTurns 10

.NOTES
  - Ollama must be reachable at OLLAMA_HOST (defaults to http://localhost:11435)
  - Commands are executed with PowerShell from RepoPath
  - Ollama responses must be JSON: {"run":"<cmd>"} or {"done":true,"summary":"..."}
#>
[CmdletBinding()]
param(
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [string]$RepoPath = ".",
    [string]$Goal = "Build Source Distribution LV2025 64-bit",
    [int]$MaxTurns = 10,
    [switch]$StopAfterFirstCommand,
    [string[]]$AllowedRuns = @("pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"),
    [int]$CommandTimeoutSec = 0,
    [string]$SeedAssistantRunCommand
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoFull = (Resolve-Path -LiteralPath $RepoPath).Path
$ollamaHost = if ([string]::IsNullOrWhiteSpace($Endpoint)) { "http://localhost:11435" } else { $Endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) { throw "Model tag is required. Set OLLAMA_MODEL_TAG or pass -Model." }

$seedRunCommand = $null
if (-not [string]::IsNullOrWhiteSpace($SeedAssistantRunCommand)) {
    $trimmed = $SeedAssistantRunCommand.Trim()
    if ($trimmed.Length -gt 0) {
        $seedRunCommand = $trimmed
    }
}
$stopAfterFirst = [bool]$StopAfterFirstCommand
$offlineSeededMode = ($null -ne $seedRunCommand) -and $stopAfterFirst

if ($offlineSeededMode) {
    Write-Host "[executor] Seeded run command provided with StopAfterFirstCommand; running without contacting Ollama." -ForegroundColor Cyan
}
else {
    $healthParams = @{
        Host            = $ollamaHost
        ModelTag        = $Model
        RequireModelTag = $true
    }
    & "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams
}

Write-Host ("Executor targeting {0} with model {1}" -f $ollamaHost, $Model)

$systemPrompt = @"
You are an executor agent. Always respond with JSON only.
Schema:
- To run a PowerShell command: {"run": "<command>"}
- To finish: {"done": true, "summary": "<short status>"}
Use PowerShell syntax. Keep commands short and safe. No prose.
After each run you will receive: {"result":{"exit":<int>,"stdout":"...","stderr":"..."}}
Respond again with either {"run":"..."} or {"done":true,"summary":"..."}.
"@

$messages = @(
    @{ role = "system"; content = $systemPrompt },
    @{ role = "user"; content = "Goal: $Goal" }
)

$seedRunContent = $null
if ($seedRunCommand) {
    $seedRunContent = (@{ run = $seedRunCommand } | ConvertTo-Json -Compress)
}

function Test-CommandAllowed {
    param([string]$Command)
    
    # Normalize: trim whitespace
    $Command = $Command.Trim()
    
    # Block empty or whitespace-only commands
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return "Rejected: empty or whitespace-only command"
    }
    
    # Hard allowlist: exact matches only (case-insensitive)
    if ($AllowedRuns -and -not ($AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() })) {
        return "Rejected: command not in allowlist."
    }

    # Allow only repo scripts invoked via pwsh -NoProfile -File scripts/...
    $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
    if (-not ($Command -match $allowedPattern)) {
        return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
    }

    # Require parameters after the script name (scripts should not be called without arguments)
    if ($Command -match '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\s*$') {
        return "Rejected: script must be called with parameters"
    }

    # Check for path traversal (parent directory references)
    if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
        return "Rejected: path traversal attempt detected (..)"
    }

    # Check for command chaining/injection (expanded to catch more patterns)
    if ($Command -match '[;&|`]' -or $Command -match '\$[\(\{]' -or 
        $Command -match '<<' -or $Command -match '\$\s' -or
        $Command -match '@\{') {  # Block PowerShell hashtable literals
        return "Rejected: command injection attempt detected"
    }

    # Block script injection (HTML/XML/JS tags)
    if ($Command -match '<script[\s>]' -or $Command -match '</script>' -or 
        $Command -match '<img\s' -or $Command -match 'onerror\s*=' -or 
        $Command -match 'onclick\s*=' -or $Command -match 'onload\s*=') {
        return "Rejected: script injection attempt detected"
    }

    # Block privilege escalation attempts
    if ($Command -match '\brunas\b' -or $Command -match '\bsudo\b' -or
        $Command -match '-ExecutionPolicy\s+Bypass' -or $Command -match '-ExecutionPolicy\s+Unrestricted' -or
        $Command -match '\bsu\b' -or $Command -match '\belevate\b') {
        return "Rejected: privilege escalation attempt detected"
    }

    # Block file redirection operators
    if ($Command -match '\s+>\s+' -or $Command -match '\s+>>\s+' -or 
        $Command -match '\s+<\s+' -or $Command -match '\s+2>\s+' -or
        $Command -match '\s+2>>\s+' -or $Command -match '\s+2>&1\s+') {
        return "Rejected: file redirection attempt detected"
    }

    # Block network tools and commands
    if ($Command -match '\bwget\b' -or $Command -match '\bcurl\b' -or 
        $Command -match '\bnc\b' -or $Command -match '\bnetcat\b' -or
        $Command -match '\bnmap\b' -or $Command -match '\btelnet\b' -or
        $Command -match 'Invoke-WebRequest' -or $Command -match 'Invoke-RestMethod') {
        return "Rejected: network tool usage detected"
    }

    # Block SQL injection patterns
    if ($Command -match '\bOR\s+1\s*=\s*1\b' -or $Command -match '\bAND\s+1\s*=\s*1\b' -or
        $Command -match '--\s*$' -or $Command -match '/\*.*\*/' -or
        $Command -match ';--' -or $Command -match 'UNION\s+SELECT') {
        return "Rejected: SQL injection pattern detected"
    }

    # Block encoded/obfuscated content
    if ($Command -match '\b[A-Za-z0-9+/]{50,}={0,2}\b' -or  # Base64-like
        $Command -match '%[0-9A-Fa-f]{2}' -or  # URL encoding
        $Command -match '\\x[0-9A-Fa-f]{2}' -or  # Hex encoding
        $Command -match '\\u[0-9A-Fa-f]{4}') {  # Unicode escapes
        return "Rejected: encoded/obfuscated content detected"
    }

    # Block null bytes and control characters
    if ($Command -match '\x00' -or $Command -match '[\x01-\x08\x0B\x0C\x0E-\x1F]') {
        return "Rejected: null byte or control character detected"
    }

    # Forbid dangerous tokens - case insensitive matching with word boundaries
    $forbiddenPatterns = @(
        '\brm\b', '\bdel\b', 'Remove-Item', 'Format-',
        'Start-Process', '\bshutdown\b', '\breg\b', '\bsc\b',
        'net\s+user', 'net\s+localgroup', '\bicacls\b', '\btakeown\b',
        '\bschtasks\b', '\bat\b', '\bcrontab\b', '\bsystemctl\b',
        '/bin/bash', '/bin/sh', 'cmd\.exe', 'powershell\.exe',
        '\bwget\b', '\bcurl\b', '\bnc\b', '\bnetcat\b', '\bssh\b', '\bftp\b',
        '\btftp\b', '\bscp\b', '\brsync\b', '\bnet\b'
    )
    
    foreach ($pattern in $forbiddenPatterns) {
        if ($Command -match $pattern) {
            return "Rejected: contains forbidden pattern '$pattern'"
        }
    }
    
    return $null
}

function Invoke-Ollama {
    param([array]$Msgs)
    $body = @{
        model    = $Model
        messages = $Msgs
        stream   = $false
    } | ConvertTo-Json -Depth 6
    return Invoke-RestMethod -Uri "$($ollamaHost.TrimEnd('/'))/api/chat" -Method Post -ContentType "application/json" -Body $body
}

for ($turn = 1; $turn -le $MaxTurns; $turn++) {
    $content = $null
    $action = $null

    if ($seedRunContent -and $turn -eq 1) {
        $content = $seedRunContent
        $messages += @{ role = "assistant"; content = $content }
        $action = [pscustomobject]@{ run = $seedRunCommand }
    }
    else {
        $resp = Invoke-Ollama -Msgs $messages
        $content = $resp.message.content
        $messages += @{ role = "assistant"; content = $content }

        try {
            $action = $content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $messages += @{ role = "user"; content = 'Invalid JSON; respond with {"run":"cmd"} or {"done":true}' }
            continue
        }
    }

    $hasDone = ($action -is [psobject] -and $action.PSObject.Properties['done'])
    if ($hasDone -and $action.done) {
        $summary = ""
        if ($action.PSObject.Properties['summary']) {
            $summary = $action.summary
        }

        Write-Host ("[executor] Done: {0}" -f ($summary ?? "")) -ForegroundColor Green
        break
    }

    $hasRun = ($action -is [psobject] -and $action.PSObject.Properties['run'])
    if (-not $hasRun) {
        $messages += @{ role = "user"; content = 'Missing run field; respond with {"run":"cmd"}.' }
        continue
    }

    $cmd = $action.run
    Write-Host ("[executor] Turn {0}: {1}" -f $turn, $cmd)

    $vet = Test-CommandAllowed -Command $cmd
    if ($vet) {
        Write-Host ("[executor] {0}" -f $vet) -ForegroundColor Yellow
        $messages += @{ role = "user"; content = ("Command vetoed: {0}" -f $vet) }
        continue
    }

    # Use cross-platform temp directory via .NET for reliability
    $tempBase = [System.IO.Path]::GetTempPath()
    $stdoutPath = Join-Path $tempBase "ollama-exec-out.txt"
    $stderrPath = Join-Path $tempBase "ollama-exec-err.txt"
    Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

    # Check if simulation mode is enabled
    $simulationMode = ($env:OLLAMA_EXECUTOR_MODE -eq 'sim')
    
    if ($simulationMode) {
        # Use simulation provider instead of real execution
        Write-Host "[executor] SIMULATION MODE - using SimulationProvider" -ForegroundColor Cyan
        try {
            $simResult = & "$PSScriptRoot/SimulationProvider.ps1" -Command $cmd -WorkingDirectory $repoFull
            $exitCode = $simResult.ExitCode
            $stdout = $simResult.StdOut
            $stderr = $simResult.StdErr
        }
        catch {
            $exitCode = -1
            $stdout = ""
            $stderr = "Simulation provider error: $($_.Exception.Message)"
        }
    }
    else {
        # Real execution path (existing code)
        try {
            $proc = Start-Process -FilePath "pwsh" `
                -ArgumentList @("-NoProfile", "-Command", $cmd) `
                -WorkingDirectory $repoFull `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath `
                -NoNewWindow -PassThru

            $timedOut = $false
            if ($CommandTimeoutSec -gt 0) {
                $finished = $proc.WaitForExit($CommandTimeoutSec * 1000)
                if (-not $finished) {
                    $timedOut = $true
                    try { $proc.Kill() } catch {}
                }
            }
            else {
                $proc.WaitForExit() | Out-Null
            }

            $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }
        }
        catch {
            $exitCode = -1
            Set-Content -LiteralPath $stderrPath -Value $_.Exception.Message
        }

        $stdout = if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
        $stderr = if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
        if ($timedOut) {
            $stderr = "Timed out after ${CommandTimeoutSec}s`r`n$stderr"
        }
        Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    }

    $result = @{
        result = @{
            exit   = $exitCode
            stdout = $stdout
            stderr = $stderr
        }
    } | ConvertTo-Json -Depth 5

    Write-Host ("[executor] Exit={0}" -f $exitCode)
    if ($stdout) { Write-Host "[stdout]" ; Write-Host $stdout }
    if ($stderr) { Write-Host "[stderr]" ; Write-Host $stderr }

    $messages += @{ role = "user"; content = $result }

    if ($StopAfterFirstCommand) {
        Write-Host "[executor] StopAfterFirstCommand set; exiting loop." -ForegroundColor Yellow
        break
    }
}

if ($turn -gt $MaxTurns) {
    Write-Host "[executor] Max turns reached without completion." -ForegroundColor Yellow
    exit 1
}

# Executor completed successfully
exit 0
