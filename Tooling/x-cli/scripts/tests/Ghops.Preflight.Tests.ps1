Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Ghops token preflight and JSON quiet' {

  It 'annotations helper fails fast with REST missing token' {
    $ps1 = Join-Path $PSScriptRoot '..' 'ghops' 'tools' 'get-run-annotations.ps1'
    Push-Location (Resolve-Path (Join-Path $PSScriptRoot '..' '..'))
    try {
      $cmd = "& pwsh -NoProfile -File `"$ps1`" -Repo 'owner/name' -RunId 123 -Transport rest -Json"
      $out = & pwsh -NoProfile -Command $cmd 2>&1
      $LASTEXITCODE | Should -Be 1
      ($out -join "`n") | Should -Match 'Token check failed|GH_TOKEN/GITHUB_TOKEN not set'
    } finally {
      Pop-Location
    }
  }

  It 'post-comment helper returns JSON only and no warnings when -Json and no token' {
    $ps1 = Join-Path $PSScriptRoot '..' 'ghops' 'tools' 'post-comment-or-artifact.ps1'
    # Create a temporary comment file
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value 'hello' -Encoding utf8NoBOM -NoNewline
    try {
      $outPath = Join-Path $env:TEMP ("pester-out-" + [guid]::NewGuid().ToString('N'))
      $cmd = "`$env:GITHUB_OUTPUT = '$outPath'; & pwsh -NoProfile -File `"$ps1`" -LabelName test -CommentPath `"$tmp`" -Repo owner/name -PrNumber 1 -Token '' -Json"
      $out = & pwsh -NoProfile -Command $cmd 2>&1
      $LASTEXITCODE | Should -Be 0
      $text = ($out -join "").Trim()
      # Should be a single JSON object and not include 'warning:'
      $text | Should -Not -Match 'warning:'
      $obj = $text | ConvertFrom-Json
      $obj.posted | Should -BeFalse
      # Reason may be 'label-missing' or 'no-token' depending on inputs; ensure field exists
      $obj.PSObject.Properties.Name | Should -Contain 'reason'
    } finally {
      Remove-Item $tmp -ErrorAction SilentlyContinue
      if (Test-Path $outPath) { Remove-Item $outPath -ErrorAction SilentlyContinue }
    }
  }
}
