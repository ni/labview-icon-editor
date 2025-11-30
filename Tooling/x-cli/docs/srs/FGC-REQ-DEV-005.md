# FGC-REQ-DEV-005 - Commit messages include SRS metadata
Version: 1.1

## Description
Commit messages shall follow the repository template enforced by `scripts/check-commit-msg.py` and `scripts/prepare-commit-msg.py`:

1. A summary line of 1–50 characters.
2. A blank second line.
3. A metadata line `codex: <change_type> | SRS: <comma-separated-srs-ids>` with an optional `| issue: #<number>` suffix.
4. Each SRS ID shall reference a registered requirement; unknown or mismatched versions cause the commit to be rejected.

## Rationale
Standardized commit metadata enables automation and accurate SRS traceability.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall require commit messages to follow the repository template.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-005.md
