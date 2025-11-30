Param(
  [Parameter(Mandatory=$true)][string]$Repo,          # owner/name, e.g., LabVIEW-Community-CI-CD/gha-pr-comment-and-artifacts
  [string]$Version = 'v1.0.0',
  [string]$Branch = 'main',
  [ValidateSet('both','post','artifacts','telemetry')][string]$Mode = 'both',
  [switch]$DryRun,
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Run([string]$cmd, [switch]$allowFail) {
  Write-Host "» $cmd"
  if ($DryRun) { return }
  $ec = 0
  $out = & pwsh -NoProfile -Command $cmd 2>&1; $ec = $LASTEXITCODE
  if (-not $allowFail -and $ec -ne 0) { throw "Command failed ($ec): $cmd`n$out" }
  return $out
}

function Ensure-GhAuth {
  try {
    $out = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh not authenticated" }
    Write-Host ($out -join "`n")
  } catch { throw "GitHub CLI (gh) not authenticated. Run: gh auth login" }
}

function Copy-Rel($src, $dst) {
  if (-not (Test-Path -LiteralPath $src)) { return }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent -Path $dst) | Out-Null
  Copy-Item -Path $src -Destination $dst -Recurse -Force
}

if (-not $DryRun) { Ensure-GhAuth }

# Resolve local paths
$root = Resolve-Path (Join-Path $PWD '.')
$tmp = Join-Path $env:TEMP ("action-repo-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# Create or verify remote repo
$owner, $name = $Repo.Split('/')
if (-not $name) { throw "Repo must be 'owner/name'" }
Write-Host "Target repo: $Repo"

$exists = $true
if (-not $DryRun) {
  $exists = $false
  try { & gh repo view $Repo 1>$null 2>$null; if ($LASTEXITCODE -eq 0) { $exists = $true } } catch {}
  if (-not $exists) {
    Run "gh repo create $Repo --public --description 'Label-gated PR comments + artifacts metadata loader composites' --disable-wiki" $false | Out-Null
  }
}

# Clone
Run "gh repo clone $Repo `"$tmp`" -- -q" $false | Out-Null
$dst = $tmp

# Prepare content
Write-Host "Copying composite actions and helpers…"
Copy-Rel (Join-Path $root '.github\actions\post-comment-or-artifact') (Join-Path $dst '.github\actions\post-comment-or-artifact')
Copy-Rel (Join-Path $root '.github\actions\load-artifacts-meta') (Join-Path $dst '.github\actions\load-artifacts-meta')
Copy-Rel (Join-Path $root 'scripts\ghops\tools\post-comment-or-artifact.ps1') (Join-Path $dst 'scripts\ghops\tools\post-comment-or-artifact.ps1')
Copy-Rel (Join-Path $root 'scripts\ghops\tools\post-comment-or-artifact.sh') (Join-Path $dst 'scripts\ghops\tools\post-comment-or-artifact.sh')
Copy-Rel (Join-Path $root 'scripts\ghops\tools\update-external-actions-readme.ps1') (Join-Path $dst 'scripts\ghops\tools\update-external-actions-readme.ps1')
Copy-Rel (Join-Path $root 'scripts\ghops\tools\update-external-actions-readme.sh') (Join-Path $dst 'scripts\ghops\tools\update-external-actions-readme.sh')
Copy-Rel (Join-Path $root '.github\workflows\post-comment-or-artifact-ci.yml') (Join-Path $dst '.github\workflows\post-comment-or-artifact-ci.yml')
Copy-Rel (Join-Path $root '.github\workflows\action-pr-target-ci.yml') (Join-Path $dst '.github\workflows\action-pr-target-ci.yml')
Copy-Rel (Join-Path $root '.github\workflows\post-comment-or-artifact-release.yml') (Join-Path $dst '.github\workflows\post-comment-or-artifact-release.yml')
Copy-Rel (Join-Path $root '.github\workflows\codeql.yml') (Join-Path $dst '.github\workflows\codeql.yml')

# Prune content based on Mode
if ($Mode -eq 'post') {
  $rm = Join-Path $dst '.github\actions\load-artifacts-meta'
  if (Test-Path $rm) { Remove-Item -Recurse -Force $rm }
  # Remove workflows that depend on artifacts loader (PR target CI).
  $w = Join-Path $dst '.github\workflows\action-pr-target-ci.yml'
  if (Test-Path $w) { Remove-Item -Force $w }
} elseif ($Mode -eq 'artifacts') {
  $rm = Join-Path $dst '.github\actions\post-comment-or-artifact'
  if (Test-Path $rm) { Remove-Item -Recurse -Force $rm }
  # Replace workflows with a minimal artifacts CI
  $wfDir = Join-Path $dst '.github\workflows'
  New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
  $wfPath = Join-Path $wfDir 'artifacts-meta-ci.yml'
  @'
name: Artifacts Metadata Action CI

on:
  push:
    paths:
      - '.github/actions/load-artifacts-meta/**'
      - '.github/workflows/artifacts-meta-ci.yml'
  pull_request:
    paths:
      - '.github/actions/load-artifacts-meta/**'

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
    steps:
      - uses: actions/checkout@v4
      - name: Run artifacts loader (dry-run)
        id: meta
        uses: ./.github/actions/load-artifacts-meta
        with:
          prefer_cache: true
          output_path: telemetry/artifacts_meta.json
      - name: Validate outputs
        run: |
          test -f telemetry/artifacts_meta.json || { echo 'missing output'; exit 1; }
          echo "count=$(jq -r '.artifacts|length' telemetry/artifacts_meta.json)"
'@ | Out-File -Encoding utf8NoBOM -FilePath $wfPath
  # Remove post-only CI
  $w1 = Join-Path $dst '.github\workflows\post-comment-or-artifact-ci.yml'
  if (Test-Path $w1) { Remove-Item -Force $w1 }
  $w2 = Join-Path $dst '.github\workflows\action-pr-target-ci.yml'
  if (Test-Path $w2) { Remove-Item -Force $w2 }
}

elseif ($Mode -eq 'telemetry') {
  # Create telemetry publish action structure
  $actDir = Join-Path $dst '.github\actions\telemetry-publish'
  New-Item -ItemType Directory -Force -Path $actDir | Out-Null
  $actionYml = @'
name: "Telemetry Publish"
description: "Publishes telemetry summary with robust fallback + history + diagnostics"
inputs:
  current:
    description: "Path to telemetry/summary.json"
    required: true
  discord:
    description: "Discord webhook URL (optional; default from env DISCORD_WEBHOOK_URL)"
    required: false
  history-dir:
    description: "History directory"
    required: false
    default: "telemetry/history"
  manifest:
    description: "Path to manifest.json (optional)"
    required: false
  prefer-attachment:
    description: "Prefer attachment over chunking"
    required: false
    default: false
  emit-chunk-diagnostics:
    description: "Emit chunk diagnostics JSON"
    required: false
    default: true
  comment-path:
    description: "Write PR-friendly comment markdown"
    required: false
    default: ""
runs:
  using: "composite"
  steps:
    - name: Run telemetry publish
      shell: pwsh
      env:
        DISCORD_WEBHOOK_URL: ${{ inputs.discord }}
      run: |
        pwsh -NoProfile -File scripts/telemetry-publish.ps1 `
          -Current '${{ inputs.current }}' `
          -Discord ${env:DISCORD_WEBHOOK_URL} `
          -HistoryDir '${{ inputs["history-dir"] }}' `
          -Manifest '${{ inputs.manifest }}' `
          $(@{True='-PreferAttachment'}[[bool]::Parse('${{ inputs["prefer-attachment"] }}')]) `
          $(@{True='-EmitChunkDiagnostics'}[[bool]::Parse('${{ inputs["emit-chunk-diagnostics"] }}')]) `
          -CommentPath '${{ inputs["comment-path"] }}'
'@
  $actionYml | Out-File -Encoding utf8NoBOM -FilePath (Join-Path $actDir 'action.yml')
  # Copy the telemetry script
  Copy-Rel (Join-Path $root 'scripts\telemetry-publish.ps1') (Join-Path $dst 'scripts\telemetry-publish.ps1')

  # CI workflow
  $wfDir = Join-Path $dst '.github\workflows'
  New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
  $wf = @'
name: Telemetry Publish CI

on:
  push:
    paths:
      - '.github/actions/telemetry-publish/**'
      - 'scripts/telemetry-publish.ps1'
      - '.github/workflows/telemetry-publish-ci.yml'
  pull_request:
    paths:
      - '.github/actions/telemetry-publish/**'
      - 'scripts/telemetry-publish.ps1'

jobs:
  smoke:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Prepare summary
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Force -Path telemetry | Out-Null
          '{"pass":1,"fail":0,"skipped":0,"duration_seconds":0.1}' | Out-File -Encoding utf8NoBOM -FilePath telemetry/summary.json
      - name: Run action (dry-run fallback)
        uses: ./.github/actions/telemetry-publish
        with:
          current: telemetry/summary.json
          history-dir: telemetry/history
          emit-chunk-diagnostics: true
'@
  $wf | Out-File -Encoding utf8NoBOM -FilePath (Join-Path $wfDir 'telemetry-publish-ci.yml')

  # Release workflow to move v1
  $rel = @'
name: Action Release (telemetry-publish)

on:
  push:
    tags:
      - 'v1.*'

permissions:
  contents: write

jobs:
  bump-v1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Move v1 tag
        run: |
          tag="${GITHUB_REF_NAME}"
          git tag -fa v1 -m "rolling v1 -> $tag" "$tag"
          git push origin v1 --force
'@
  $rel | Out-File -Encoding utf8NoBOM -FilePath (Join-Path $wfDir 'telemetry-publish-release.yml')
}

