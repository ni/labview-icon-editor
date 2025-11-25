# Reusable Actions & Scripts

This repository defines reusable build/test tasks under [`scripts`](../../../scripts); many are composite actions, some are plain scripts. Workflows such as [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) rely on the [`build-lvlibp`](../../../scripts/build-lvlibp) and [`build-vip`](../../../scripts/build-vip) actions for their build steps.

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
| [rename-file](../../../scripts/rename-file) | Renames a file on disk. |
| [restore-setup-lv-source](../../../scripts/restore-setup-lv-source) | Reverts prepared sources back to their packaged state. |
| [revert-development-mode](../../../scripts/revert-development-mode) | Restores the repository after development mode. |
| [prepare-labview-source](../../../scripts/prepare-labview-source/README.md) | Script: prepares LabVIEW sources for builds. |
| [bind-development-mode](../../../scripts/bind-development-mode/README.md) | Script: binds/unbinds dev mode per bitness, emits JSON status, supports dry-run/force (BIND-001..BIND-014). |
| [run-unit-tests](../../../scripts/run-unit-tests) | Executes LabVIEW unit tests via g-cli. |
| [set-development-mode](../../../scripts/set-development-mode) | Configures the repository for development mode. |

Each task directory includes a `README.md` (and an `action.yml` when it is a composite action) with usage details.

