# FGC-REQ-CI-019 - Commit message policy
Version: 1.1

## Description
Enforce the repository's commit message conventions.
- The third line meta is required and shall include an issue reference:
  `codex: <change_type> | SRS: <ids>@<version> | issue: #<issue-number>`
- The commit message validator checks all commits in the PR for compliance.

## Rationale
Consistent commit messages improve traceability and automation tooling.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. The validator rejects a commit message missing an issue reference.
- AC2. The validator rejects malformed meta (e.g., invalid change_type or SRS ID format).
- AC3. The commit template in `scripts/commit-template.txt` matches the enforced format.
## Statement(s)
- RQ1. The system shall enforce the repository's commit message conventions, including a required issue reference in the third line meta.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-019.md
