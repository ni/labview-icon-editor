# Customer Impact Assessment

## Overview
Analyze customer-facing effects of the latest release candidate, including support load and field telemetry signals.

## Key Tasks
- [x] Generate this assessment via `scripts/write_markdown.py`.
- [x] Aggregate field telemetry anomalies and support ticket volume.
- [ ] Coordinate mitigation messaging with customer success.

## Reference Links
- Documentation: docs/templates/markdown/README.md
- Related Issue: #1003

## Telemetry Links (Optional)
- `telemetry/customer/field-telemetry.json`
- `telemetry/customer/support-trend.csv`

## Contacts (Optional)
- Owner: `customer-success@example.com`
- Escalation: `head-of-support@example.com`

## Approvals (Optional)
- Approver: Morgan Díaz (Customer Success Lead)
- Date: 2025-10-10

## Risk Log (Optional)
- Risk: Increased support tickets related to Stage 3 artifact misconfiguration.
- Mitigation: Publish knowledge-base fix and patch artifact.

## Escalation History (Optional)
- Event: Tier-2 escalation due to CLI crash in win-x64 artifact.
- Resolution Time: 3 hours

## Lessons Learned (Optional)
- Insight: Need proactive comms when telemetry flags new errors.
- Impact: Customers experienced 2-hour outage window before mitigation.

## Follow-up Owners (Optional)
- Action: Automate email notifications for high-severity telemetry spikes.
- Owner: `communications-owner@example.com`
- Due Date: 2025-10-14

## Dependency Notes (Optional)
- Component: Support knowledge base integration
- Status: Update pending
- Action: Republish KB article with clarified steps.

## Tooling Gaps (Optional)
- Tool: Customer analytics dashboard
- Gap: Lacks real-time alerting.
- Plan: Integrate with telemetry aggregator push API.

## Compliance Exceptions (Optional)
- Exception: Temporary waiver on customer-notification SLA (24 hours).
- Waiver Expiry: 2025-10-15
- Mitigation: Restore SLA alerts post-mitigation.

## Release Timeline (Optional)
- Milestone: Hotfix announcement
- Target Date: 2025-10-11
- Status: Scheduled

## Security Findings (Optional)
- Finding: None (no security impact observed in this cycle).
- Severity: N/A
- Remediation: N/A

## Notes
Customer-facing data indicates a recurring need to capture impact metrics and mitigation messaging. Recommend adding optional `Customer Impact` section with placeholders for severity, affected users, and communications.
