# Branch Protection Reference

This document captures the branch protection and ruleset requirements currently in effect for `LabVIEW-Community-CI-CD/x-cli`.

Local verification:

```
pwsh -File scripts/dev/check-branch-protection.ps1
```

For the rationale behind each check, see `docs/ci/required-checks-rationale.md`.

## Required Checks (Classic Protection)

| Branch | Strict | Required Status Checks |
| ------ | ------ | ---------------------- |
| develop | ❌ | coverage, lychee |
| main | ✅ | Pre-Commit / run, SRS Gate / SRS Compliance + Smoke, SRS Gate / SRS Scripts - Unit Tests, SRS Gate / Traceability (RTM) Verify, Tests Gate / Python Tests (serial), Tests Gate / Python Tests (parallel), PR Coverage Gate / coverage, Docs Gate / Canonical Sources, DoD Gate / dod, YAML Lint / lint |
| feat/demo | ❌ | YAML Lint / lint |

> `feat/demo` is a representative feature branch used for verification. Any branch matching `refs/heads/feat/*` or `refs/heads/feature/*` must satisfy the same checks.

Note: While classic protection on `develop` has no required status checks, the active `main` ruleset applies to the default branch (`~DEFAULT_BRANCH`), resulting in effective checks: `coverage`, `lychee`.

## Active Rulesets

| Name | Enforcement | Target | Include Patterns | Required Checks |
| ---- | ----------- | ------ | ---------------- | --------------- |
| main | active | branch | `~DEFAULT_BRANCH`, `refs/heads/main` | coverage, lychee |
| coverage | active | branch | `refs/heads/coverage` | coverage |
| features-yaml-lint | active | branch | `refs/heads/feat/*`, `refs/heads/feature/*` | YAML Lint / lint |

## Update Process

1. Apply changes in GitHub (Settings → Branches or Settings → Rules) to add or remove required checks.
2. Re-run the guard test (`pwsh -File scripts/dev/check-branch-protection.ps1`).
3. Update `docs/settings/branch-protection.expected.json` and this markdown file to reflect the new state, then run the test again to confirm parity.

The guard test executes Pester tests (`scripts/tests/BranchProtection.Tests.ps1`) that compare the documented expectations against live GitHub settings. Tests return `Inconclusive` when `gh` isn’t authenticated or a token is missing; run `gh auth login` or export `GH_TOKEN` to enable validation.

