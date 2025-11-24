# Dev Mode Bind Requires Force (General)

Use this when the bind task fails because LabVIEW is already pointed at another path for the VIPB-derived version/bitness, or when INI tokens are malformed.

## Context (template)
- VIPB: `<path to .vipb>`
- Derived LabVIEW version: `<version from VIPB>`
- Task: `BindDevelopmentMode.ps1 -Mode bind -Bitness <32|64|both>`

## Typical symptoms
- Target INI tokens show `[OTHER-REPO]` (or `[OTHER]`) for the VIPB version/bitness.
- Bind attempt fails with “LocalHost.LibraryPaths points to another path … use -Force to overwrite.”
- Anomalies may include:
  - Target version bound to another repo/path.
  - Suspicious double-rooted token paths (e.g., `C:\...C:\...`).

## Diagnosis
- The canonical LabVIEW.ini for the VIPB version/bitness contains a LocalHost.LibraryPaths entry that points to a different checkout or malformed path. The bind helper refuses to overwrite without Force to avoid clobbering another repo.

## Remediation
1) Overwrite the tokens with Force:
   - VS Code: Terminal → Run Task → **Dev Mode (interactive bind/unbind)** → choose **bind**, set bitness (32/64/both), enable **Force**.
   - CLI: `pwsh .github/actions/bind-development-mode/BindDevelopmentMode.ps1 -RepositoryPath . -Mode bind -Bitness both -Force`
2) If other repos rely on the existing binding, confirm before forcing.
3) Clean suspicious/double-rooted tokens by running unbind with **Force** for the affected version/bitness if not needed.

## Artifacts
- JSON summary: `reports/dev-mode-bind.json` (contains per-bitness status, paths, messages).
