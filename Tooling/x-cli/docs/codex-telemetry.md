# Codex Guard Telemetry

The Codex authorship guard records mirror verification attempts in
`artifacts/codex-auth-validation.jsonl`.

## Fields

- `timestamp` – ISO‑8601 time when the guard ran.
- `pr` – pull request number.
- `author` – GitHub login for the PR author.
- `type` – fixed value `mirror_check`.
- `status` – `pass` when all checks succeed, otherwise `fail`.
- `reason` – one of `label`, `mode`, `author`, `signature_invalid`.
- `head` – first eight characters of the PR head commit.

## Review Cadence

Audit entries are reviewed weekly to confirm guard behavior and spot
unexpected failures. Aggregated telemetry may be processed by automated
jobs for long‑term trends.

## Cross-Agent Telemetry Entries

The helper :func:`codex_rules.telemetry.append_telemetry_entry` stores
per-session metadata in ``.codex/telemetry.json``. Entries must follow
this format:

For local development, `scripts/qa.sh` invokes
`scripts/generate_telemetry_stub.py` to create a minimal
`.codex/telemetry.json` when none exists so telemetry checks can run.

### Required fields

- `modules_inspected` – list of module paths or names analysed.
- `checks_skipped` – list of QA checks intentionally skipped.

### Optional fields

- `ci_log_paths` – list of paths to CI log files.
- `failing_tests` – list of failing test identifiers.
- `agent_feedback` – freeform summary of the session.
- `command` – executed command as a list of strings.
- `exit_status` – integer exit code for `command`.
- `exception_type` / `exception_message` – diagnostic details when an error occurs.
- `srs_ids` – list of related SRS identifiers.
- `timestamp` – ISO‑8601 timestamp, added automatically if omitted.
- `srs_omitted` – boolean derived from `srs_ids` indicating omission.

Singular strings supplied for list fields are normalised to one-item
lists. Supplying non-string items for these fields results in a
``ValueError``.
