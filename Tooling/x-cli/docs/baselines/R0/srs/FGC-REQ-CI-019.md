# FGC-REQ-CI-019 — Commit message policy
Version: 1.0

## Description
Enforce the repository's commit message conventions.
- `.github/workflows/commit-message-policy.yml` verifies that every commit message matches the required template.
- The workflow fails when a commit message violates the policy.

## Rationale
Consistent commit messages improve traceability and automation tooling.

## Verification
- Push a commit with an invalid message and observe `.github/workflows/commit-message-policy.yml` failing the check.
