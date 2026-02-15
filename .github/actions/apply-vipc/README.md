# Apply VIPC Dependencies 📦

Ensure a runner has all required LabVIEW packages installed before building or testing. This composite action calls **`ApplyVIPC.ps1`** to apply a `.vipc` **VI Package Configuration** through **g-cli**.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Inputs](#inputs)
3. [Quick-start](#quick-start)
4. [How it works](#how-it-works)
5. [Troubleshooting](#troubleshooting)
6. [License](#license)

---

## Prerequisites
| Requirement | Notes |
|-------------|-------|
| **Windows runner** | LabVIEW and g-cli are Windows only. |
| **LabVIEW 2021 (21.0)** | Matches `labview_version`, or `.lvversion` when omitted. |
| **g-cli** in `PATH` | Used to apply the `.vipc` configuration. Install via **VIPM (JKI)** or include the executable in the runner image. |
| **PowerShell 7** | Composite steps use PowerShell Core (`pwsh`). |

---

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW *major* version that the repo supports. Defaults to `.lvversion` when omitted. |
| `supported_bitness` | **Yes** | `32` or `64` | LabVIEW bitness to target. |
| `repo_root` | **Yes** | `${{ github.workspace }}` | Root path of the repository on disk. |
| `vipc_path` | **Yes** | `Tooling/deployment/runner_dependencies.vipc` | Path (relative to `repo_root`) of the VI Package Configuration to apply. |

---

## Quick-start
```yaml
# .github/workflows/ci-composite.yml (excerpt)
steps:
  - uses: actions/checkout@v4
  - name: Install LabVIEW dependencies
    uses: ./.github/actions/apply-vipc
    with:
      supported_bitness: 64
      repo_root: ${{ github.workspace }}
      vipc_path: Tooling/deployment/runner_dependencies.vipc
```

---

## How it works
1. **Checkout** – pulls the repository to ensure scripts and the `.vipc` file are present.
2. **PowerShell wrapper** – executes `ApplyVIPC.ps1` with the provided inputs.
3. **g-cli invocation** – `ApplyVIPC.ps1` launches **g-cli** to apply the `.vipc` VI Package Configuration (via VIPM) to the specified LabVIEW installation.
4. **Failure propagation** – any error in path resolution, g-cli, or the script causes the step (and job) to fail.

---

## Troubleshooting
| Symptom | Hint |
|---------|------|
| *g-cli executable not found* | Ensure g-cli is installed and on `PATH`. |
| *`.vipc` file not found* | Check `repo_root` and `vipc_path` values. |
| *LabVIEW version mismatch* | Make sure the installed LabVIEW version matches `labview_version` (or `.lvversion` when omitted). |

---

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
