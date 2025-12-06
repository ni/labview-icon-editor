# Test Telemetry Analysis

This document explains how the repository captures and analyzes test telemetry.
See [FGC-REQ-TEL-001](srs/FGC-REQ-TEL-001.md) for the canonical requirements on
telemetry analyses.

The repository captures per-test telemetry in `artifacts/test-telemetry.jsonl`.
Each JSON object records the test name, language, external dependencies,
outcome, and duration. The `scripts/analyze_telemetry.py` helper examines this
file after tests complete. It computes average duration for each test, warns
about slow tests, and fails if the same external dependency repeatedly causes failures. A concise summary
with aggregated slow test and dependency-failure counts is written to
`artifacts/telemetry-summary.json` so that subsequent agents can quickly review
results without re-running the full analysis.

A rolling history of these summaries is kept in
`artifacts/telemetry-summary-history.jsonl`. Each line records the timestamp and
counts from a single run, retaining only the most recent entries (default 20).
This lightweight log lets teams spot regressions without downloading full
telemetry logs.

Stage 3 restores the previous run’s `telemetry-history` artifact so it can
compare the current summary against prior results. The latest summary is kept at
`telemetry/history/summary-latest.json`, while timestamped snapshots
(`summary-<timestamp>.json`) are appended for auditability. Each run also stores a
machine-readable diff (`diff-<timestamp>.json`) and updates
`telemetry/history/diff-latest.json`. The entire `telemetry/history/` directory is
uploaded as the `telemetry-history` artifact and retained for 30 days per
GitHub’s artifact policy.

CI also publishes the `telemetry/history/` directory to the repository's
`gh-pages` branch so the same summaries and diffs are available via GitHub
Pages. This Pages-backed store keeps the most recent 90 days of history,
pruning older `summary-*.json` and `diff-*.json` files on upload. The artifact
provides a short-lived handoff between CI stages, while the Pages copy offers
longer retention and public access. Once the artifact expires, the Pages
history remains accessible until its 90‑day window elapses.

See [Telemetry History](telemetry-history.md) for details on retention and
access controls. Because the Pages site is publicly readable, telemetry must
contain only aggregate build and test statistics—avoid secrets or personal
data. Updates to the Pages branch require a `GITHUB_TOKEN` with `contents:
write`, limiting write access to CI workflows and repository maintainers.

## Manifest integrity

Stage 2 emits `telemetry/manifest.json` that records each artifact's path and
SHA‑256 checksum. Stage 3 validates this manifest before running any tests by
invoking `scripts/validate-manifest.ps1`. The script ensures every listed file
exists and its computed checksum matches the manifest entry. A mismatch causes
the job to fail immediately so corrupted artifacts never execute.

Regenerate the manifest after rebuilding artifacts with:

```
./scripts/generate-manifest.sh
```

This helper recomputes the SHA‑256 hashes for the `dist/` binaries and
`telemetry/summary.json` and rewrites `telemetry/manifest.json` with the new
values.

## Derived fields (human‑readable)

To make CI summaries easier to scan without changing machine‑readable data, the
pipeline augments `telemetry/summary.json` with human‑friendly sibling fields:

- For numeric second values (`*_seconds`), a `*_human` string is added using
  1–2 decimals with an `s` suffix (for example, `duration_seconds: 123.456`
  gains `duration_human: "123.46s"`).
- For byte counts (`*_bytes`), a `*_human` string is added using SI units
  (`kB`, `MB`, `GB`) for readability (for example, `artifact_bytes: 1048576`
  gains `artifact_human: "1.05MB"`).

These fields are additive and idempotent; the original numeric keys remain for
automation. The augmentation runs in Stage 1/2 and in the combined Stage 2→3
workflow before the manifest step so downstream consumers see a consistent
summary shape.

## Dashboards and Alerts

The `scripts/render_telemetry_dashboard.py` helper turns the rolling history
into a simple HTML dashboard (`telemetry-dashboard.html`) and compares the last
two runs. If slow-test counts or total dependency failures increase, the script
emits GitHub Actions warnings and returns a non-zero status so regressions are
immediately visible.

When a regression is detected, the script can also notify teams. Supply a Slack
webhook URL via `--slack-webhook` or the `SLACK_WEBHOOK_URL` environment
variable, or provide an email recipient with `--alert-email` or `ALERT_EMAIL`.
The message summarizes the regression and links to the published dashboard
(`TELEMETRY_DASHBOARD_URL` can override the default `telemetry-dashboard.html`).

Add a workflow step after telemetry analysis:

```
- name: Render telemetry dashboard
  run: python scripts/render_telemetry_dashboard.py
```

The generated dashboard and history file are uploaded as artifacts for trend
tracking and published to GitHub Pages so the latest run is available at
`telemetry-dashboard.html` without downloading artifacts.

