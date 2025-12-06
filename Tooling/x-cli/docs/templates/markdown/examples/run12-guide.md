# Training Needs Assessment

## Overview
Evaluate team readiness for the upcoming automation upgrades and identify skill gaps that could slow delivery.

## Key Tasks
- [x] Generate this assessment via `scripts/write_markdown.py`.
- [x] Survey Stage 1-3 owners for required training topics.
- [ ] Schedule training sessions and track completion metrics.

## Reference Links
- Documentation: docs/templates/markdown/README.md
- Related Issue: #1050

## Telemetry Links (Optional)
- `telemetry/org/training-completion.json`
- `telemetry/org/skill-gap.csv`

## Contacts (Optional)
- Owner: `enablement-lead@example.com`
- Escalation: `engineering-director@example.com`

## Approvals (Optional)
- Approver: Jamie Park (Engineering Director)
- Date: 2025-10-14

## Risk Log (Optional)
- Risk: Lack of Stage 3 Windows expertise could delay telemetry validation.
- Mitigation: Pair new hires with senior operators during next cycle.

## Escalation History (Optional)
- Event: Escalation for missing training coverage in Stage 2.
- Resolution Time: 6 hours

## Lessons Learned (Optional)
- Insight: Training plans should be drafted alongside PI planning.
- Impact: Ad-hoc sessions caused conflicting schedules.

## Follow-up Owners (Optional)
- Action: Create quarterly training roadmap.
- Owner: `training-coordinator@example.com`
- Due Date: 2025-10-30

## Dependency Notes (Optional)
- Component: Training LMS integration
- Status: In progress
- Action: Connect LMS completions to telemetry dashboards.

## Tooling Gaps (Optional)
- Tool: Training LMS
- Gap: No API access to completion data.
- Plan: Request vendor enable API export or nightly CSV drop.

## Budget Impact (Optional)
- Spend Summary: Additional $3k for Stage 3 lab environment rentals.
- Variance: +12% vs forecast
- Adjustment Plan: Shift unused Stage 1 cloud budget.

## Customer Impact (Optional)
- Impact Summary: None yet; preventive training aims to avoid customer-facing issues.
- Affected Users: N/A
- Communication Plan: Include training summary in release notes if new tooling touches customers.

## Notes
Training needs surfaced as a distinct theme. Consider adding an optional `Training Needs` section to capture required sessions, owners, and timelines explicitly.
