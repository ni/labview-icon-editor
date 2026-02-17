#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [long]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$OutJson,

    [Parameter(Mandatory = $false)]
    [string]$OutMarkdown,

    [Parameter(Mandatory = $false)]
    [string]$SignaturePath,

    [Parameter(Mandatory = $false)]
    [string]$FixturePath,

    [switch]$FailOnUnknown
)

$ErrorActionPreference = 'Stop'

function Resolve-CiDebtRepoRoot {
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..\..\..') -ErrorAction Stop).Path
}

function Resolve-CiDebtRepoName {
    param(
        [string]$RepoOverride,
        [string]$RepoRoot
    )

    $resolverScript = Join-Path $RepoRoot 'Tooling\Resolve-GitHubRepo.ps1'
    if (-not (Test-Path -Path $resolverScript)) {
        throw "Repository resolver script not found at $resolverScript"
    }

    $resolved = if (-not [string]::IsNullOrWhiteSpace($RepoOverride)) {
        & $resolverScript -Repo $RepoOverride -RepoRoot $RepoRoot
    } else {
        & $resolverScript -RepoRoot $RepoRoot
    }
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolved)) {
        throw "Unable to resolve repository via Tooling/Resolve-GitHubRepo.ps1."
    }

    return $resolved.Trim()
}

function Resolve-CiDebtOutPath {
    param(
        [string]$RepoRoot,
        [long]$RunIdentifier,
        [string]$OutPath,
        [string]$Extension
    )

    if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
        return $OutPath
    }

    $fileName = if ($RunIdentifier -gt 0) { "{0}.analysis.{1}" -f $RunIdentifier, $Extension } else { "latest.analysis.{0}" -f $Extension }
    return Join-Path $RepoRoot ("TestResults\agent-logs\ci-debt\{0}" -f $fileName)
}

function Initialize-CiDebtParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
}

function Get-CiDebtSignatureTable {
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        throw "CI debt signature file not found at $Path"
    }

    $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "CI debt signature file is empty at $Path"
    }

    $doc = $raw | ConvertFrom-Json -ErrorAction Stop
    $signatureList = @($doc.signatures)
    if ($signatureList.Count -eq 0) {
        throw "CI debt signature file contains no signatures at $Path"
    }

    foreach ($signature in $signatureList) {
        if ([string]::IsNullOrWhiteSpace([string]$signature.id)) {
            throw "Signature entry is missing required field 'id'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$signature.job)) {
            throw "Signature '$($signature.id)' is missing required field 'job'."
        }
        if (@($signature.containsAny).Count -eq 0) {
            throw "Signature '$($signature.id)' is missing required field 'containsAny'."
        }
    }

    return $signatureList
}

function Get-CiDebtRunFromGh {
    param(
        [string]$RepoName,
        [long]$RunIdentifier
    )

    if ($RunIdentifier -le 0) {
        throw "RunId must be provided when FixturePath is not used."
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "gh CLI is required to analyze live CI run data."
    }

    $runJson = gh run view $RunIdentifier --repo $RepoName --json databaseId,workflowName,name,url,status,conclusion,event,headBranch,headSha,createdAt,updatedAt,jobs
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($runJson)) {
        throw "Failed to read run metadata for run $RunIdentifier in $RepoName."
    }

    $runData = $runJson | ConvertFrom-Json -ErrorAction Stop
    $jobs = @($runData.jobs)
    foreach ($job in $jobs) {
        $jobId = [long]$job.databaseId
        $jobLog = ''
        if ($jobId -gt 0) {
            try {
                $logOutput = gh run view $RunIdentifier --repo $RepoName --job $jobId --log 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $jobLog = if ($logOutput -is [array]) { $logOutput -join [Environment]::NewLine } else { [string]$logOutput }
                } else {
                    $jobLog = "Unable to fetch job log (exit code $LASTEXITCODE)."
                }
            } catch {
                $jobLog = "Unable to fetch job log: $($_.Exception.Message)"
            }
        }
        Add-Member -InputObject $job -NotePropertyName log -NotePropertyValue $jobLog -Force
    }

    return [pscustomobject]@{
        run = $runData
        jobs = $jobs
    }
}

function Get-CiDebtRunFromFixture {
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        throw "Fixture file not found at $Path"
    }

    $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Fixture file is empty at $Path"
    }

    $fixture = $raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $fixture.run) {
        throw "Fixture file missing required root property 'run'."
    }
    if (-not $fixture.jobs) {
        throw "Fixture file missing required root property 'jobs'."
    }

    return [pscustomobject]@{
        run = $fixture.run
        jobs = @($fixture.jobs)
    }
}

