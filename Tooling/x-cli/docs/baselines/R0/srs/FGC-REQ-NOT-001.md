# FGC-REQ-NOT-001 — GitHub Comment Alerts
Version: 1.0

## Description
CI scripts can post comments to GitHub issues or pull requests via the GitHub REST API using `scripts/github_comment.py`.

## Rationale
Comment-based notifications provide a lightweight mechanism for alerting contributors.

## Verification
- Run `scripts/github_comment.py` to post a test message and ensure `tests/test_github_comment.py` validates the request.
