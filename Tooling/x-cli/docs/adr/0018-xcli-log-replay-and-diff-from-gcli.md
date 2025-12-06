# ADR 0018: x-cli Log Replay (from g-cli runs) and Timing Diff

- Status: Accepted
- Date: 2025-09-26
- Deciders: x-cli maintainers
- Tags: replay, logs, workflows, timing, diff

## Context
Many historical workflow runs were produced via a PowerShell script that invoked g-cli. We want x-cli to recreate those runs’ console output exactly (verbatim syntax and relative timing) inside modern workflows, without executing tests or adding extra output. This establishes a reproducible baseline so that, in a second phase, x-cli can detect timing differences per test and recurring patterns across runs previously made by g-cli.

## Decision
Add two capabilities to x-cli:

1) Log Replay (baseline)
- Input: a structured JSON Lines (JSONL) file representing a single workflow run previously produced with g-cli.
- Behavior: x-cli prints each record to the designated stream (stdout/stderr) with the original message content and inter-record delay, reproducing timing and syntax verbatim. x-cli prints nothing else.
- Scope: no network or test execution; printing only. Ordering and line breaks are preserved.

2) Timing Diff (follow-up)
- Inputs: two JSONL runs (baseline and candidate).
- Behavior: compute and print per-test (and aggregate) timing deltas. Output can be text or JSON, intended for human inspection and downstream tooling. No pass/fail policy at this stage.

## Commands (proposed)
- `x-cli log-replay --from <path>`
  - Options:
    - `--strict`        (fail on malformed records)
    - `--max-delay-ms`  (cap sleep to avoid long replays)
    - `--stdout-only`   (force stdout for all lines when a workflow requires it)
- `x-cli log-diff --baseline <path> --candidate <path>`
  - Options:
    - `--by test|step`  (grouping granularity)
    - `--format text|json`

## JSONL Schema
Each line is a JSON object. Required fields for replay:
- `t`: integer; delay from the previous record in milliseconds (first record is from t=0).
- `s`: string; one of `stdout` or `stderr`.
- `m`: string; exact message to print (verbatim, no mutation).

Optional fields (ignored by replay, used by diff/patterns):
- `test`: string; logical test or step identifier.
- `meta`: object; arbitrary metadata (e.g., file, seed, tags).

Example
```
{"t":0,   "s":"stdout", "m":"Starting suite A"}
{"t":120, "s":"stdout", "m":"Test A1 ... ok",   "test":"A1"}
{"t":15,  "s":"stderr", "m":"[warn] slow op"}
```

## Related Requirements
- FGC-REQ-LOG-003 — Log replay reproduces captured workflow output
- FGC-REQ-LOG-004 — Log diff reports timing deltas

## Verification & Acceptance
- Replay: Given a baseline JSONL, `x-cli log-replay` emits the same lines with inter-line delays within ±10ms of `t` (subject to `--max-delay-ms`). No extra output is produced.
- Diff: Given baseline and candidate JSONL with `test` fields, `x-cli log-diff` prints per-test deltas and overall wall time delta in the requested format.

## Out of Scope
- Awareness of g-cli flags or behavior beyond reproducing the captured output.
- Executing tests/programs; this feature only prints.
- Altering messages or normalizing time beyond an explicit `--max-delay-ms` cap.

## Consequences
- Teams can re-run historic logs in current workflows for apples-to-apples comparisons.
- A stable JSONL schema decouples replay/diff from any one producer while still supporting runs that originally used g-cli.

## Migration Plan
- Provide a one-time converter to transform existing console logs into the JSONL schema.
- Implement `log-replay` first (training/baseline), then add `log-diff` as a separate iteration to surface per-test timing deltas and recurring patterns.
