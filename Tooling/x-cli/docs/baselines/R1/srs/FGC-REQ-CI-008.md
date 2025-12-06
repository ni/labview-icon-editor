# FGC-REQ-CI-008 — Enforce codex authorship
Version: 1.0

## Description
Ensure commits in automated branches originate from approved codex identities.
- `.github/workflows/enforce-codex-authorship.yml` runs on pull requests and verifies commit authorship.
- The workflow fails if commits are not authored by allowed codex accounts.

## Rationale
Restricting authorship prevents untrusted automation from modifying the codebase.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall ensure commits in automated branches originate from approved codex identities.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-008.md