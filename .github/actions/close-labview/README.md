# Close LabVIEW 💤

Run **`Close_LabVIEW.ps1`** to terminate a running LabVIEW instance via g-cli.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW 2021 (21.0) to close. Defaults to `.lvversion` and fails if it conflicts. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |

## Quick-start
```yaml
- uses: ./.github/actions/close-labview
  with:
    supported_bitness: 64
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

