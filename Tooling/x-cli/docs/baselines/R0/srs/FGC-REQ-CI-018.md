# FGC-REQ-CI-018 — Codex mirror sign
Version: 1.0

## Description
Mirror repository contents and produce signed artifacts for release.
- `.github/workflows/codex-mirror-sign.yml` mirrors the repository to the designated target.
- The workflow signs published artifacts and verifies signatures.

## Rationale
Signed mirrors enable trusted distribution and archival of releases.

## Verification
- Execute `.github/workflows/codex-mirror-sign.yml` and ensure mirrored artifacts include valid signatures.
