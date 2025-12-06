Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Branch protection matches documented expectations' {
  BeforeAll {
    $repo = 'LabVIEW-Community-CI-CD/x-cli'
    $expectPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')) 'docs/settings/branch-protection.expected.json'
    if (-not (Test-Path $expectPath)) {
      throw "Expectation file not found: $expectPath"
    }
    $Expected = Get-Content -LiteralPath $expectPath -Raw | ConvertFrom-Json
    $Script = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' 'ghops' 'tools')) 'branch-protection-awareness.ps1'
    if (-not (Test-Path $Script)) { throw "branch-protection-awareness.ps1 not found." }

    function Invoke-BranchAwareness([string] $branch) {
      $args = @('-Repo', $repo, '-Branch', $branch, '-Json')
      try {
        $cmd = @('-NoProfile', '-File', $Script) + $args
        $output = & pwsh @cmd 2>$null
        if ($LASTEXITCODE -ne 0) {
          Write-Warning "branch-protection-awareness failed for $branch"
          return $null
        }
        return $output | ConvertFrom-Json
      }
      catch {
        Write-Warning ("branch-protection-awareness threw for {0}: {1}" -f $branch, $_.Exception.Message)
        return $null
      }
    }

    $Global:BP_Context = [pscustomobject]@{
      Repo = $repo
      Expected = $Expected
      ActualBranches = @{}
      ActualRulesets = @()
    }

    foreach ($branch in $Expected.branches) {
      $actual = Invoke-BranchAwareness -branch $branch.name
      if ($null -eq $actual) {
        $Global:BP_Context.ActualBranches[$branch.name] = $null
      } else {
        $Global:BP_Context.ActualBranches[$branch.name] = $actual
      }
    }

    # Fetch rulesets via gh api if available
    $useGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
    if ($useGh) {
      try {
        $Global:BP_Context.ActualRulesets = gh api "repos/$repo/rulesets" | ConvertFrom-Json
      } catch {
        Write-Warning "gh api repos/$repo/rulesets failed: $($_.Exception.Message)"
        $Global:BP_Context.ActualRulesets = @()
      }
    } else {
      Write-Warning 'gh CLI not available; ruleset comparison skipped.'
      $Global:BP_Context.ActualRulesets = @()
    }
  }

  It 'has branch data for each documented branch' {
    foreach ($branch in $Global:BP_Context.Expected.branches) {
      $actual = $Global:BP_Context.ActualBranches[$branch.name]
      if ($null -eq $actual) {
        Set-ItResult -Inconclusive -Because "Failed to retrieve protection for $($branch.name). Ensure gh auth login or set GH_TOKEN."
        return
      }
      $actual.effective_required_checks | Sort-Object | Should -BeExactly ($branch.expected_required_checks | Sort-Object)
      [bool]$actual.classic.strict | Should -Be $branch.strict
    }
  }

  It 'has matching ruleset expectations when gh is available' {
    if ($Global:BP_Context.ActualRulesets.Count -eq 0) {
      Set-ItResult -Inconclusive -Because 'Rulesets not retrieved (gh unavailable or API failure).'
      return
    }
    foreach ($expectedRs in $Global:BP_Context.Expected.rulesets) {
      $actualRs = $Global:BP_Context.ActualRulesets | Where-Object { $_.name -eq $expectedRs.name }
      if (-not $actualRs) {
        throw "Expected ruleset '$($expectedRs.name)' not found."
      }
      $actualRs = $actualRs | Select-Object -First 1
      $actualDetail = gh api "repos/$($Global:BP_Context.Repo)/rulesets/$($actualRs.id)" | ConvertFrom-Json
      $actualDetail.enforcement | Should -Be $expectedRs.enforcement
      $actualDetail.target | Should -Be $expectedRs.target
      ($actualDetail.conditions.ref_name.include | Sort-Object) | Should -BeExactly ($expectedRs.include | Sort-Object)
      $actualChecks = @()
      foreach ($rule in $actualDetail.rules) {
        if ($rule.type -eq 'required_status_checks') {
          $actualChecks += ($rule.parameters.required_status_checks | ForEach-Object { $_.context })
        }
      }
      ($actualChecks | Sort-Object) | Should -BeExactly ($expectedRs.expected_required_checks | Sort-Object)
    }
  }

  It 'applies expected checks to feature branches' {
    $expected = $Global:BP_Context.Expected
    if (-not $expected.feature_branch_patterns -or -not $expected.feature_expected_required_checks) {
      Set-ItResult -Inconclusive -Because 'Feature branch patterns/checks not documented in expected settings.'
      return
    }

    foreach ($pattern in $expected.feature_branch_patterns) {
      if (-not ($pattern -is [string]) -or [string]::IsNullOrWhiteSpace($pattern)) { continue }
      if (-not $pattern.StartsWith('refs/heads/')) { continue }

      # Derive a sample branch name from the ref pattern
      $branch = $pattern.Substring(11) # strip 'refs/heads/'
      $branch = $branch -replace '\*+', 'smoke'
      if ($branch.EndsWith('/')) { $branch += 'smoke' }

      $actual = Invoke-BranchAwareness -branch $branch
      if ($null -eq $actual) {
        Set-ItResult -Inconclusive -Because "Failed to evaluate feature branch '$branch'. Ensure gh auth login or set GH_TOKEN."
        return
      }

      ($actual.effective_required_checks | Sort-Object) | Should -BeExactly ($expected.feature_expected_required_checks | Sort-Object)
    }
  }
}

