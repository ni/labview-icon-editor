# Token Awareness — Org-Level Access

Purpose: help agents quickly understand what GitHub token is in use, whether it carries organization-level scopes, and whether it can see the target org.

Helpers such as `scripts/ghops/tools/get-run-annotations.ps1` run this preflight automatically (unless disabled via `-NoPreflightToken`). If they fail fast with token guidance, follow the steps below before retrying.

## Quick Check

PowerShell:

```
pwsh -File scripts/ghops/tools/token-awareness.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -Json
```

Outputs
- `transport`: `gh` (GitHub CLI) or `rest` (direct API using `GH_TOKEN`/`GITHUB_TOKEN`).
- `scopes`: values from `X-OAuth-Scopes` when available (classic tokens; may be empty for fine‑grained tokens).
- `has_read_org`: true when the token advertises any `*:org` scope (e.g., `read:org`, `admin:org`).
- `can_list_orgs`: true when `/user/orgs` returns at least one org.
- `org` / `org_visible`: owner inferred from `-Repo`/`-Org` and whether it appears in `/user/orgs`.
- `notes`: hints when REST is selected without a token.

## When To Ask For Help

If `transport` is `rest` and `notes` include “No token in GH_TOKEN/GITHUB_TOKEN”, or if `has_read_org` is false but you need org‑level operations, request an org‑scoped token:

Suggested request:

```
I need an org‑scoped PAT to proceed. Please export one of:
  PowerShell:  $Env:GH_TOKEN = '<org‑scoped PAT>'
  POSIX:       export GH_TOKEN='<org‑scoped PAT>'

Minimum scopes (classic PAT): read:org, repo, workflow, checks
For fine‑grained PATs: grant access to the organization and the repository with read permissions for Actions/Checks.
```

## Tips

- `gh` CLI often already holds a token; the script prefers `gh` by default. Use `-Transport rest` to test env tokens only.
- For CI workflows, prefer `${{ secrets.GH_ORG_TOKEN }}` when org‑level access is required; map it to `GH_TOKEN` in steps.
