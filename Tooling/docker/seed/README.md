# Seed Docker helper

Run the Seed CLI from a locally built image so each fork can own its own tag without relying on GHCR.

- Build context: vendored source under `Tooling/seed` (Dockerfile in that folder).
- Local image tag: `seed-local:latest`.
- Mounts the repo at `/workspace` by default.

## Usage
1) Ensure Docker is installed. The compose file will build the local image on first run.
2) Show Seed help from the container (builds if needed):
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed
   ```
   (By default the service runs `seed --help`.)
3) Run a specific Seed command (builds if needed):
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed seed <args>
   ```
4) Drop into a shell inside the container:
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed bash
   ```

The repo is mounted at `/workspace`; adjust paths accordingly when running commands in the container.
