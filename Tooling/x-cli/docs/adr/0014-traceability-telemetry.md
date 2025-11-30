# ADR 0014: Traceability Telemetry

- Status: Accepted
- Date: 2025-09-02
- Deciders: x-cli maintainers
- Tags: traceability, telemetry, srs

## Context
Requirements in `docs/srs` map the specification for X-CLI. Existing tools
capture mappings from requirement identifiers to source files and tests, but we
also need a structured snapshot that records commit evidence so that audits and
automation can reason about coverage over time.

## Decision
  - `scripts/generate-traceability.py` scans `docs/srs` for `FGC-REQ-*` identifiers,
    locates test files under the `tests/` tree with a native Python glob and text
    scan (no external dependencies) and uses `git ls-files` so `.gitignore`
    rules are respected. It then queries `git log` for commits mentioning each
    identifier.
- The script writes the aggregated data to `telemetry/traceability.json` with the
  shape `{ "requirements": [ { "id", "spec", "tests", "commits" } ] }`.
- CI workflows invoke the script and upload the resulting JSON in the telemetry
  artifact bundle. Dashboards and auditors consume this file to verify that every
  requirement has corresponding tests and commit history.
- Stage 3 persists each run's file to a long‑term history store for at least one
  year to satisfy compliance reviews. The most recent entry is kept under
  `telemetry/` and previous versions reside in `telemetry/history/`.
- SRS coverage metrics read `telemetry/traceability.json` to compute coverage
  ratios. Requirements lacking tests or commit entries are reported as coverage
  gaps.
  
In addition, commit summary enrichment writes contextual memory to `.codex/telemetry.json`
and preserves dropped tags in commit trailers (`X-Tags: …`), improving post‑hoc
correlation between CI runs, issues, and requirement coverage.

## Performance

Benchmarking the scan on a repository with ~2 k test files produced:

| Implementation | Mean time |
| --- | --- |
| Python glob/text scan | ~0.26 s |
| ripgrep | ~0.024 s |

Results were captured with `time python scripts/generate-traceability.py` on a synthetic tree containing ~2 k test files. The native approach is roughly 10× slower but avoids the ripgrep dependency. Expect near-linear scaling with repository size; the SRS requires a 2 k-file scan to finish within five seconds.
Unit tests exercise both flat and nested ~2 k-file layouts to ensure the implementation stays within this five-second budget.

## Consequences
- Contributors must run the generator or rely on CI to refresh
  `telemetry/traceability.json` when adding or updating requirements.
- Dashboards and audits can automatically surface missing tests or commit
  evidence, improving visibility into specification coverage.
- Storing historical snapshots increases artifact retention needs and requires
  periodic pruning beyond the one‑year retention policy.
  - Relying on a Python glob/text scan instead of ripgrep removes an external
    dependency at the expense of performance on large trees (~0.26 s vs 0.024 s when
    scanning ~2k files in local tests). Using `git ls-files` keeps behaviour
    consistent with ripgrep by honouring `.gitignore` patterns.
