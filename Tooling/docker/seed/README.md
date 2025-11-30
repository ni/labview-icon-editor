# Seed Docker helper

Use the Seed CLI via a locally built Docker image. The repo is bind-mounted to `/workspace` inside the container, so reference paths accordingly. Docker Desktop is assumed to be available and running. This helper is optional—skip it if you do not use Docker.

- Build context: `Tooling/seed` (vendored source + Dockerfile)
- Tag produced: `seed-local:latest`
- Compose file: `Tooling/docker/seed/docker-compose.yml` (builds locally; no pulls)

## Quick start
Show Seed help (auto-builds if needed):
```
docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed
```

Run a Seed command:
```
docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed seed <args>
# example: seed vipb json --input /workspace/Tooling/deployment/seed.vipb --output /workspace/out.json
```

Open a shell:
```
docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed bash
```

## Env-driven invocation
The entrypoint respects GitHub Action-style env vars. Set them and pass `-e` when running:

PowerShell:
```
$env:INPUT_MODE='vipb2json'
$env:INPUT_INPUT='/workspace/Tooling/deployment/seed.vipb'
$env:INPUT_OUTPUT='/workspace/artifacts/seed/metadata.json'
docker compose -f Tooling/docker/seed/docker-compose.yml run --rm -e INPUT_MODE -e INPUT_INPUT -e INPUT_OUTPUT seed
```

Bash:
```
INPUT_MODE=vipb2json INPUT_INPUT=/workspace/Tooling/deployment/seed.vipb INPUT_OUTPUT=/workspace/artifacts/seed/metadata.json \
  docker compose -f Tooling/docker/seed/docker-compose.yml run --rm -e INPUT_MODE -e INPUT_INPUT -e INPUT_OUTPUT seed
```

## Common tasks
- Convert VIPB to JSON: `seed vipb json --input /workspace/path/to/package.vipb --output /workspace/out.json`
- Apply JSON patch to VIPB: `seed vipb patch --input /workspace/path/to/package.vipb --patch /workspace/patch.json --output /workspace/patched.vipb`
- Smoke tests: `pwsh ./tests/ConversionError.Tests.ps1` (inside the container shell)

