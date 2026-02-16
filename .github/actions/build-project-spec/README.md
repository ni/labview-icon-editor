# Build Project Spec

Call **`BuildProjectSpec.ps1`** to execute a LabVIEW project build specification via LabVIEWCLI.

Behavior notes:
- Canonical script path: `.github/actions/build-lvlibp/BuildProjectSpec.ps1`.
- Shared pre-steps: staged `MassCompile` + Icon Editor source synchronization.
- Execution path: LabVIEWCLI `ExecuteBuildSpec`.
- Spec type contract:
  - `PackedLibrary`: defaults to `Editor Packed Library` and `resource/plugins/lv_icon.lvlibp`.
  - `SourceDistribution`: requires explicit `build_spec_name` and `output_relative_path`.

Compatibility note:
- `.github/actions/build-lvlibp` remains available as a compatibility wrapper for packed-library builds.
