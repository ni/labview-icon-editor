param(
  [string]$Path = 'telemetry/stage3-diagnostics.json'
)

BeforeAll {
  if (-not (Test-Path $Path)) {
    throw "Diagnostics file not found: $Path"
  }
  $global:Diag = Get-Content $Path -Raw | ConvertFrom-Json
}

Describe 'Stage3 Diagnostics JSON' {
  It 'has required top-level fields' {
    $Diag | Should -Not -BeNullOrEmpty
    $Diag.PSObject.Properties.Name | Should -Contain 'published'
    $Diag.PSObject.Properties.Name | Should -Contain 'dry_run_forced'
    $Diag.PSObject.Properties.Name | Should -Contain 'webhook_present'
    $Diag.PSObject.Properties.Name | Should -Contain 'summary_path'
    $Diag.PSObject.Properties.Name | Should -Contain 'comment_path'
    $Diag.PSObject.Properties.Name | Should -Contain 'summary_bytes'
    $Diag.PSObject.Properties.Name | Should -Contain 'comment_bytes'
  }

  It 'uses expected value types' {
    $Diag.published | Should -BeOfType 'System.String'
    $Diag.dry_run_forced | Should -BeOfType 'System.String'
    $Diag.webhook_present | Should -BeOfType 'System.String'
    $Diag.summary_path | Should -BeOfType 'System.String'
    $Diag.comment_path | Should -BeOfType 'System.String'
    $Diag.summary_bytes | Should -BeGreaterOrEqual 0
    $Diag.comment_bytes | Should -BeGreaterOrEqual 0
  }

  It 'has chunks object with optional metrics' {
    $Diag.PSObject.Properties.Name | Should -Contain 'chunks'
    $Diag.chunks | Should -Not -BeNullOrEmpty
    if ($Diag.chunks.PSObject.Properties.Name -contains 'count') {
      $Diag.chunks.count | Should -BeGreaterOrEqual 0
    }
    if ($Diag.chunks.PSObject.Properties.Name -contains 'message_length') {
      $Diag.chunks.message_length | Should -BeGreaterOrEqual 0
    }
  }
}

