# Preinstalled Tools (Base Container)

This document lists the language runtimes and tools that ship with the base container.
Agent setup scripts shall **skip** installation of these when present.

- Python **3.12**
- Node.js **20**
- Ruby **3.4.4**
- Rust **1.89.0**
- Go **1.24.3**
- Bun **1.2.14**
- PHP **8.4**
- Java **21**
- Swift **6.1**

> Notes
> - PowerShell (`pwsh`) is **not** included by default. `x-cli` installs it during setup (see `scripts/setup_codex_env.sh`).
> - This list may evolve; changes require maintainer approval and an ADR.
