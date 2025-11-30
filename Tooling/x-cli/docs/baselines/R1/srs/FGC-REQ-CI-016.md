# FGC-REQ-CI-016 — Discord canary
Version: 1.0

## Description
Verify connectivity to the project's Discord notification channel.
- `.github/workflows/discord-canary.yml` posts a canary message to the configured Discord webhook.
- The workflow fails if the message cannot be delivered.

## Rationale
Regular canary checks alert maintainers to broken notification channels.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall verify connectivity to the project's Discord notification channel.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-016.md