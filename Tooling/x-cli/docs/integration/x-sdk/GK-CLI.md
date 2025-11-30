# x-sdk - GitKraken GK-CLI Integration (v3.1.37)

The x-sdk uses GitKraken's GK-CLI to streamline local developer workflows (work items, commits, PRs) across multiple repos. This is optional for CI, but recommended for day-to-day dev.

Version pin: v3.1.37
Repository: https://github.com/gitkraken/gk-cli/tree/v3.1.37

Install
- macOS (Homebrew): `brew install gitkraken-cli`
- Linux (deb/rpm): download v3.1.37 from releases, then `sudo apt install ./gk.deb` or `sudo rpm -i ./gk.rpm`
- Linux (binary): place `gk` in a directory on `PATH`, e.g., `/usr/local/bin`
- Windows (Winget): `winget install gitkraken.cli --version 3.1.37`
- Verify: `gk version`

Quick start
```bash
# Authenticate once
gk auth login

# In your repo root
gk work create "My new work item"

# Make changes  then commit with AI
gk work commit --ai

# Push and open a PR (AI-assisted)
gk work push
gk work pr create --ai
```

CI note
- CI does not require GK-CLI to run x-cli workflows. If you want a light presence check, add a step: `gk version` (ignore failure where GK-CLI is not installed).

See also
- Orchestration samples: `docs/integration/x-sdk/orchestrate-x-cli*.yml`
- ADR: `docs/adr/0022-x-sdk-adopts-gk-cli.md`
