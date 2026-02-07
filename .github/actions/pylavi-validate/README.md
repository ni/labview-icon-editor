# pylavi-validate

Composite action that runs `vi_validate` (pylavi) against the repo using the LabVIEW version synced from `.lvversion` (or an explicit input that must match). Any configured `absolute_roots` are redacted in CI output and the uploaded log artifact. The step summary includes top-offender tables when available.

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
