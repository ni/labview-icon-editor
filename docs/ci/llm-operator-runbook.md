# LLM Operator Runbook (Solo Maintainer)

This runbook is the deterministic execution path for LLM-driven repository operations in solo-maintainer mode.

## Safety Rules

- Do not use destructive git commands (`reset --hard`, `checkout --`, force-push history rewrites).
- Do not merge directly in automation scripts; open/update PRs only.
- Keep merge strategy as merge commits.
- Use manual publish intent only.

Optional policy setup helper:

```powershell
pwsh -NoProfile -File .\Tooling\Set-SoloMaintainerBranchProtection.ps1 -DryRun
```

## Modes

## 1) Validate Mode

Runs static contracts and contract-focused Pester suites.

```powershell
pwsh -NoProfile -File .\Tooling\Run-LlmSoloFlow.ps1 -Mode validate
```

Expected result:

- Exits `0`.
- Runs:
  - `Tooling/Test-PathContract.ps1`
  - `Tooling/Test-CiPipelineSelectorDevModeContract.ps1`
  - `Tooling/Test-SoloMaintainerWorkflowContract.ps1`
  - Pester suites under `Tooling/tests` for the three contracts above.

Hard stop conditions:

- Any contract guard failure.
- Any Pester failure.

## 2) Integrate Mode

Runs validation, optional local parity, pushes branch, and opens/updates PR.

```powershell
pwsh -NoProfile -File .\Tooling\Run-LlmSoloFlow.ps1 `
  -Mode integrate `
  -TargetBranch 456-2020-migration `
  -RunLocalParity `
  -MaxParityAttempts 3
```

Expected result:

- Validation passes.
- Optional parity succeeds within max attempts.
- Branch is pushed.
- PR exists from source branch to target branch.
- No direct merge performed.

Hard stop conditions:

- Dirty git worktree.
- `gh` CLI unavailable or not authenticated.
- Parity loop failure.
- PR create/update failure.

## 3) Release Mode

Runs integrate preconditions, then optionally dispatches prerelease workflow.

No dispatch:

```powershell
pwsh -NoProfile -File .\Tooling\Run-LlmSoloFlow.ps1 -Mode release
```

Dispatch with explicit intent:

```powershell
$sha = (git rev-parse HEAD).Trim()
pwsh -NoProfile -File .\Tooling\Run-LlmSoloFlow.ps1 `
  -Mode release `
  -PublishPrerelease `
  -ExpectedSha $sha
```

Expected result:

- Dispatch occurs only with both:
  - `-PublishPrerelease`
  - `-ExpectedSha` matching `HEAD`
- Evidence file written:
  - `builds/status/solo-release-evidence.json`

## Evidence Contract

`builds/status/solo-release-evidence.json` records:

- source SHA
- source and target branches
- repository
- PR URL
- guard results
- CI run URLs (when resolvable)
- artifact names (when resolvable)
- publish decision
- timestamp

## Failure Triage Matrix

| Failure Type | Primary Check | Next Action |
| --- | --- | --- |
| Contract guard failure | Guard script output | Fix violated contract; rerun `-Mode validate`. |
| Workflow contract failure | `Test-SoloMaintainerWorkflowContract.ps1` | Restore manual-only triggers / pipeline-contract / publish-intent tokens. |
| Container parity failure | `Run-CICompositeLocal-Auto.ps1` logs | Re-run with same mode; inspect `TestResults/agent-logs`. |
| Release gate failure | `publish-gate` or `publish-prerelease` logs | Confirm dispatch inputs and required asset pipeline outcomes. |

## Related Policy

- `docs/ci/solo-maintainer-mode.md`
