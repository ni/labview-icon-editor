# pylavi-validate

Composite action that runs `vi_validate` (pylavi) against the repo using the LabVIEW version synced from `.lvversion` (or an explicit input that must match). Prefers `runner-cli` when available (set `LVIE_REQUIRE_RUNNER_CLI=1` to disable fallbacks). Any configured `absolute_roots` are redacted in CI output and the uploaded log artifact. The step summary includes top-offender tables when available, including optional baseline/delta details.

## Inputs
- `config_path` (default: `Tooling/pylavi/vi-validate.yml`)
- `labview_numeric` (optional; year or numeric, e.g., `2021` or `21.0`; must match `.lvversion` if provided)
- `python_version` (default: `3.x`)
- `label` (default: `pylavi`)
- `report_only` (default: `true`)
- `absolute_roots` (optional; semicolon-delimited; keep sensitive paths out of the repo)
- `upload_offenders` (default: `true`)
- `offenders_name` (default: `pylavi-validate-offenders`)
- `upload_log` (default: `true`)
- `log_name` (default: `pylavi-validate-log`)
- `baseline_path` (optional; baseline offenders report path for delta checks)
- `baseline_required` (default: `false`; fail if baseline is missing)
- `fail_on_delta` (default: `false`; fail if new offenders appear vs baseline)

## Environment
- `LVIE_RUNNER_CLI_PATH` (optional; prefer this runner-cli binary)
- `LVIE_REQUIRE_RUNNER_CLI=1` to fail if runner-cli is unavailable (disables PowerShell fallback)
- `LVIE_PYLAVI_BASELINE_PATH` (optional; baseline path when `baseline_path` input is empty)
- `LVIE_PYLAVI_BASELINE_REQUIRED=1` (optional; same as `baseline_required`)
- `LVIE_PYLAVI_FAIL_ON_DELTA=1` (optional; same as `fail_on_delta`)

## Example (report-only)
```yaml
- name: Validate LabVIEW Files (pylavi)
  uses: ./.github/actions/pylavi-validate
  with:
    label: strict
    report_only: 'true'
```

## Example (strict)
```yaml
- name: Validate LabVIEW Files (pylavi)
  uses: ./.github/actions/pylavi-validate
  with:
    report_only: 'false'
```
