# Stage 1 Invocation

The `scripts/invoke-stage1.py` wrapper validates input before starting the codex agent.

## Schema

Requests must follow `.codex/schema/invoke.schema.json` and include:

- `summary` – one paragraph describing the change.
- `change_type` – `spec`, `impl`, or `both`.
- `srs_ids` – array of `FGC-REQ-*` identifiers.
- `acceptance` – array of objective acceptance criteria.
- `plan` – high-level patch plan.

## SRS ID Validation

`invoke-stage1.py` ensures every entry in `srs_ids` maps to a registered
requirement. The script checks for a matching document under `docs/srs/` via
the SRS API (`src/SrsApi`).

If any ID is unknown, Stage 1 aborts and prints a message like:

```
Unknown SRS IDs: TEST-REQ-XXX-001 (placeholder). Register new requirements via
src/SrsApi before running Stage 1.
```

To remediate, replace the placeholder with the actual ID, create the missing
`docs/srs/<SRS-ID>.md` file, and ensure it is registered through the SRS API.

## Usage

```bash
scripts/invoke-stage1.py request.json -- ./scripts/bootstrap.sh
```

If the payload passes validation, the command following the JSON file is executed. Without a command the script only validates the request.

To automatically dispatch the [Stage 1 Telemetry workflow](../.github/workflows/stage1-telemetry.yml) after the command succeeds, add `--dispatch-telemetry` and ensure `GITHUB_TOKEN` (or `--token`) is set. The script records the resulting run ID in `.codex/stage1_run_id` for use by Stage 2.

```bash
scripts/invoke-stage1.py request.json --dispatch-telemetry -- ./scripts/bootstrap.sh
```

## Stage 1 Telemetry

Stage 1 Telemetry reads `.codex/telemetry.json`, generates `telemetry/summary.json`, and uploads both as artifacts. Stage 2 cannot start until these artifacts are available.

## Example

```json
{
  "summary": "Add example endpoint",
  "change_type": "impl",
  "srs_ids": ["FGC-REQ-CLI-001"],
  "acceptance": [
    "Schema validates requests",
    "Example passes smoke test"
  ],
  "plan": "Add wrapper and schema; document invocation"
}
```
