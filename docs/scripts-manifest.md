# Scripts Manifest

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/add-token-to-labview/AddTokenToLabVIEW.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
  - RepositoryPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/add-token-to-labview/LocalhostLibraryPaths.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/analyze-vi-package/Analyze-VIP.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/analyze-vi-package/run-local.ps1`
- Inputs:
  - VipArtifactPath [String]
  - MinLabVIEW [String] default="21.0"
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/analyze-vi-package/run-workflow-local.ps1`
- Inputs:
  - VipArtifactPath [String] default="builds/VI Package"
  - MinLabVIEW [String] default="21.0"
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/apply-vipc/ApplyVIPC.ps1`
- Inputs:
  - MinimumSupportedLVVersion [String]
  - VIP_LVVersion [String]
  - SupportedBitness [String]
  - RepositoryPath [String]
  - VIPCPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/build-lvlibp/Build_lvlibp.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
  - RepositoryPath [String]
  - Major [Int32]
  - Minor [Int32]
  - Patch [Int32]
  - Build [Int32] (overridden by total commit count when git history is available)
  - Commit [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/build-vip/build_vip.ps1`
- Inputs:
  - SupportedBitness [String]
  - RepositoryPath [String]
  - VIPBPath [String]
  - Package_LabVIEW_Version [Int32]
  - LabVIEWMinorRevision [String] default="0"
  - Major [Int32]
  - Minor [Int32]
  - Patch [Int32]
  - Build [Int32]
  - Commit [String]
  - ReleaseNotesFile [String]
  - DisplayInformationJSON [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/build/Build.ps1`
- Inputs:
  - RepositoryPath [String]
  - Major [Int32] default=1
  - Minor [Int32] default=0
  - Patch [Int32] default=0
  - Build [Int32] default=1 (overridden by total commit count when git history is available)
  - Commit [String]
  - LabVIEWMinorRevision [Int32] default=3
  - CompanyName [String]
  - AuthorName [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/build/run-local-build.ps1`
- Inputs:
  - RepositoryPath [String]
  - Major [Int32] default=0
  - Minor [Int32] default=0
  - Patch [Int32] default=0
  - Build [Int32] default=1
  - CompanyName [String] default="LabVIEW-Community-CI-CD"
  - AuthorName [String] default="LabVIEW Icon Editor CI"
  - LabVIEWMinorRevision [Int32] default=3
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/close-labview/Close_LabVIEW.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/compute-version/Get-LastTag.ps1`
- Inputs:
  - AsJson [SwitchParameter]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/compute-version/tests/test_first_release_detection.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/generate-release-notes/GenerateReleaseNotes.ps1`
- Inputs:
  - OutputPath [String] default="Tooling/deployment/release_notes.md"
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1`
- Inputs:
  - LVVersion [String]
  - Arch [String]
  - ProjectFile [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/missing-in-project/RunMissingCheckWithGCLI.ps1`
- Inputs:
  - LVVersion [String]
  - Arch [String]
  - ProjectFile [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1`
- Inputs:
  - SupportedBitness [String]
  - RepositoryPath [String]
  - VIPBPath [String]
  - Package_LabVIEW_Version [Int32]
  - LabVIEWMinorRevision [String] default="0"
  - Major [Int32]
  - Minor [Int32]
  - Patch [Int32]
  - Build [Int32]
  - Commit [String]
  - ReleaseNotesFile [String]
  - DisplayInformationJSON [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/prepare-labview-source/Prepare_LabVIEW_source.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
  - RepositoryPath [String]
  - LabVIEW_Project [String]
  - Build_Spec [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/rename-file/Rename-file.ps1`
- Inputs:
  - CurrentFilename [String]
  - NewFilename [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/restore-setup-lv-source/RestoreSetupLVSource.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
  - RepositoryPath [String]
  - LabVIEW_Project [String]
  - Build_Spec [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/revert-development-mode/RevertDevelopmentMode.ps1`
- Inputs:
  - RepositoryPath [String]
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String] default='64'
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/revert-development-mode/run-dev-mode.ps1`
- Inputs:
  - RepositoryPath [String]
  - SupportedBitness [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/run-unit-tests/RunUnitTests.ps1`
- Inputs:
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/set-development-mode/run-dev-mode.ps1`
- Inputs:
  - RepositoryPath [String]
  - SupportedBitness [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/set-development-mode/Set_Development_Mode.ps1`
- Inputs:
  - RepositoryPath [String]
  - Package_LabVIEW_Version [String]
  - SupportedBitness [String] default='64'
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/actions/unit-tests/unit_tests.ps1`
- Inputs:
  - RepositoryPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/.github/scripts/dump-gcli-help.ps1`
- Inputs:
  - OutputPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/scripts/check-build-task.ps1`
- Inputs:
  - TasksPath [String] default=".vscode/tasks.json"
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/scripts/get-package-lv-version.ps1`
- Inputs:
  - RepositoryPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/scripts/read-library-paths.ps1`
- Inputs:
  - RepositoryPath [String]
  - SupportedBitness [String]
  - FailOnMissing [SwitchParameter]
  - IniPath [String]
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/Test/AnalyzeTask.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/Test/BuildTask.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/Test/DevMode.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/Test/DevModeTasks.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

## `/mnt/c/repos/labview-icon-editor-community-ci-cd/Test/ModifyVIPBDisplayInfo.Tests.ps1`
- Inputs: *(none declared)*
- Outputs: *(not explicitly declared)*

