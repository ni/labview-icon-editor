# Contributor License Agreement (CLA) intake

This repo uses a simple, auditable CLA manifest to track who is cleared to contribute. CLA reviewers should confirm every new collaborator has a valid record before granting write access or merging PRs.

## Required fields (per contributor)
- `github`: GitHub handle (e.g., `svelderrainruiz`)
- `cla_type`: `individual` or `corporate`
- `cla_version`: identifier of the signed CLA (e.g., `v1.0`)
- `signed_on`: ISO date the CLA was signed
- `evidence`: URL or document ID pointing to stored CLA evidence (do not store the signed doc in the repo)
- `email`: contact used on the CLA (optional but recommended)
- `notes`: optional reviewer notes

## Reviewer checklist
1. Verify a signed CLA exists for the contributor and matches the requested access.
2. Add or update the entry in `docs/cla/manifest.json`.
3. Keep sensitive documents outside the repo; only store references/IDs here.
4. Ensure CODEOWNERS for CLA files includes the CLA reviewer team/owners.

## When to update
- Adding a new collaborator or granting write access.
- When a CLA is superseded (bump `cla_version` and `signed_on`).
- When evidence storage location changes (update `evidence`).

## Process references
- CLA signing steps: `docs/cla/signing.md`
