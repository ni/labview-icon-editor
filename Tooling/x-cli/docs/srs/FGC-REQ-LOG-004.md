# FGC-REQ-LOG-004 - Log diff reports timing deltas
Version: 1.0

## Description
x-cli shall provide `log-diff` to compare two workflow captures encoded as JSONL. The command loads baseline and candidate streams, groups entries by logical test when requested, and reports elapsed time deltas in either plain text or JSON output.

## Rationale
ADR 0018 extends the replay baseline with timing analytics so teams can quantify drift between historical g-cli runs and new executions driven by x-cli. Structured output enables dashboards while human-readable text supports ad-hoc reviews.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. With `--format text --by test`, `x-cli log-diff` shall list each test found in the captures alongside its baseline, candidate, and delta timings.
- AC2. With `--format json --by test`, the command shall emit a JSON document containing a `by` field matching the requested grouping and an array of rows describing per-test timing metrics.

## Statement(s)
- RQ1. x-cli shall expose a `log-diff` command that accepts baseline and candidate JSONL files and reports per-test timing deltas when invoked with `--by test`.
- RQ2. When `--format json` is requested, `log-diff` shall emit structured JSON including the requested grouping metadata and per-row baseline, candidate, and delta durations in milliseconds.

## Attributes
Priority: Medium
Owner: QA
Source: ADR 0018 - x-cli Log Replay and Timing Diff
Status: Proposed
Trace: docs/srs/FGC-REQ-LOG-004.md
