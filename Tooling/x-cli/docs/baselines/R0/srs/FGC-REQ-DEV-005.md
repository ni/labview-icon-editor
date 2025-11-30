# FGC-REQ-DEV-005 — Commit messages include SRS metadata
Version: 1.1

## Description
Commit messages must follow the repository template enforced by `scripts/check-commit-msg.py` and `scripts/prepare-commit-msg.py`:

1. A summary line of 1–50 characters.
2. A blank second line.
3. A metadata line `codex: <change_type> | SRS: <comma-separated-srs-ids>` with an optional `| issue: #<number>` suffix.
4. Each SRS ID must reference a registered requirement; unknown or mismatched versions cause the commit to be rejected.

## Rationale
Standardized commit metadata enables automation and accurate SRS traceability.

## Verification
- Run `scripts/check-commit-msg.py` or the pre-commit hook and ensure `tests/test_check_commit_msg.py` and `tests/test_prepare_commit_msg.py` pass for valid messages.
