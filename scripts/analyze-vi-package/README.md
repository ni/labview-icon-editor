
# Analyze VI Package (Pester policy suite)

This repo contains:
- `VIPReader.psm1` — helper functions that read a `.vip` directly and parse its `spec`.
- `Analyze-VIP.Tests.ps1` — Pester tests mapped 1:1 to policy requirement IDs.
- `Requirements.md` — normative requirements (policy, version-agnostic).
- `action.yml` — GitHub composite action **Analyze VI Package** to run the tests in CI.

## Local run
```powershell
pwsh -NoProfile -File ./Analyze-VIP.Tests.ps1 -VipArtifactPath "/mnt/data/work/ni_icon_editor-0.0.2.16.vip" -MinLabVIEW "21.0"
```

## Local workflow-style run (mirrors CI job)
```powershell
# Using a directory, .vip file, or downloaded artifact .zip:
pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "builds/vip-stash" -MinLabVIEW "21.0"
# Directly target a specific package or artifact directory (recommended for local validation):
pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "path/to/package.vip" -MinLabVIEW "21.0"
```

## Troubleshooting
- **VIPReader module not found:** Confirm `scripts/analyze-vi-package/VIPReader.psm1` exists (for example, it may be missing if the repo checkout is incomplete).
- **No `.vip` found:** Ensure the package is available under `builds/vip-stash` or explicitly set `VIP_PATH` to the `.vip` file you want analyzed.

## GitHub Actions usage
```yaml
jobs:
  analyze:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./vip-analyzer
        with:
          vip_artifact_path: "/mnt/data/work/ni_icon_editor-0.0.2.16.vip"
          min_labview: "21.0"
```

## Notes
- The workflow script requires a real `.vip` file. If a placeholder artifact such as `vipm-skipped-placeholder.vip` is present (emitted when vipm builds are intentionally skipped), the Analyze-VIP suite will detect it and skip the tests instead of using the placeholder.
- `VIPReader.psm1` lives next to the tests at `scripts/analyze-vi-package/VIPReader.psm1` and is automatically imported by `Analyze-VIP.Tests.ps1` and the workflow wrapper—no manual module import is necessary.

