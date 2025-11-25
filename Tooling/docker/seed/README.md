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
# example: seed vipb json --input /workspace/Tooling/deployment/labview-icon-editor.vipb --output /workspace/out.json
```

Open a shell:
```
docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed bash
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

## VS Code tasks (optional)
The tasks live in `.vscode/tasks.json`. They are optional; skip if you don’t use Docker or Seed.

### Build LVAddon (VI Package)
- Label: `Build LVAddon (VI Package)`
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
  1) Export a baseline JSON: run `seed: vipb -> json` or `seed vipb json ...`
  2) Edit the JSON or create a patch file with your changes
  3) Run `seed: apply patch` to produce a patched `.vipb`
  4) Optionally re-export to JSON to verify the patch applied as expected
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
