# Applying the Design Pack

## Option A — Use the ZIP
1. Unzip `x-cli-design-pack.zip` at the root of your repository.
2. Review and adjust any paths or naming conventions in:
   - `docs/traceability.yaml`
   - `.github/workflows/design-lock.yml` (branch names; runs design validation script)
3. Stage, commit, and open the PR using the updated `PR_DESCRIPTION.md` template (includes Codex metadata JSON, Agent Checklist, and AGENTS.md digest lines) as the body.
4. Run a design review; when approved, change the first line of `/docs/Design.md` to `**Status:** Approved`.

## Option B — Apply the Patch
1. Save `x-cli-design-pack.patch` at repo root.
2. Run: `git apply x-cli-design-pack.patch`
3. Verify files created, then commit and open a PR.
4. Proceed with review and flip status to **Approved** before merge.

## Manual README/CONTRIBUTING updates
- Paste `README.snippet.md` into your README under a "Design" section.
- Paste `CONTRIBUTING.snippet.md` into CONTRIBUTING.md.
