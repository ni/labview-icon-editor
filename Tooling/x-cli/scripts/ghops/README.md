# GitHub Ops Helpers (gh CLI)

These helpers wrap the GitHub CLI (`gh`) so agents can push branches, open PRs,
watch workflow runs, rerun failures, download artifacts, and tag releases for
`LabVIEW-Community-CI-CD/x-cli` with minimal friction.

Prereqs
- `gh` installed and authenticated: `gh auth login`
- `git` configured with SSH (recommended)
- `GITHUB_REPOSITORY=LabVIEW-Community-CI-CD/x-cli` (auto-detected if missing)

## Quick commands (POSIX)

Open a PR from develop
```bash
scripts/ghops/pr-create.sh my-feature "feat: improve bootstrap" PR_BODY.md --labels "ci,bootstrap" --draft
```

Watch the latest build workflow on this branch
```bash
scripts/ghops/run-watch.sh build.yml --branch my-feature
```

Rerun the last failed run on this branch
```bash
scripts/ghops/run-rerun.sh --branch my-feature --failed
```

Download artifacts
```bash
scripts/ghops/artifacts-download.sh --branch my-feature -o artifacts/latest
```

Tag a release and create a GitHub Release
```bash
scripts/ghops/release-tag.sh v1.2.3 --notes RELEASE_NOTES.md --attach dist/x-cli-*
```

Windows equivalents exist under the same folder with `.ps1` suffix.

Dry-run support
- All helpers accept `--dry-run` (bash) or `-DryRun` (PowerShell) to log intended commands without executing them or requiring `gh`/`git`.

JSON logs
- Bash: add `--json` to emit a JSON object with `dryRun`, `repo`, and `commands`.
- PowerShell: add `-Json` for a richer JSON object that also includes script-specific fields.

Tests
- Minimal Pester smoke tests are provided:
  - `powershell -File scripts/ghops/tests/RunGhopsTests.ps1`

Examples
- Bash: `scripts/ghops/run-watch.sh build.yml --dry-run --json > ghops-run-watch.json`
- PowerShell: `powershell -File scripts/ghops/pr-create.ps1 my-feature "feat: bootstrap" -DryRun -Json > ghops-pr-create.json`

PR comments
- CI posts a summary comment on PRs labeled `ghops-logs`. Add `ghops-logs-details` for a deep-dive that includes the full commands per file in collapsible sections.

Auto post comment.md when a label is present
- Helper: `scripts/ghops/tools/post-comment-or-artifact.ps1`
- Behavior: reads event JSON to detect PR and labels; if the given label is present it posts `comment.md`; otherwise it sets outputs so you can upload the file as an artifact instead.

CI example (Stage 2 snippet)
```yaml
    - name: Build telemetry comment
      shell: pwsh
      run: |
        pwsh -File scripts/telemetry-publish.ps1 `
          -Current telemetry/summary.json `
          -Discord $env:DISCORD_WEBHOOK_URL `
          -HistoryDir telemetry/history `
          -EmitChunkDiagnostics `
          -CommentPath telemetry/comment.md
      env:
        DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}

    - name: Post PR comment if label present
      id: post_comment
      shell: pwsh
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        pwsh -File scripts/ghops/tools/post-comment-or-artifact.ps1 `
          -LabelName 'telemetry-chunk-diag' `
          -CommentPath 'telemetry/comment.md'

    - name: Upload comment.md artifact (no label)
      if: steps.post_comment.outputs.posted != 'true'
      uses: actions/upload-artifact@v4
      with:
        name: telemetry-comment
        path: telemetry/comment.md
```

Artifacts
- CI uploads per-command JSON files and two aggregates:
  - `ghops-logs/summary.json` with per-file counts and key fields
  - `ghops-logs/aggregate.json` with the raw logs for each file under `files.{name}`

## Quick commands (Windows PowerShell)

Open a PR from develop
```
powershell -File scripts/ghops/pr-create.ps1 my-feature "feat: improve bootstrap" PR_BODY.md -Labels "ci,bootstrap" -Draft
```

Watch the latest build workflow on this branch
```
powershell -File scripts/ghops/run-watch.ps1 build.yml --branch my-feature
```

Rerun the last failed run on this branch
```
powershell -File scripts/ghops/run-rerun.ps1 --workflow build.yml --branch my-feature --failed
```

Download artifacts
```
powershell -File scripts/ghops/artifacts-download.ps1 --workflow build.yml --branch my-feature -o artifacts/latest
```

Tag a release and create a GitHub Release
```
powershell -File scripts/ghops/release-tag.ps1 v1.2.3 --notes RELEASE_NOTES.md --attach "dist/x-cli-*"
```
