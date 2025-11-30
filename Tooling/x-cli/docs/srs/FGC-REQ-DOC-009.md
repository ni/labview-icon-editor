# FGC-REQ-DOC-009 - Cross-Agent Session Reflection
Version: 1.0

## Description
Establish a lightweight, ongoing “Cross-Agent Session Reflection” practice: each
session records its own Cross-Agent Telemetry Recommendation, then briefly
reflects on the most recent prior recommendation to capture agreements, deltas,
and concrete next tweaks. The reflection is non-blocking and concise.

## Rationale
Promotes continuity across sessions without anchoring bias and improves shared
tooling/process incrementally while keeping PRs focused.

## Verification
Method(s): Inspection
Acceptance Criteria:
- AC1. PR template includes an explicit prompt to first write the agent’s own
  Cross-Agent Telemetry Recommendation and then add a brief Cross-Agent Session
  Reflection, noting it is non-blocking.
- AC2. ADR describing the practice exists and is marked Accepted.

## Statement(s)
- RQ1. The repository shall include a PR template section that prompts
  contributors to write their own Cross-Agent Telemetry Recommendation first and
  then add a brief (3–5 bullets) Cross-Agent Session Reflection, noted as
  non-blocking.
- RQ2. The repository shall include an accepted ADR that defines the
  Cross-Agent Session Reflection practice and its intent.

## Attributes
Priority: Medium
Owner: DevEx
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-DOC-009.md

