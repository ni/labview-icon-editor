# Agent Bootstrap — GitFlow and Environment Prep

Use the bootstrap scripts to standardize the repository and environment before editing workflows or publishing releases.

## Quick start

```bash
./scripts/agent_bootstrap_gitflow.sh
```

On Windows PowerShell:

```powershell
pwsh scripts/agent_bootstrap_gitflow.ps1
```

## What the script does

- Confirms remotes point at `LabVIEW-Community-CI-CD/x-cli` and fetches upstream.
- Ensures `main` and `develop` branches exist locally and are up to date.
- Initializes `git flow` with `feature/`, `release/`, `hotfix/` prefixes.
- Exports `GITHUB_REPOSITORY=LabVIEW-Community-CI-CD/x-cli` for downstream scripts.
- Checks required GitHub secrets: `GH_ORG_TOKEN`, `GHCR_USER`, `GHCR_TOKEN` (warns if missing).
- Installs PowerShell 7 on Linux runners and prints `pwsh -v`.
- Runs `pre-commit run lint-pwsh-shell --all-files` to ensure workflows use `pwsh`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Missing `develop` branch | Script creates it and pushes to upstream if absent. |
| `gh` command not found | Install GitHub CLI (<https://cli.github.com/>) and log in (`gh auth login`). |
| Secret warning | Run `gh secret set <NAME> -R LabVIEW-Community-CI-CD/x-cli -b '<value>'`. |
| `pwsh` missing on Linux | Script installs via Microsoft package feed; rerun bootstrap. |

## Integration with CI

A dedicated workflow (`bootstrap-check.yml`) runs the bootstrap script in `--dry-run` mode on each PR to ensure prerequisites remain valid.

---

See also:
- `docs/workflows-inventory.md`
- `docs/issues/cleanup-workflows-and-docs.md`
