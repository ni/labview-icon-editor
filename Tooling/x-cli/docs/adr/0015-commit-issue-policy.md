# ADR 0015: Commit Message Issue Requirement

- Status: Accepted
- Date: 2025-09-24

## Context
We standardize commit metadata to strengthen traceability (see ADR 0006, 0012, 0013).
Commits must include a structured third line:

codex: <change_type> | SRS: <ids>@<version> | issue: #<issue-number>

The required issue reference enables audit trails, triage, and PR linkage.

## Decision
- Require an issue reference in the third line meta (`| issue: #<n>`), alongside `codex:` and `SRS:` blocks.
- Enforce via:
  - commit template (`scripts/commit-template.txt`),
  - commit-msg hook (`scripts/commit-msg` + `scripts/check-commit-msg.py`),
  - CI commit checks in PR gates.
- Provide `scripts/create_issue.py` to create an issue and emit the snippet `issue: #<n>`.
- Support summary enrichment with a short bracketed suffix while keeping the 50‑char limit; drop overflow tags but preserve them in a trailer line (`X-Tags: …`) and `.codex/telemetry.json`.
- Allow well-known exceptions that are auto-generated or squashed later: merge commits, reverts, and fixup/squash commits are accepted without the template.

## Consequences
- Commits missing the required issue are rejected locally and in CI (except allowed exceptions above).
- Developers use `scripts/create_issue.py` (or GitHub UI) to create/locate an issue, then append `| issue: #<n>` to line 3.
- Telemetry captures commit summary enrichment decisions and any dropped tags.
- Docs and SRS compliance gates reflect the required field and the exceptions.

## Examples
Summary line (<= 50 chars)

codex: impl | SRS: FGC-REQ-DEV-005@1.0, FGC-REQ-SPEC-001@1.0 | issue: #123

Merge commits (auto-generated) and `fixup!`/`squash!` commits bypass strict checks.

## References
- ADR 0006: Requirements Traceability — commit metadata requirement
- ADR 0012: Traceability Matrix — commit evidence capture
- ADR 0014: Traceability Telemetry — enrichment memory and dashboards

- Supersedes: 
- Superseded-by: 
