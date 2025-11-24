# Full Build 🛠️

Runs **`Build.ps1`** to clean, compile, and package the LabVIEW Icon Editor.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root on disk. |
| `major` | **Yes** | `1` | Major version number. |
| `minor` | **Yes** | `0` | Minor version number. |
| `patch` | **Yes** | `0` | Patch version number. |
| `build` | **Yes** | `1` | Build number. |
| `commit` | **Yes** | `abcdef` | Commit identifier embedded in metadata. |
| `labview_minor_revision` | No (defaults to `3`) | `3` | LabVIEW minor revision. |
| `company_name` | **Yes** | `Acme Corp` | Company for display info. |
| `author_name` | **Yes** | `Jane Doe` | Author for display info. |

## Quick-start
```yaml
- uses: ./.github/actions/build
  with:
    repository_path: ${{ github.workspace }}
    major: 1
    minor: 0
    patch: 0
    build: 1
    commit: ${{ github.sha }}
    company_name: Example Co
    author_name: CI
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
