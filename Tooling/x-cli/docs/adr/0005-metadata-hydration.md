# ADR 0005: Metadata Hydration

- Status: Accepted
- Date: 2025-09-01
- Deciders: x-cli maintainers
- Tags: process, metadata

## Context
The repository requires structured commit and PR metadata for traceability.
Manually copying summaries, change types, and SRS IDs from GitHub issues is
error‑prone and inconsistent across contributors. A repeatable mechanism is
needed to derive this metadata directly from the source issue.

## Decision
- Introduce a metadata hydration step that populates `.codex/metadata.json`
  using `scripts/hydrate_metadata_from_issue.py`.
- The script fetches the GitHub issue referenced by `ISSUE_NUMBER`, extracts the
  summary and any `FGC-REQ-` identifiers, and infers the `change_type` from
  labels.
- `make bootstrap` (via `scripts/bootstrap.sh`) invokes hydration when
  `ISSUE_NUMBER` is set, ensuring agents start with consistent metadata.

### Hydration workflow

`scripts/hydrate_metadata_from_issue.py` uses environment variables to locate
and fetch the source issue:

- `ISSUE_NUMBER` supplies the numeric issue identifier.
- `GITHUB_REPOSITORY` provides the `owner/repo` slug for API requests.
- `GITHUB_TOKEN` (optional) enables authenticated requests when present.

The script writes `.codex/metadata.json` with four fields:

- `summary`: free‑form summary text from the issue body.
- `change_type`: inferred from issue labels.
- `srs_ids`: list of `FGC-REQ-` identifiers discovered in the issue.
- `issue`: the numeric issue reference.

Run the script directly—or invoke `make bootstrap`, which calls it—before
starting work so that up‑to‑date metadata is available.

A unit test ([tests/test_hydrate_metadata_from_issue.py](../../tests/test_hydrate_metadata_from_issue.py))
covers the end-to-end hydration path, verifying `.codex/metadata.json`
is populated as expected and remains exercised in the standard test suite.

### Commit message generation

`scripts/prepare-commit-msg.py` consumes `.codex/metadata.json` when creating
commit messages. The hook resolves each SRS identifier to the latest known
version (appending `@<version>`) and adds `| issue: #<number>` when the metadata
includes an issue reference.

Example output:

```
Update logging docs

codex: impl | SRS: FGC-REQ-DEV-005@1.1 | issue: #42
```

## Consequences
- Commit and PR metadata remain synchronized with the originating issue,
  improving traceability and reducing manual errors.
- Hydration depends on GitHub API access; offline workflows must supply
  `metadata.json` manually.

