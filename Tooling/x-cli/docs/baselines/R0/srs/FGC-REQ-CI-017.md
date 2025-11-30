# FGC-REQ-CI-017 — Agents contract check
Version: 1.0

## Description
Validate that commits and pull requests adhere to the AGENTS contract.
- `.github/workflows/agents-contract-check.yml` verifies commit messages, AGENTS digests, and required metadata.
- The workflow fails when the contract is violated.

## Rationale
Enforcing the contract maintains traceability and consistent automation across contributions.

## Verification
- Run `.github/workflows/agents-contract-check.yml` on a pull request and confirm it fails when digests or metadata are missing.
