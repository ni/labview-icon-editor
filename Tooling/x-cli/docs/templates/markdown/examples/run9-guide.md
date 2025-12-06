# Security Findings Summary

## Overview
Aggregate security observations from the recent penetration test and CI scans, highlighting required mitigations.

## Key Tasks
- [x] Generate this summary with `scripts/write_markdown.py`.
- [x] Collect findings from Stage 1 container scans and Stage 3 Windows antivirus logs.
- [ ] Track remediation actions and deadlines for each finding.

## Reference Links
- Documentation: docs/templates/markdown/README.md
- Related Issue: #990

## Telemetry Links (Optional)
- `telemetry/security/pen-test-summary.json`
- `telemetry/security/av-scan-results.csv`

## Contacts (Optional)
- Owner: `security-analyst@example.com`
- Escalation: `ciso@example.com`

## Approvals (Optional)
- Approver: Riley Chen (Security Lead)
- Date: 2025-10-08

## Risk Log (Optional)
- Risk: Outdated OpenSSL package in Stage 1 container enables medium-severity CVE.
- Mitigation: Upgrade base image and re-run Stage 1 QA.

## Escalation History (Optional)
- Event: Stage 2 antivirus quarantine during artifact publish.
- Resolution Time: 22 minutes

## Lessons Learned (Optional)
- Insight: Automated container scanning needs to run on nightly builds.
- Impact: Pen test reported issue before nightly detected it.

## Follow-up Owners (Optional)
- Action: Add container scan step to nightly pipeline.
- Owner: `secops-owner@example.com`
- Due Date: 2025-10-25

## Dependency Notes (Optional)
- Component: OpenSSL 1.1.1
- Status: Pending upgrade
- Action: Adopt 1.1.1v patch within 48 hours.

## Tooling Gaps (Optional)
- Tool: Antivirus reporting
- Gap: Lacks API export for telemetry aggregator.
- Plan: Script CSV ingestion into telemetry history.

## Compliance Exceptions (Optional)
- Exception: Temporary waiver for OpenSSL patch pending Stage 1 rebuild.
- Waiver Expiry: 2025-10-15
- Mitigation: Rebuild container and remove waiver before expiry.

## Release Timeline (Optional)
- Milestone: October hotfix release
- Target Date: 2025-10-18
- Status: At risk pending OpenSSL patch.

## Notes
Security findings surfaced repeatedly; recommend adding an optional `Security Findings` section and consider aliasing it for multi-entry lists.
