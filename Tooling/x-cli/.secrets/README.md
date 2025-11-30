# Local Secrets

Place your GitHub Personal Access Token (PAT) in `github_token.txt` within this folder to enable local tooling (gh CLI, CI helpers, bootstrap scripts).

- File: `.secrets/github_token.txt`
- Contents: a single line containing the token.
- Scope: `repo` is sufficient for publishing and commenting operations described in this repo.

Security
- This folder is git-ignored: tokens are not committed.
- Only `README.md` and `.gitignore` are tracked under `.secrets/`.

Quick start
1) Create/obtain a PAT with the required scopes (e.g., `repo`).
2) Paste it into `.secrets/github_token.txt` (no extra spaces/newlines).
3) Load it for this session and (optionally) log in gh:
   - Windows: `pwsh -File scripts/ghops/tools/use-local-github-token.ps1 -Login`
   - Linux/macOS: `bash scripts/ghops/tools/use-local-github-token.sh --login`

After loading, `GITHUB_TOKEN` and `GH_TOKEN` are set for this shell and `gh auth status` should report an authenticated session.

