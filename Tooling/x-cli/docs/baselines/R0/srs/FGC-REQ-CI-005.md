# FGC-REQ-CI-005 — Configure branch protection
Version: 1.0

## Description
Maintain required branch protection rules for the repository.
- `.github/workflows/configure-branch-protection.yml` applies predefined branch protection settings via the GitHub API.
- The workflow runs on demand to ensure rules remain enforced.

## Rationale
Automated branch protection prevents unauthorized changes and preserves repository integrity.

## Verification
- Execute `.github/workflows/configure-branch-protection.yml` and verify branch rules match the policy after completion.
