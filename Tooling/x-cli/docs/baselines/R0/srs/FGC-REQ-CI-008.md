# FGC-REQ-CI-008 — Enforce codex authorship
Version: 1.0

## Description
Ensure commits in automated branches originate from approved codex identities.
- `.github/workflows/enforce-codex-authorship.yml` runs on pull requests and verifies commit authorship.
- The workflow fails if commits are not authored by allowed codex accounts.

## Rationale
Restricting authorship prevents untrusted automation from modifying the codebase.

## Verification
- Push a pull request with an unauthorized author and observe `.github/workflows/enforce-codex-authorship.yml` failing the check.
