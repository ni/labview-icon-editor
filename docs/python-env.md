# Python environment

The repository now includes a `.python-version` file that pins **Python 3.12.6** for both local tools and CI. `actions/setup-python` reads the same file, so builds and local runs stay aligned.

## Quick start with pyenv (macOS/Linux/WSL)
- Install pyenv using your package manager (e.g., `brew install pyenv` or the official installer).
- Install and select the pinned version:
  ```bash
  pyenv install --skip-existing 3.12.6
  pyenv local 3.12.6
  python -V  # expect Python 3.12.6
  ```

## Quick start with pyenv-win (Windows)
- Install [pyenv-win](https://github.com/pyenv-win/pyenv-win) and restart your shell so `pyenv` is on PATH.
- Apply the pinned version in this repo:
  ```powershell
  pyenv install 3.12.6
  pyenv local 3.12.6
  pyenv rehash
  python -V  # expect Python 3.12.6
  ```

## Manual install (without pyenv)
- Install Python 3.12.6 from python.org or your package manager.
- Ensure `python -V` resolves to 3.12.6 when run inside the repo (pyenv will take precedence if present).

> Tip: If you already have a virtual environment under `.venv`, recreate it after switching Python versions to avoid mixed-version packages.