# Add README updater workflow (conditional on Marketplace vars)
$wfUpd = Join-Path $dst '.github\workflows\update-readme-on-release.yml'
@'
name: Update README on release

on:
  release:
    types: [published]

permissions:
  contents: write
  actions: read

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update README (if slugs present)
        if: ${{ vars.MARKETPLACE_POST_SLUG != '' || vars.MARKETPLACE_ARTIFACTS_SLUG != '' }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          MARKETPLACE_POST_SLUG: ${{ vars.MARKETPLACE_POST_SLUG }}
          MARKETPLACE_ARTIFACTS_SLUG: ${{ vars.MARKETPLACE_ARTIFACTS_SLUG }}
        run: |
          bash scripts/ghops/tools/update-external-actions-readme.sh \
            --repo "$GITHUB_REPOSITORY" \
            --post-slug "${MARKETPLACE_POST_SLUG}" \
            --artifacts-slug "${MARKETPLACE_ARTIFACTS_SLUG}" \
            --max-wait 30 --quiet
'@ | Out-File -Encoding utf8NoBOM -FilePath $wfUpd

# Adjust badges in composite README if present
foreach($readme in @(
  (Join-Path $dst '.github\actions\post-comment-or-artifact\README.md'),
  (Join-Path $dst '.github\actions\load-artifacts-meta\README.md')
)){
  if (Test-Path $readme) {
    $text = Get-Content -LiteralPath $readme -Raw
    $text = $text -replace 'LabVIEW-Community-CI-CD/x-cli', $Repo
    $text | Out-File -Encoding utf8NoBOM -FilePath $readme
  }
}

# Minimal root README
$rootReadme = Join-Path $dst 'README.md'
if (-not (Test-Path $rootReadme)) {
  @(
    "# PR Comment + Artifacts Composites", "",
    "This repository publishes two composite actions:",
    "- action-post: label-gated PR comments", "- action-artifacts: load normalized run artifacts metadata",
    "",
    "Pin by major: uses: $Repo/action-post@v1", ""
  ) -join "`n" | Out-File -Encoding utf8NoBOM -FilePath $rootReadme
}

if ($DryRun) {
  Write-Host "[dry-run] Skipping git push and tag operations. Repo staged at: $dst"
  exit 0
}

Push-Location $dst
try {
  Run "git config user.name 'github-actions'" $false | Out-Null
  Run "git config user.email 'github-actions@users.noreply.github.com'" $false | Out-Null
  Run "git add ." $false | Out-Null
  $status = & git status --porcelain
  if (-not [string]::IsNullOrWhiteSpace(($status -join ''))) {
    Run "git commit -m 'feat: initial composites (post, artifacts)'" $false | Out-Null
    Run "git push origin HEAD:$Branch" $false | Out-Null
  } else {
    Write-Host "Nothing to commit; continuing to tagging"
  }
  # Tag and move v1
  Run "git tag $Version -f" $true | Out-Null
  Run "git push origin $Version --force" $true | Out-Null
  Run "git tag -fa v1 -m 'rolling v1 -> $Version' $Version" $false | Out-Null
  Run "git push origin v1 --force" $false | Out-Null
  # Create release if missing
  Run "gh release view $Version || gh release create $Version --title '$Version' --generate-notes" $true | Out-Null
} finally { Pop-Location }

Write-Host "Done. Consume via:"
Write-Host "- uses: $Repo/action-post@v1"
Write-Host "- uses: $Repo/action-artifacts@v1"
