# Composite GitHub Actions

This repository defines several reusable [composite actions](https://docs.github.com/actions/creating-actions/creating-a-composite-action) in [`.github/actions`](../../../.github/actions). These actions wrap common LabVIEW build and test tasks and can be called from workflows in this or other repositories. Workflows such as [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) rely on the [`build-lvlibp`](../../../.github/actions/build-lvlibp) and [`build-vip`](../../../.github/actions/build-vip) actions for their build steps.

| Action | Description |
|---|---|
| [add-token-to-labview](../../../.github/actions/add-token-to-labview) | Adds a `LocalHost.LibraryPaths` token to the LabVIEW INI. |
| [apply-vipc](../../../.github/actions/apply-vipc) | Installs runner dependencies for a given LabVIEW version and bitness. |
| [auto-issue-branch](../../../.github/actions/auto-issue-branch) | Automatically creates branches for issues with required metadata; used by [auto-issue-branch workflow](../../../.github/workflows/auto-issue-branch.yml). |
| [build](../../../.github/actions/build) | **Deprecated**: previously orchestrated the full build and packaging process. |
| [build-lvlibp](../../../.github/actions/build-lvlibp) | Creates the editor packed library. |
| [build-vip](../../../.github/actions/build-vip) | Updates a VIPB file and builds the VI package. |
| [close-labview](../../../.github/actions/close-labview) | Gracefully shuts down a LabVIEW instance after build steps to free runner resources. |
| [compute-version](../../../.github/actions/compute-version) | Determines the semantic version from commit history and labels. |
| [generate-release-notes](../../../.github/actions/generate-release-notes) | Generates a `release_notes.md` summarizing recent commits for use in changelogs or release drafts. |
| [missing-in-project](../../../.github/actions/missing-in-project) | Checks a project for missing files using `MissingInProjectCLI.vi`. |
| [modify-vipb-display-info](../../../.github/actions/modify-vipb-display-info) | Updates display information in a VIPB file. |
| [prepare-labview-source](../../../.github/actions/prepare-labview-source) | Prepares LabVIEW sources for builds. |
| [rename-file](../../../.github/actions/rename-file) | Renames a file on disk. |
| [restore-setup-lv-source](../../../.github/actions/restore-setup-lv-source) | Reverts prepared sources back to their packaged state. |
| [revert-development-mode](../../../.github/actions/revert-development-mode) | Restores the repository after development mode. |
| [run-unit-tests](../../../.github/actions/run-unit-tests) | Executes LabVIEW unit tests via g-cli. |
| [set-development-mode](../../../.github/actions/set-development-mode) | Configures the repository for development mode. |

Each action directory includes a `README.md` and `action.yml` with full usage details.