## Notes
- Use `/workspace/...` paths inside the container (that's where the repo mounts).
- The image builds locally; retag via `image:` in `docker-compose.yml` if you want a different name.
- Rebuild after source changes: `docker compose -f Tooling/docker/seed/docker-compose.yml build --no-cache seed` (VS Code tasks run `docker compose ... build seed` before invoking the container).
- If you prefer not to use Docker, run Seed directly from `Tooling/seed` with `dotnet` after restoring its dependencies.
- Compose is set to `pull_policy: never` to avoid registry pulls; first run will build the image locally.

## Containerized runner (Linux/WSL/Windows)
Run the full Seed + Analyze-VIP flow inside a tools container that has PowerShell, Pester, and the Docker CLI (binds the host Docker socket):
```
pwsh -NoProfile -File ./scripts/run-seed-runner.ps1
```
Prereqs: Docker running on the host, and `/var/run/docker.sock` available to the container (Docker Desktop with WSL 2 backend works). The repo is mounted at `/workspace` inside the runner.
- Trust and pinning:
  - Pester is fetched from the NuGet CDN by default (`https://globalcdn.nuget.org/packages/pester.<version>.nupkg`) with TLS validation and a pinned checksum (default 5.7.1 / SHA256 `3c6dad5fb143faf19709dfb28c31c873989944705a087e160e23b7ce462e37a1`).
  - If your network MITMs TLS, pass your root CA as base64 to the build: `export CA_CERT_BUNDLE_BASE64=$(base64 -w0 ./my-root-ca.crt)` then rebuild. You can override the Pester version/hash/url via `PESTER_VERSION`, `PESTER_SHA256`, and `PESTER_URL` to keep the pin in sync.
  - Last resort: set `ALLOW_INSECURE_PESTER_DOWNLOAD=1` to allow `curl -k` with checksum validation (only if you cannot supply a trusted CA).
  - Optional GitHub source: publish the Pester `.nupkg` you trust to a GitHub release, then set `PESTER_GH_REPO=owner/repo`, optionally `PESTER_GH_TAG=<tag>` and `PESTER_GH_ASSET=<asset-name>` (defaults to `Pester.<version>.nupkg`) to download via `gh release download` instead of PowerShell Gallery. Keep `PESTER_SHA256` aligned with the asset you host.
  - Set `GH_TOKEN` if you need authenticated GitHub API access (private repo or rate limit avoidance).
  - GitHub CLI comes from a pinned release tarball (default 2.83.1 / SHA256 `1c5252d4ce3db07b51c01ff0b909583da6364ff3fdc06d0c2e75e62dc0380a34`); override with `GH_VERSION`/`GH_SHA256` if you want a different version.
- Host path for nested compose:
  - The containerized runner uses Docker-in-Docker; the inner Seed compose uses `WORKSPACE_HOST_PATH` for the bind mount. The helper script sets it automatically to your repo path on the host. If paths resolve incorrectly (e.g., Windows), set `WORKSPACE_HOST_PATH` to the host path of this repo before running the task.
- Buildx automation: the helper script will use docker compose (buildx/Bake) when available; if `docker buildx` is missing it falls back to `docker build` + `compose run --no-build` so forks without Buildx still work. Install the buildx plugin for faster builds (`docker buildx version`).

## Linux/WSL bash helper
Run the full Seed + Analyze-VIP flow from Bash (Linux/WSL) without inline PowerShell quoting issues:
```
./scripts/run-seed-and-analyze.sh
```
Prereqs: Bash + Docker/Compose available in your shell; PowerShell (`pwsh`) is optional but required to run the Pester metadata tests and Analyze-VIP. If `pwsh` is missing, those steps are skipped with a warning.

## VS Code tasks (optional)
The tasks live in `.vscode/tasks.json`. They are optional; skip if you don’t use Docker or Seed.

### 02 Build LVAddon (VI Package)
- Label: `02 Build LVAddon (VI Package)`
- Scope: root build task for the VI package
- Runs: `scripts/ie.ps1 build-worktree` with the current repo

### Seed: help
- Label: `seed: help`
- Purpose: build the Seed image and show CLI help (`seed --help`)

### Seed: shell
- Label: `seed: shell`
- Purpose: build the Seed image and open a bash shell in the container
- Use when you want to run custom Seed commands manually

### Seed: vipb -> json
- Label: `seed: vipb -> json`
- Purpose: convert a `.vipb` to JSON
- Prompts for input/output paths (use `/workspace/...` inside the container)

### Seed: apply patch
- Label: `seed: apply patch`
- Purpose: apply a JSON patch to a `.vipb`
- Prompts for:
  - Input `.vipb` (use `/workspace/...` inside the container)
  - JSON patch file (e.g., `patch.json`)
  - Output `.vipb` path (where the patched file is written)
- Typical flow:
  1) Export a baseline JSON (`seed: vipb -> json` or `seed vipb json ...`).
  2) Author a small patch JSON with your changes.
  3) Run `seed: apply patch` to produce a patched `.vipb`.
  4) (Optional) Re-export to JSON to confirm the patch.
- Patch format: a JSON merge file that overlays fields (for example):
  ```json
  {
    "Package": {
      "Version": "0.1.0.1509",
      "Display Name": "LabVIEW Icon Editor (patched)"
    }
  }
  ```
  Point the task’s patch path to this file; the tool merges it into the VIPB and writes the patched copy.
- Tips:
  - Keep the patch file in the repo (e.g., `Tooling/seed/patches/my-change.json`) so paths are stable.
  - Merge is additive/overwriting; omitted fields stay unchanged.
  - To drop a field entirely, set it to `null` in the patch JSON.

### Seed + Analyze: deep metadata check (optional)
- Label: `seed + analyze: deep metadata check (containerized)`
- Runs: `docker compose -f ./Tooling/docker/seed-runner/docker-compose.yml run --rm seed-runner`
- Purpose: one-click deep check that:
  - Builds the Seed image
  - Exports VIPB metadata to `artifacts/seed/metadata.json`
  - Runs `Test/SeedMetadata.Tests.ps1` (Pester) and Analyze-VIP (PowerShell), both inside the runner container
  - Finds the newest `.vip` under `builds-isolated` and runs `scripts/analyze-vi-package/run-local.ps1` against it
- Use when you want a detailed metadata report plus VIP content checks without relying on host PowerShell; Docker must be running and the host socket must be available to the container.