function Find-CiDebtSignatureMatch {
    param(
        [string]$JobName,
        [string]$LogText,
        [object[]]$Signatures
    )

    $jobKey = [string]$JobName
    $jobLower = $jobKey.ToLowerInvariant()
    $logLower = [string]$LogText
    $logLower = $logLower.ToLowerInvariant()

    foreach ($signature in $Signatures) {
        $signatureJob = [string]$signature.job
        if ([string]::IsNullOrWhiteSpace($signatureJob)) {
            continue
        }
        if ($jobLower -notlike "*$($signatureJob.ToLowerInvariant())*") {
            continue
        }

        $fragments = @($signature.containsAny) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $matched = New-Object System.Collections.Generic.List[string]
        foreach ($fragment in $fragments) {
            $fragmentText = [string]$fragment
            if ($logLower.Contains($fragmentText.ToLowerInvariant())) {
                $matched.Add($fragmentText) | Out-Null
            }
        }

        if ($matched.Count -gt 0) {
            return [pscustomobject]@{
                Signature = $signature
                MatchedFragments = @($matched)
            }
        }
    }

    return $null
}

function New-CiDebtMarkdown {
    param(
        [object]$Run,
        [object[]]$Incidents,
        [int]$UnknownCount
    )

    $runId = [string]$Run.databaseId
    $runUrl = [string]$Run.url
    $workflowName = [string]$Run.workflowName
    if ([string]::IsNullOrWhiteSpace($workflowName)) {
        $workflowName = [string]$Run.name
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## CI Debt Analysis ($runId)") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Workflow: $workflowName") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($runUrl)) {
        $lines.Add("- Run URL: $runUrl") | Out-Null
    }
    $lines.Add("- Conclusion: $($Run.conclusion)") | Out-Null
    $lines.Add("- Open incidents: $($Incidents.Count)") | Out-Null
    $lines.Add("- Unknown incidents: $UnknownCount") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('### Incident Table') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Job | Signature | Classification | Severity |') | Out-Null
    $lines.Add('| --- | --- | --- | --- |') | Out-Null
    foreach ($incident in $Incidents) {
        $lines.Add("| $($incident.job) | $($incident.id) | $($incident.classification) | $($incident.severity) |") | Out-Null
    }
    if ($Incidents.Count -eq 0) {
        $lines.Add('| <none> | <none> | <none> | <none> |') | Out-Null
    }
    $lines.Add('') | Out-Null

    $signatureIds = @($Incidents | ForEach-Object { $_.id })
    $hasLint = ($signatureIds -contains 'powershell-lint.git-missing') -or ($signatureIds -contains 'powershell-lint.new-issues')
    $hasVerify = $signatureIds -contains 'verify-iepaths.setup-failed'
    $hasPipeline = $signatureIds -contains 'pipeline-contract.cascade-failure'

    $lines.Add('### Issue #74 Checklist') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add(("{0} Lint fix (powershell-lint.*)" -f ($(if ($hasLint) { '[ ]' } else { '[x]' })))) | Out-Null
    $lines.Add(("{0} Verify IE Paths 64/32 fix (verify-iepaths.setup-failed)" -f ($(if ($hasVerify) { '[ ]' } else { '[x]' })))) | Out-Null
    $lines.Add(("{0} Pipeline Contract fix (pipeline-contract.cascade-failure)" -f ($(if ($hasPipeline) { '[ ]' } else { '[x]' })))) | Out-Null
    $lines.Add(("{0} Hardening/tests updated for new signatures" -f ($(if ($UnknownCount -gt 0) { '[ ]' } else { '[x]' })))) | Out-Null
    $lines.Add('') | Out-Null

    if ($UnknownCount -gt 0) {
        $lines.Add('### Unknown Incidents') | Out-Null
        $lines.Add('') | Out-Null
        $unknownIncidents = @($Incidents | Where-Object { $_.classification -eq 'unknown' })
        foreach ($incident in $unknownIncidents) {
            $lines.Add("- $($incident.job): no signature matched.") | Out-Null
        }
        $lines.Add('') | Out-Null
    }

    $lines.Add('<!-- ci-debt-train:v1 -->') | Out-Null
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Invoke-CiDebtAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Repo,

        [Parameter(Mandatory = $false)]
        [long]$RunId,

        [Parameter(Mandatory = $false)]
        [string]$OutJson,

        [Parameter(Mandatory = $false)]
        [string]$OutMarkdown,

        [Parameter(Mandatory = $false)]
        [string]$SignaturePath,

        [Parameter(Mandatory = $false)]
        [string]$FixturePath,

        [switch]$FailOnUnknown
    )

    $repoRoot = Resolve-CiDebtRepoRoot
    $repoName = Resolve-CiDebtRepoName -RepoOverride $Repo -RepoRoot $repoRoot
    $resolvedSignaturePath = if (-not [string]::IsNullOrWhiteSpace($SignaturePath)) {
        $SignaturePath
    } else {
        Join-Path $repoRoot 'Tooling\agents\ci-debt\signatures.json'
    }
    $signatures = Get-CiDebtSignatureTable -Path $resolvedSignaturePath

    $runPayload = if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        Get-CiDebtRunFromFixture -Path $FixturePath
    } else {
        Get-CiDebtRunFromGh -RepoName $repoName -RunIdentifier $RunId
    }

    $run = $runPayload.run
    $jobs = @($runPayload.jobs)
    $actionableConclusions = @('failure', 'cancelled', 'timed_out', 'action_required', 'startup_failure')
    $failedJobs = @(
        $jobs | Where-Object {
            $conclusion = [string]$_.conclusion
            -not [string]::IsNullOrWhiteSpace($conclusion) -and $actionableConclusions -contains $conclusion.ToLowerInvariant()
        }
    )

    $incidents = New-Object System.Collections.Generic.List[object]
    foreach ($job in $failedJobs) {
        $jobName = [string]$job.name
        $jobLog = [string]$job.log
        $match = Find-CiDebtSignatureMatch -JobName $jobName -LogText $jobLog -Signatures $signatures

        if ($match) {
            $signature = $match.Signature
            $incidents.Add([pscustomobject]@{
                id = [string]$signature.id
                job = $jobName
                job_id = [long]$job.databaseId
                status = [string]$job.status
                conclusion = [string]$job.conclusion
                classification = [string]$signature.classification
                severity = [string]$signature.severity
                matched_fragments = @($match.MatchedFragments)
                recommended_actions = @($signature.recommendedActions)
                preventive_check = [string]$signature.preventiveCheck
            }) | Out-Null
            continue
        }

        $incidents.Add([pscustomobject]@{
            id = 'unknown'
            job = $jobName
            job_id = [long]$job.databaseId
            status = [string]$job.status
            conclusion = [string]$job.conclusion
            classification = 'unknown'
            severity = 'unknown'
            matched_fragments = @()
            recommended_actions = @(
                'Add a deterministic signature in ci-debt/signatures.json.',
                'Add a fixture and playbook entry in the remediation PR.'
            )
            preventive_check = 'CI Debt Policy Gate / Root Cause Contract'
        }) | Out-Null
    }

    $unknownIncidents = @($incidents | Where-Object { $_.classification -eq 'unknown' })
    $unknownCount = $unknownIncidents.Count
    $incidentArray = $incidents.ToArray()
    $openSignatureIds = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($incident in $incidentArray) {
        $incidentId = [string]$incident.id
        if (-not [string]::IsNullOrWhiteSpace($incidentId) -and $incidentId -ne 'unknown') {
            $openSignatureIds.Add($incidentId) | Out-Null
        }
    }
    $openSignatureCount = $openSignatureIds.Count

    $runIdentifier = [long]$run.databaseId
    $resolvedJson = Resolve-CiDebtOutPath -RepoRoot $repoRoot -RunIdentifier $runIdentifier -OutPath $OutJson -Extension 'json'
    $resolvedMarkdown = Resolve-CiDebtOutPath -RepoRoot $repoRoot -RunIdentifier $runIdentifier -OutPath $OutMarkdown -Extension 'md'
    Initialize-CiDebtParentDirectory -Path $resolvedJson
    Initialize-CiDebtParentDirectory -Path $resolvedMarkdown

    $analysis = [ordered]@{
        schema_version = '1.0'
        generated_utc = (Get-Date).ToUniversalTime().ToString('o')
        repository = $repoName
        run = [ordered]@{
            id = $runIdentifier
            workflow_name = [string]$run.workflowName
            name = [string]$run.name
            url = [string]$run.url
            status = [string]$run.status
            conclusion = [string]$run.conclusion
            event = [string]$run.event
            head_branch = [string]$run.headBranch
            head_sha = [string]$run.headSha
            created_at = [string]$run.createdAt
            updated_at = [string]$run.updatedAt
        }
        failed_job_count = $failedJobs.Count
        incident_count = $incidentArray.Count
        unknown_incident_count = $unknownCount
        open_signature_count = $openSignatureCount
        incidents = $incidentArray
    }

    $analysis | ConvertTo-Json -Depth 10 | Out-File -FilePath $resolvedJson -Encoding utf8
    $markdown = New-CiDebtMarkdown -Run $run -Incidents $incidentArray -UnknownCount $unknownCount
    $markdown | Out-File -FilePath $resolvedMarkdown -Encoding utf8

    Write-Host ("CI debt analysis written to: {0}" -f $resolvedJson)
    Write-Host ("CI debt markdown written to: {0}" -f $resolvedMarkdown)
    Write-Host ("Incidents: {0}; Unknown: {1}" -f $incidentArray.Count, $unknownCount)

    if ($FailOnUnknown -and $unknownCount -gt 0) {
        throw ("Unknown CI debt incidents detected: {0}" -f $unknownCount)
    }

    return [pscustomobject]@{
        Repo = $repoName
        RunId = $runIdentifier
        OutJson = $resolvedJson
        OutMarkdown = $resolvedMarkdown
        IncidentCount = $incidentArray.Count
        UnknownIncidentCount = $unknownCount
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CiDebtAnalysis @PSBoundParameters | Out-Null
}
