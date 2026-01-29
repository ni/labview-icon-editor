# Close LabVIEW 💤

Run **`Close_LabVIEW.ps1`** to terminate a running LabVIEW instance via g-cli.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW 2021 (21.0) to close. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |

## Quick-start
```yaml
- uses: ./.github/actions/close-labview
  with:
    minimum_supported_lv_version: 2021
    supported_bitness: 64
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

