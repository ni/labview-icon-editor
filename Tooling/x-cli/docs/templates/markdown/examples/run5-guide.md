# Escalation Drill Debrief

## Overview
Record findings from the latest escalation drill and capture outstanding actions for the on-call rotation.

## Key Tasks
- [x] Generate this debrief from the base template using `scripts/write_markdown.py`.
- [x] Document contact tree updates and escalation timing benchmarks.
- [ ] Confirm playbook revisions with security and ops leads.

## Reference Links
- Documentation: docs/templates/markdown/README.md
- Related Issue: #812

## Telemetry Links (Optional)
- Incident timeline: telemetry/history/incidents/drill-2025-09.json
- Response metrics: telemetry/history/response/summary.json

## Contacts (Optional)
- Owner: `oncall-lead@example.com`
- Escalation: `security-manager@example.com`

## Approvals (Optional)
- Approver: Kim Lee (Security Lead)
- Date: 2025-09-26

## Risk Log (Optional)
- Risk: Escalation path for third-party outage remains untested.
- Mitigation: Schedule partner integration drill before next quarterly review.

## Escalation History (Optional)
- Event: Vendor outage simulation
- Resolution Time: 42 minutes

## Notes
Escalation history now carried explicitly; future drills can capture multiple events by duplicating the new section as needed.
