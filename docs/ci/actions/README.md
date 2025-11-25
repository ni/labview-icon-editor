# Composite GitHub Actions

This repository defines several reusable [composite actions](https://docs.github.com/actions/creating-actions/creating-a-composite-action) in [`scripts`](../../../scripts). These actions wrap common LabVIEW build and test tasks and can be called from workflows in this or other repositories. Workflows such as [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) rely on the [`build-lvlibp`](../../../scripts/build-lvlibp) and [`build-vip`](../../../scripts/build-vip) actions for their build steps.

| Action | Description |
|---|---|
| [add-token-to-labview](../../../scripts/add-token-to-labview) | Adds a `LocalHost.LibraryPaths` token to the LabVIEW INI. |
| [apply-vipc](../../../scripts/apply-vipc) | Installs runner dependencies for a given LabVIEW version and bitness. |
| [auto-issue-branch](../../../scripts/auto-issue-branch) | Automatically creates branches for issues with required metadata; used by [auto-issue-branch workflow](../../../.github/workflows/auto-issue-branch.yml). |
| [build](../../../scripts/build) | **Deprecated**: previously orchestrated the full build and packaging process. |
| [build-lvlibp](../../../scripts/build-lvlibp) | Creates the editor packed library. |
| [build-vip](../../../scripts/build-vip) | Updates a VIPB file and builds the VI package. |
| [close-labview](../../../scripts/close-labview) | Gracefully shuts down a LabVIEW instance after build steps to free runner resources. |
| [compute-version](../../../scripts/compute-version) | Determines the semantic version from commit history and labels. |
| [generate-release-notes](../../../scripts/generate-release-notes) | Generates a `release_notes.md` summarizing recent commits for use in changelogs or release drafts. |
| [missing-in-project](../../../scripts/missing-in-project) | Checks a project for missing files using `MissingInProjectCLI.vi`. |
| [modify-vipb-display-info](../../../scripts/modify-vipb-display-info) | Updates display information in a VIPB file. |
| [prepare-labview-source](../../../scripts/prepare-labview-source) | Prepares LabVIEW sources for builds. |
| [rename-file](../../../scripts/rename-file) | Renames a file on disk. |
| [restore-setup-lv-source](../../../scripts/restore-setup-lv-source) | Reverts prepared sources back to their packaged state. |
| [revert-development-mode](../../../scripts/revert-development-mode) | Restores the repository after development mode. |
| [bind-development-mode](../../../scripts/bind-development-mode) | Binds/unbinds dev mode per bitness, emits JSON status, and supports dry-run/force (BIND-001..BIND-014). |
| [run-unit-tests](../../../scripts/run-unit-tests) | Executes LabVIEW unit tests via g-cli. |
| [set-development-mode](../../../scripts/set-development-mode) | Configures the repository for development mode. |

Each action directory includes a `README.md` and `action.yml` with full usage details.

