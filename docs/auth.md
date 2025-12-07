# Authentication guidance

Use the lightest-weight flow that keeps secrets out of the repo and off shared images. Defaults below are safe for most contributors and automation.

## TL;DR for this repo
- Prefer SSH. Run:
```pwsh
ssh-keygen -t ed25519 -C "you@example.com"
ssh-agent -s | Out-Null
ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com
# Switch your origin to SSH (replace org/repo with your fork or upstream)
git remote set-url origin git@github.com:org/repo.git
```
- If you stick to HTTPS, only set GCM when installed:
```pwsh
if (Get-Command git-credential-manager-core -ErrorAction SilentlyContinue) {
	git config --global credential.helper manager-core
} else {
	Write-Host "GCM not installed; see https://aka.ms/gcm"
}
```
- Avoid PATs; if you must, cache short-lived: `git config --global credential.helper "cache --timeout=3600"`.

## Human contributors (preferred order)
- SSH keys first: no tokens to copy and plays well across OS/devcontainer/Codespaces.
- HTTPS with Git Credential Manager (GCM) second: single interactive login, no PAT paste.
- Fine-grained PAT only as a fallback: short-lived, repo-scoped, never baked into images or dotfiles.

### SSH setup
```pwsh
ssh-keygen -t ed25519 -C "you@example.com"
ssh-agent -s | Out-Null
ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com  # confirm
# Point origin at SSH (replace org/repo)
git remote set-url origin git@github.com:org/repo.git
```

### HTTPS with Git Credential Manager
```pwsh
# Install GCM if missing (see https://aka.ms/gcm for OS-specific installers)
git config --global credential.helper manager-core
```
- Log in once when prompted; GCM stores/refreshes securely.
- Keep origin as HTTPS for this mode (no PAT paste needed).

### PAT fallback (avoid when possible)
- Use fine-grained PAT, scope to this repo, set an expiration.
- Cache interactively instead of storing on disk:
```pwsh
git config --global credential.helper "cache --timeout=3600"
# next git fetch/push will prompt once and cache for an hour
```
- Never commit or bake PATs into devcontainers/Codespaces; prefer `GITHUB_TOKEN`/GitHub App tokens for automation.

## Automation and CI
- Prefer GitHub Actions `GITHUB_TOKEN` (scoped per repo/run) or a GitHub App installation token.
- Avoid long-lived PATs in pipelines; if unavoidable, store in the host’s secret manager and rotate often.

## Devcontainers and Codespaces
- Do not embed secrets in the image. Rely on SSH agent forwarding or interactive GCM.
- Codespaces injects a token automatically for `git` over HTTPS; SSH still works if you add your key to your GitHub account.

## Quick fixes
- “Permission denied (publickey)”: ensure `ssh-add -l` shows your key; re-add and rerun `ssh -T git@github.com`.
- Pushing over HTTPS keeps prompting: switch to SSH or set `credential.helper manager-core`.
- Remote mismatch: `git remote -v` to inspect; use `git remote set-url origin git@github.com:org/repo.git` (SSH) or HTTPS as needed.
