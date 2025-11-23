# Apply VIPC Dependencies 📦

Ensure a runner has all required LabVIEW packages installed before building or testing. This composite action calls **`ApplyVIPC.ps1`** to apply a `.vipc` container through the **VIPM CLI**.

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
| **Windows runner** | LabVIEW and VIPM CLI are Windows only. |
| **LabVIEW** `>= 2021` | Must match `package_labview_version` (typically derived from the `.vipb`). |
| **VIPM CLI** in `PATH` | Used to apply the `.vipc` container. Install from VIPM. |
| **PowerShell 7** | Composite steps use PowerShell Core (`pwsh`). |

---

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `package_labview_version` | **Yes** | `2021` | LabVIEW version used to apply the `.vipc` file (typically derived from the `.vipb`). |
| `supported_bitness` | **Yes** | `32` or `64` | LabVIEW bitness to target. |
| `repository_path` | **Yes** | `${{ github.workspace }}` | Root path of the repository on disk. |
| `vipc_path` | **Yes** | `Tooling/deployment/runner_dependencies.vipc` | Path (relative to `repository_path`) of the container to apply. |

---

## Quick-start
```yaml
# .github/workflows/ci.yml (excerpt)
steps:
  - uses: actions/checkout@v4
  - name: Install LabVIEW dependencies
    uses: ./.github/actions/apply-vipc
    with:
      package_labview_version: 2024
      supported_bitness: 64
      repository_path: ${{ github.workspace }}
      vipc_path: Tooling/deployment/runner_dependencies.vipc
```

---

## How it works
1. **Checkout** – pulls the repository to ensure scripts and the `.vipc` file are present.
2. **PowerShell wrapper** – executes `ApplyVIPC.ps1` with the provided inputs.
3. **VIPM CLI invocation** – `ApplyVIPC.ps1` launches **vipm install** to apply the `.vipc` container to the specified LabVIEW installation.
4. **Package diffing** – before/after applying, the script compares installed packages against the VIPC; it skips install if already compliant and fails if post-check still shows missing/mismatched packages. A summary JSON is written (`summary-json` output) for downstream steps.
5. **Failure propagation** – any error in path resolution, VIPM CLI, or the script causes the step (and job) to fail.

---

## Troubleshooting
| Symptom | Hint |
|---------|------|
| *vipm executable not found* | Ensure VIPM CLI is installed and on `PATH`. |
| *`.vipc` file not found* | Check `repository_path` and `vipc_path` values. |
| *LabVIEW version mismatch* | Make sure the installed LabVIEW version matches both version inputs. |

---

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
