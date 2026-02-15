# Tooling

This folder contains PowerShell scripts used for local CI parity, packaging, and developer workflows.

Common entrypoints:
- `Resolve-GitHubRepo.ps1`
  Resolves the current GitHub repository as `owner/name` without relying on `gh repo view` auto-resolution.
  Precedence: `-Repo` argument, `GH_REPO` env var, then `origin` remote URL.
  Example: `pwsh -NoProfile -File .\\Tooling\\Resolve-GitHubRepo.ps1`
  Optional shell hygiene: `pwsh -NoProfile -File .\\Tooling\\Resolve-GitHubRepo.ps1 -SetGhDefault`
- `Run-ViValidate.ps1`
  Runs the fast pylavi `vi_validate` gate only. Uses `.lvversion` as the canonical LabVIEW version.
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-ViValidate.ps1`
  Profiles: `-ViValidateProfile strict|legacy|both`, optional `-ViValidateReportOnly`, `-ViValidateSkipVersionGate`.
  Optional absolute-path focus: set `LVIE_PYLAVI_ABSOLUTE_PATH_ROOTS` (semicolon-delimited) to flag specific roots without committing sensitive paths. CI redacts configured roots in logs and the uploaded pylavi log artifact, uploads a redacted top-offenders report (`pylavi-validate-offenders-<label>`), and prints a top-offenders table in the step summary.
- `Run-CICompositeLocal.ps1`
  Local CI parity run (Verify IE Paths, VIPC, unit tests, PPLs, VIP build).
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-CICompositeLocal.ps1`
  Dev-mode request flags are policy-disabled and now fail fast.
  Note: Direct execution is deprecated; use `Invoke-WorktreeOrchestrator.ps1` for worktree-aware runs.
- `Run-CICompositeLocal-Auto.ps1`
  Retry loop for local CI parity with adaptive timeouts and selectable success contracts (`vip|ppl|script`).
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-CICompositeLocal-Auto.ps1 -MaxAttempts 5`
- `Invoke-BeltAndSuspendersCI.ps1` (recommended proactive loop)
  Canonical "belt and suspenders" flow for exact-SHA confidence:
  1) local parity auto-loop until PPL success target is met,
  2) dispatch `ci-composite.yml` for the same SHA,
  3) wait for completion and run CI debt analysis on failure.
  Example: `pwsh -NoProfile -File .\\Tooling\\Invoke-BeltAndSuspendersCI.ps1 -Sha HEAD`
  Useful switches: `-SkipLocalParity`, `-FullLocalParity`, `-DispatchCleanupRemote`, `-CiDebtFailOnUnknown`.
- `Run-CICompositeForCommit.ps1`
  Dispatches `CI Pipeline (Composite)` for an explicit SHA via a temporary branch.
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-CICompositeForCommit.ps1 -Sha <commit>`
- `Invoke-WorktreeOrchestrator.ps1`
  Resolves worktree policy/root, builds runner-cli in the selected worktree, and can invoke local CI parity.
  Example: `pwsh -NoProfile -File .\\Tooling\\Invoke-WorktreeOrchestrator.ps1 -Run -RunArgs -LabVIEWVersion 2021`
