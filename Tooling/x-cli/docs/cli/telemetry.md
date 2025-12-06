# Telemetry CLI

The `telemetry` command group provides standardized, fast, and cross‑platform telemetry utilities built into `x-cli` (C#, .NET 8). Core goals are stability, strong typing, and zero extra runtimes for core telemetry operations.

## Commands

- `telemetry summarize --in PATH --out PATH [--history PATH]`
  - Reads a QA JSONL log and produces a summary JSON. When `--history` is provided, also appends a snapshot record (one line per run).
  - Exit codes: `0` on success; `2` when required arguments are missing.

- `telemetry write --out PATH --step NAME --status pass|fail [--duration-ms N] [--start N] [--end N] [--meta k=v ...]`
  - Appends one QA event to a JSONL file (creates directories/files if needed). If `duration-ms` is omitted, it is derived from `end-start` or defaults to `0`.
  - Exit codes: `0` on success; `2` on usage errors.

- `telemetry check --summary PATH --max-failures N [--max-failures-step step=N ...]`
  - Validates gates for total failures and optional per‑step limits. Repeat `--max-failures-step` for multiple steps.
  - Exit codes: `0` (ok), `1` (gate failed), `2` (usage/parse error).

- `telemetry validate --summary PATH | --events PATH`
  - Validates summary shape and/or events JSONL lines.
  - Exit codes: `0` (ok), `2` (usage/parse error).

Examples:

```bash
dotnet run -- telemetry summarize \
  --in artifacts/qa-telemetry.jsonl \
  --out telemetry/summary.json \
  --history telemetry/qa-summary-history.jsonl
```

Append a single event:

```bash
dotnet run -- telemetry write \
  --out artifacts/qa-telemetry.jsonl \
  --step build-release --status pass --duration-ms 1851
```

Gate on failures (total and per-step):

```bash
dotnet run -- telemetry check --summary telemetry/summary.json --max-failures 0 \
  --max-failures-step test-python=0 --max-failures-step build-release=0
```

Validate inputs:

```bash
dotnet run -- telemetry validate --summary telemetry/summary.json \
  --schema docs/schemas/v1/telemetry.summary.v1.schema.json
dotnet run -- telemetry validate --events artifacts/qa-telemetry.jsonl \
  --schema docs/schemas/v1/telemetry.events.v1.schema.json
```

Notes:
- When `GITHUB_RUN_ID` is set (CI), it is included in the history record as `run_id`.
- The summarizer is robust to slightly different JSON field names (supports both `duration_ms` and `durationMs`).
- Malformed lines in the JSONL input are ignored (best‑effort summary).

## Input/Output Formats

### Input: QA JSONL (events)

Each line is a JSON object describing a QA step. Typical fields:

```json
{ "step": "build-release", "status": "pass", "duration_ms": 1851, "start": 1759005220929, "end": 1759005222780 }
```

Accepted fields (case‑sensitive):
- `step` (string): name of the step (e.g., `install-deps`, `test-python`)
- `status` (string): `pass` or `fail`
- `duration_ms` or `durationMs` (number): step runtime in milliseconds
- `start`, `end` (number): optional timestamps in ms
- `meta` (object<string,string>): optional metadata

### Output: Summary JSON

```json
{
  "counts": { "build-release": 1, "test-python": 1 },
  "failureCounts": { "test-python": 1 },
  "durationsMs": { "build-release": 1851, "test-python": 26416 },
  "total": 2,
  "totalFailures": 1,
  "generatedAtUtc": "2025-09-27T20:43:06.8294302Z"
}
```

Fields:
- `counts`: total events per `step`
- `failureCounts`: failure events per `step` (status == `fail`)
- `durationsMs`: sum of durations per `step` (ms)
- `total`: total events across all steps
- `totalFailures`: total failures across all steps
- `generatedAtUtc`: ISO‑8601 UTC timestamp of summary creation

### Output: History JSONL

When `--history PATH` is provided, one JSON line is appended per run:

```json
{"run_id":"123456789","generated_at_utc":"2025-09-27T20:43:06.829Z","total":19,"total_failures":1,
 "failure_counts":{"test-python":1},
 "counts":{"install-deps":1,"build-release":1,"test-python":1},
 "durations_ms":{"install-deps":4129,"build-release":1851,"test-python":26416}}
```

## Integration Points

- QA pipeline (`scripts/qa.ps1`): step `qa-telemetry-summarize` invokes the CLI summarizer after tests, producing `telemetry/summary.json` and appending to `telemetry/qa-summary-history.jsonl`.
- Stage 1 can upload `telemetry/summary.json` as an artifact and pass its path to downstream stages.
- Optional gate in QA: set `MAX_QA_FAILURES` (total) and/or `MAX_QA_FAILURES_STEP` (comma‑separated `step=limit` list) to run `telemetry check` and fail when thresholds are exceeded.

## Roadmap

- Optional schema validation using JSON Schema (in addition to current shape checks).
