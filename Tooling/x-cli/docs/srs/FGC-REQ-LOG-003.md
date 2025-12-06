# FGC-REQ-LOG-003 - Log replay reproduces captured workflow output
Version: 1.0

## Description
The CLI shall expose `log-replay` to stream historical workflow output recorded as JSON Lines (JSONL). Each record provides the elapsed milliseconds (`t`), target stream (`s`), and message (`m`). The command replays each record to the specified stream with the captured ordering and sleep intervals, constrained by an optional `--max-delay-ms` argument.

## Rationale
ADR 0018 authorizes log replay so x-cli can recreate g-cli workflow transcripts verbatim before layering timing analytics. Ensuring deterministic playback allows downstream automation to compare legacy and modern runs without rerunning tests.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Given a JSONL file with mixed stdout and stderr entries, `x-cli log-replay --from <file>` shall print each message verbatim to the recorded stream in original order.
- AC2. When `--max-delay-ms` is supplied, the total replay duration shall not exceed the sum of capped delays plus a 250 ms tolerance for scheduling.

## Statement(s)
- RQ1. x-cli shall provide a `log-replay` command that consumes a JSONL run capture and emits each record's message to its designated stream with preserved ordering.
- RQ2. `log-replay` shall bound inter-record waits by `--max-delay-ms` when present while otherwise respecting the captured delay.

## Attributes
Priority: Medium
Owner: QA
Source: ADR 0018 - x-cli Log Replay and Timing Diff
Status: Proposed
Trace: docs/srs/FGC-REQ-LOG-003.md