- `gh pr create` (recommended for opening PRs)
  Opens a GitHub PR for the current branch with the desired template.
  Resolve repo: `$repo = pwsh -NoProfile -File .\\Tooling\\Resolve-GitHubRepo.ps1`
  `GH_REPO` is an optional override and takes precedence when set.
  Example: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE.md`
  Specialized templates:
  `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/bug_fix.md`
  `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/feature_request.md`
  `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/documentation.md`
  `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/infrastructure_change.md`
- `gh issue create` (recommended for template-driven issues)
  Bug report: `gh issue create --repo $repo --template "Bug Report"`
  Feature request: `gh issue create --repo $repo --template "Feature request"`
- `Get-PylaviOffenders.ps1`
  Summarizes the latest pylavi offenders report for agent handoffs or automation.
  Example: `pwsh -NoProfile -File .\\Tooling\\Get-PylaviOffenders.ps1`
  Optional: `-AsJson`, `-Top 20`, `-Label legacy`, `-OutputPath out.json`, `-WriteSummary`, `-Quiet`, `-FetchLatest`, `-ValidateExists`, `-FailOnEmpty`, `-FailOnFindings`, `-FailOnThreshold 0`.
  Deterministic: `-Sha <commit>` selects `pylavi-offenders.<sha>.json` (local or fetched); `-RunId <id>` + `-FetchLatest` targets a specific workflow run.
  `-FetchLatest` pulls the CI artifact automatically (requires `GH_TOKEN`/`GITHUB_TOKEN` with `actions:read`).
- `Fetch-PylaviOffenders.ps1`
  Downloads the latest pylavi offenders artifact from CI into `TestResults\agent-logs`.
  Example: `pwsh -NoProfile -File .\\Tooling\\Fetch-PylaviOffenders.ps1 -Branch develop`
  Deterministic: `-Sha <commit>` or `-RunId <id>` to pin a specific workflow run.
  Uses `GH_TOKEN` or `GITHUB_TOKEN` (needs `actions:read`).
- `runner-cli`
  Cross-platform helper for version-gate and pylavi scans (see `Tooling/runner-cli`).
  Example: `runner-cli version-gate --repo-root .`
  Example: `runner-cli pylavi scan --config Tooling/pylavi/vi-validate.yml --report-only`
  Example: `runner-cli pylavi summarize --repo-root .`
  Example: `runner-cli pylavi fetch --repo <owner/name> --branch develop`
  Example (baseline delta): `runner-cli pylavi summarize --path TestResults/agent-logs/pylavi-offenders.latest.json --baseline Tooling/pylavi/pylavi-offenders.baseline.json --fail-on-delta`
- `Assert-CodexSkillLayer.ps1`
  Verifies the pinned Codex skill layer is installed and valid (`0BSD`, hash, required files). Hard-fails when missing.
  Example: `pwsh -NoProfile -File .\\Tooling\\Assert-CodexSkillLayer.ps1`
- `Install-CodexSkillLayer.ps1`
  Downloads and installs the pinned Codex skill layer from release assets.
  Example: `pwsh -NoProfile -File .\\Tooling\\Install-CodexSkillLayer.ps1`
- `Invoke-CiDebtAnalysis.ps1`
  Wrapper entrypoint that runs CI debt analysis from the installed Codex skill layer.
  Example: `pwsh -NoProfile -File .\\Tooling\\Invoke-CiDebtAnalysis.ps1 -Repo $repo -RunId 21840801109`
  Fixture-only example: `pwsh -NoProfile -File .\\Tooling\\Invoke-CiDebtAnalysis.ps1 -Repo $repo -RunId 21840801109 -FixturePath .\\Tooling\\tests\\fixtures\\ci-debt\\run-21840801109.json`

Related config:
- `pylavi/vi-validate.yml`
  Strict configuration for `vi_validate` (paths, skips, policy). The LabVIEW version is injected at runtime from `.lvversion`.
- `pylavi/vi-validate-legacy.yml`
  Legacy scope for `vi_validate` (typically absolute-path checks only).

Release labels:
- Canonical: `Version Increment: Major`, `Version Increment: Minor`, `Version Increment: Patch`
- Compatibility aliases (deprecated after two release cycles): `major`, `minor`, `patch`
Issue-type labels:
- Canonical: `Issue group: Bug`, `Type: Enhancement`
- Compatibility aliases (deprecated after two release cycles): `bug`, `enhancement`

## Local GitHub Auth and Fork Remotes

Tooling requires system `git` on PATH.

Some tooling fetches GitHub artifacts or queries workflow runs. Configure auth and ensure your fork remotes are correct.

Auth options (either works):
- `GH_TOKEN` or `GITHUB_TOKEN` with `actions:read` for artifact fetches.
- `gh` CLI login (`gh auth status`) for commands that use `gh`.

Fork remotes:
- Ensure `origin` points to your fork and `upstream` points to `ni/labview-icon-editor`.
- Run `pwsh -NoProfile -File .\Tooling\Test-ForkRemotes.ps1` to warn when `origin` still points to upstream and to validate non-interactive fetch connectivity.
- Set `LVIE_SKIP_REMOTE_CONNECTIVITY_CHECK=1` to skip the connectivity checks when working offline.

Example fork setup:
```powershell
git remote set-url origin https://github.com/<your-user>/labview-icon-editor.git
git remote add upstream https://github.com/ni/labview-icon-editor.git
git remote -v
```
