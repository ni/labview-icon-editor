# Compliance Exception Review

## Overview
Summarize outstanding compliance exceptions identified during the latest audit cycle and outline mitigation steps.

## Key Tasks
- [x] Generate this report using `scripts/write_markdown.py`.
- [x] Collect documentation gaps and temporary waivers across stages.
- [ ] Confirm remediation owners and due dates with compliance.

## Reference Links
- Documentation: docs/templates/markdown/README.md
- Related Issue: #972

## Telemetry Links (Optional)
- `telemetry/history/compliance/exception-log.json`
- `telemetry/history/compliance/waiver-status.csv`

## Contacts (Optional)
- Owner: `compliance-manager@example.com`
- Escalation: `legal-team@example.com`

## Approvals (Optional)
- Approver: Dana Patel (Compliance Lead)
- Date: 2025-10-05

## Risk Log (Optional)
- Risk: Temporary waiver on Stage 2 artifact retention may expire before the next release.
- Mitigation: Coordinate storage upgrade within two weeks.

## Escalation History (Optional)
- Event: Stage 3 audit block due to missing telemetry manifest.
- Resolution Time: 16 minutes

## Lessons Learned (Optional)
- Insight: Exception status dashboard needs daily sync to avoid stale waivers.
- Impact: Auditor had to cross-reference manual logs, adding delays.

## Follow-up Owners (Optional)
- Action: Automate waiver expiry notifications.
- Owner: `compliance-automation@example.com`
- Due Date: 2025-10-12

## Dependency Notes (Optional)
- Component: Storage retention policy
- Status: Pending legal review
- Action: Finalize retention SLA before Q4 release.

## Tooling Gaps (Optional)
- Tool: Compliance dashboard
- Gap: Lacks waiver expiry alerts.
- Plan: Integrate with telemetry-publish job to propagate flags.

## Notes
Audit cycle suggests introducing optional sections for `Compliance Exceptions` and `Release Timeline` to track temporary waivers and cache release deadlines.
