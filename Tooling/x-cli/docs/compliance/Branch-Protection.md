# Branch Protection (Required Checks)

**Required status checks (default):**
- `PR Coverage Gate / coverage`
- `Docs Link Check / lychee`

**How to set**
1. GitHub → Settings → Branches → Default branch rule.
2. Enable **Require status checks to pass** → add the two checks above.
3. Keep **Require branches to be up to date** enabled.

_Infra automation_: `.github/workflows/configure-branch-protection.yml` attempts to apply these; if it lacks admin permission, it opens an issue with these instructions.
