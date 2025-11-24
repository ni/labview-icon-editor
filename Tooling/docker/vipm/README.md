# VIPM Docker helper (Linux)

Lightweight helper to run VIPM CLI inside NI's LabVIEW container. Useful for installing packages or exercising VIPM automation without putting VIPM on the host. This image targets LabVIEW 2025 on Linux, so keep Windows/LabVIEW 2021 builds as the source of truth.

## Setup
1) Copy `.env.example` to `.env` and fill in VIPM Pro credentials (keep `.env` local/untracked). The VS Code task below will create an empty `.env` if it’s missing (good enough for `vipm help`; fill it for activation/installs).
2) From the repo root, launch a shell in the container (builds image on first run):
   ```
   docker compose -f Tooling/docker/vipm/docker-compose.yml run --rm vipm-labview
   ```
   The repo is mounted at `/workspace`.

## Common commands to run inside the container
- Activate VIPM: `vipm vipm-activate --serial-number "$VIPM_SERIAL_NUMBER" --name "$VIPM_FULL_NAME" --email "$VIPM_EMAIL"`
- Refresh packages: `vipm package-list-refresh`
- Install our VIPC: `vipm install /workspace/icon-editor-developer.vipc` (adjust path as needed)
- Inspect installs: `vipm list --installed`
- (Experimental) Build from VIPB on Linux: `vipm build /workspace/path/to/your.vipb`

## VS Code task
- Run task “Test VIPM Docker” (calls `Tooling/docker/vipm/test-vipm.ps1`) to build the image if needed and execute `vipm help` inside the container. It will auto-create an empty `.env` if missing; supply credentials in `.env` for activation/installs. The script now builds before running to avoid pull errors.
- Run task “VIPM Docker Smoke” (calls `Tooling/docker/vipm/smoke-vipm.ps1`) to activate VIPM, refresh package metadata, install `oglib_boolean`, list installs, and sanity-check OpenG files. Requires valid `.env` credentials. Optional `-VipcPath` lets you also apply a VIPC inside the container.

## TLS note
- The Dockerfile tries a normal download of VIPM and, if the certificate chain can’t be validated (e.g., corporate TLS interception), retries with `--no-check-certificate`. If you have a corporate root CA, prefer adding it to the base image instead of relying on the insecure fallback.

## Caveats
- Base image: `nationalinstruments/labview:2025q3patch1-linux`; expect differences from our Windows/LabVIEW 2021 pipeline.
- VIPM build on Linux is not fully supported; treat this container as a convenience/verification tool, not the release path.
- `.env` holds secrets; it is ignored via `.dockerignore` and should stay out of git.
