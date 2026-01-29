# Missing‑In‑Project 💼🔍

Validate that **every file on disk that should live in a LabVIEW project _actually_ appears in the `.lvproj`.**  
The check is executed as the *first* step in your CI pipeline so the run fails fast and you never ship a package or run a unit test with a broken project file.

Internally the action launches the **`MissingInProjectCLI.vi`** utility (checked into the same directory) through **g‑cli**.  
Results are returned as standard GitHub Action outputs so downstream jobs can decide what to do next (for example, post a comment with the missing paths).

---

## Table of Contents
1. [Prerequisites](#prerequisites)  
2. [Inputs](#inputs)  
3. [Outputs](#outputs)  
4. [Quick-start](#quick-start)
5. [Example: Fail-fast workflow](#example-fail-fast-workflow)
6. [How it works](#how-it-works)  
7. [Exit codes & failure modes](#exit-codes--failure-modes)  
8. [Troubleshooting](#troubleshooting)  
9. [Developing & testing locally](#developing--testing-locally)  
10. [License](#license)

---

## Prerequisites
| Requirement            | Notes |
|------------------------|-------|
| **Windows runner**     | LabVIEW and g‑cli are only available on Windows. |
| **LabVIEW 2021 (21.0)**  | Must match the *numeric* version you pass in **`lv-ver`**. |
| **g‑cli** in `PATH`    | The action calls `g-cli --lv-ver …`. Install via **VIPM (JKI)** or copy the executable into the runner image. |
| **PowerShell 7**       | Composite steps use PowerShell Core (`pwsh`). |

---

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `lv-ver` | **Yes** | `2021` | LabVIEW *major* version number that should be used to run `MissingInProjectCLI.vi` |
| `arch` | **Yes** | `32` or `64` | Bitness of the LabVIEW runtime to launch |
| `project-file` | No | `source/MyPlugin.lvproj` | Path (absolute or relative to repository root) of the project to inspect. Defaults to **`lv_icon.lvproj`** |

---

## Outputs
| Name | Type | Meaning |
|------|------|---------|
| `passed` | `true \| false` | `true` when *no* missing files were detected and the VI ran without error |
| `missing-files` | `string` | Comma‑separated list of *relative* paths that are absent from the project (empty on success) |

---

## Quick-start
```yaml
# .github/workflows/ci-composite.yml  (excerpt)
jobs:
  prepare:
    runs-on: self-hosted-windows-lv
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Verify no files are missing from the project
        id: mip
        uses: ./.github/actions/missing-in-project
        with:
          lv-ver: 2021
          arch: 64

      - name: Print report
        if: ${{ steps.mip.outputs.passed == 'false' }}
        run: echo "Missing: ${{ steps.mip.outputs['missing-files'] }}"
```

---

## Example: Fail-fast workflow
If you want **any** missing file to abort the pipeline immediately, place the step in an *independent* job at the top of your DAG and let every other job depend on it:

```yaml
jobs:
  missing-check:
    runs-on: self-hosted-windows-lv
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/missing-in-project
        with:
          lv-ver: 2021
          arch: 64

  build-package:
    needs: missing-check
    …
```

---

## How it works
1. **Path Resolution**  
   A small PowerShell snippet expands `project-file` to an absolute path and throws if the file doesn’t exist.
2. **Invoke‑MissingInProjectCLI.ps1 wrapper**  
   - Launches `MissingInProjectCLI.vi` through **g‑cli**  
   - Captures the VI’s exit status and writes any missing paths to `missing_files.txt`
   - Translates the outcome into GitHub Action outputs (`passed`, `missing-files`) and an **exit code** (0, 1, 2).
3. **Composite step result**  
   GitHub Actions marks the step (and job) as **failed** if the exit code is non‑zero, causing a fail‑fast pipeline.

---

## Exit codes & failure modes
| Exit | Scenario | Typical fix |
|------|----------|-------------|
| **0** | No missing files; VI ran successfully | Nothing to do |
| **1** | g‑cli or the VI crashed (parsing failed) | Ensure g‑cli is in `PATH`, LabVIEW version matches `lv-ver`, VI dependencies are present |
| **2** | The VI completed and found at least one missing file | Add the file(s) to the project or delete them from disk |

---

## Troubleshooting
| Symptom | Hint |
|---------|------|
| *“g‑cli executable not found”* | Verify g‑cli is installed and on `PATH` |
| *“Project file not found”* | Double‑check the value of `project-file`; relative paths are resolved against `GITHUB_WORKSPACE` |
| *Step times out* | Large projects can be slow to load; consider bumping the job’s default timeout. |

---

## Developing & testing locally
```powershell
pwsh -File .github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1 `
      -LVVersion 2021 `
      -Arch 64 `
      -ProjectFile 'C:\path	o\MyProj.lvproj'

echo "Exit code: $LASTEXITCODE"
type .github/actions/missing-in-project/missing_files.txt
```

---

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
