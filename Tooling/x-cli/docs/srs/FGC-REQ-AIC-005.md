# FGC-REQ-AIC-005 - Automated reviewer critique for Codex PRs
Version: 1.0

## Statement(s)
- RQ1. When a PR is labeled `codex-proposal`, the CI system shall generate an AI reviewer critique.
- RQ2. When a maintainer comments `/reviewer critique` in a PR thread, the CI system shall generate an AI reviewer critique.
- RQ3. The CI system shall post the critique as a PR review comment.
- RQ4. The CI system shall fail the associated job if the critique cannot be generated or posted.

## Rationale
Adds an automated reviewer that highlights SRS alignment issues and risks before human review and fails the CI job when no critique is produced.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. Labeling a PR `codex-proposal` produces a reviewer comment with the required sections (Executive Summary, SRS Alignment, Risk & Impact, Actionable Next Steps, Verdict).
- AC2. Commenting `/reviewer critique` in a PR thread produces the same style of critique in that PR.
- AC3. If critique generation or posting fails, the CI job reports an error and no critique comment is added.

## Attributes
Priority: Medium
Owner: QA
Source: Process policy
Status: Proposed
Trace: `.github/workflows/codex-reviewer.yml`, `scripts/reviewer_bridge.py`
Maintenance: QA updates these attributes via version-controlled commits whenever values change.