## Thresholds

The script accepts two optional environment variables to tune its behavior:

- `SLOW_TEST_FACTOR` (float, default `2`): tests whose average runtime exceeds
  this multiple of the global average emit GitHub Actions warnings but do not
  fail the build.
- `MAX_DEPENDENCY_FAILURES` (int, default `0`): if a dependency appears in more
  failed tests than this count, the script exits with a non-zero status to
  surface the flakiness.
- `TELEMETRY_HISTORY_LIMIT` (int, default `20`): number of summary entries to
  retain in `telemetry-summary-history.jsonl`.

Adjust thresholds in the workflow step:

```
- name: Analyze telemetry
  run: python scripts/analyze_telemetry.py
  env:
    SLOW_TEST_FACTOR: 3
    MAX_DEPENDENCY_FAILURES: 1
```

## Expanding Coverage

Start with generous thresholds and tighten them as more tests record telemetry.
Add `external_dep` markers to tests to expand dependency coverage gradually and
watch for emerging hotspots before enforcing stricter limits.

## QA Telemetry

`scripts/qa.sh` and `scripts/qa.ps1` emit JSONL entries to
`artifacts/qa-telemetry.jsonl` capturing start/end times, durations, and
pass/fail status for each QA step. After the run, execute
`scripts/analyze_qa_telemetry.py` to summarize average step durations and count
failures. The script writes `qa-telemetry-summary.json` and maintains a rolling
history in `qa-telemetry-summary-history.jsonl`.

To track trends across machines, set `QA_TELEMETRY_ARCHIVE` to a JSONL file on a
shared volume. Each analysis appends a timestamped summary so agents can spot
recurring flaky steps and regressions without copying artifacts between runs.

Render a trend dashboard and surface recurring failures with
`scripts/render_qa_telemetry_dashboard.py`. It produces
`qa-telemetry-dashboard.html` and exits non-zero when the same step fails across
consecutive runs, optionally sending Slack or email alerts using the same
environment variables as test telemetry.

These helpers enable cross-run QA trend analysis without manual log review.

## SRS Omission Telemetry

Telemetry can include a boolean `srs_omitted` flag that records whether a run
supplied any SRS IDs. Tracking this field over time highlights how often
contributors skip SRS mapping.

After collecting telemetry, analyze omission rates with the helper script:

```
- name: Analyze SRS telemetry
  run: python scripts/analyze_srs_telemetry.py
```

The script writes `srs-telemetry-summary.json` and appends a timestamped record
to `srs-telemetry-summary-history.jsonl`. Feed this history file to
`scripts/render_telemetry_dashboard.py` to produce a simple HTML chart showing
omission trends:

```
- name: Render SRS telemetry dashboard
  run: python scripts/render_telemetry_dashboard.py artifacts/srs-telemetry-summary-history.jsonl
```

Monitoring the omission rate guides automation priorities—spikes in
`srs_omitted` shall trigger automation of SRS ID capture or improved
tooling to keep specification coverage high.

## Agent Feedback in Telemetry (optional)

Contributors can attach freeform notes to telemetry so future sessions see
previous decisions. Store a lightweight JSON record under a project-local path
(e.g., `.codex/telemetry.json`) that includes an `agent_feedback` field. Example:

```
{
  "entries": [
    {
      "modules_inspected": [],
      "checks_skipped": [],
      "agent_feedback": "investigated slow tests"
    }
  ]
}
```

## Exception Details in Telemetry (optional)

Telemetry entries can optionally record ``exception_type`` and
``exception_message`` to capture error information for later investigation.

## Command Context in Telemetry (optional)

Telemetry entries may record the ``command`` executed and its ``exit_status``.
Capturing arguments and status code provides context when tools fail or behave
unexpectedly, allowing future contributors to diagnose issues without rerunning
the original command.

## Hang Diagnostics in Telemetry (optional)

The `tests/TestUtil/run.py` helper can record hang diagnostics to a local
telemetry JSON whenever a subprocess exceeds a configurable runtime threshold or
times out. Entries capture the command, exit status when available, the
duration or timeout, and a Python stack trace.

## Stage 3 Baseline

Stage 3 runs `scripts/telemetry-publish.ps1` to summarize the latest
`telemetry/summary.json` and compare it against
`telemetry/history/summary-latest.json`. On each run the script writes a
timestamped snapshot, refreshes `summary-latest.json`, and saves a
machine-readable diff in the history directory (also copied to
`telemetry/history/diff-latest.json`). When no prior history exists—such as on the
first execution—the script emits `Baseline established. No previous telemetry to
compare.` and proceeds without a diff. This establishes an initial baseline so
that subsequent Stage 3 runs can report regressions without flagging the
bootstrap run as a failure.
