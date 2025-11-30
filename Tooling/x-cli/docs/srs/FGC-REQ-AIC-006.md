# FGC-REQ-AIC-006 - Persist reviewer artifacts & label PRs
Version: 1.0

## Statement(s)
- RQ1. The reviewer agent shall save each critique under `.codex/reviews/` with a timestamped filename and commit it to the repository using a `[skip ci]` message.
- RQ2. The reviewer agent shall label reviewed pull requests with `codex-reviewed`.

## Rationale
Creates an auditable record of AI review output and marks PRs that received AI critique.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. After the reviewer runs, a file `.codex/reviews/<timestamp>-pr<no>.md` exists and is committed on the default branch.
- AC2. The PR shows the `codex-reviewed` label.

## Attributes
Priority: Low
Owner: DevEx
Source: Team policy
Status: Proposed
Trace: `scripts/reviewer_bridge.py`, `.github/workflows/codex-reviewer.yml`
