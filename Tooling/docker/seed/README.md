# Seed Docker helper

Run the Seed CLI straight from the published container image so you don't have to install it locally.

- Image: `ghcr.io/labview-community-ci-cd/seed:latest`
- Mounts the repo at `/workspace` by default.

## Usage
1) Ensure Docker is installed and (if required) you are logged in to GHCR:
   ```
   docker login ghcr.io
   ```
2) Show Seed help from the container:
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed
   ```
   (By default the service runs `seed --help`.)
3) Run a specific Seed command:
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed seed <args>
   ```
4) Drop into a shell inside the container:
   ```
   docker compose -f Tooling/docker/seed/docker-compose.yml run --rm seed bash
   ```

The repo is mounted at `/workspace`; adjust paths accordingly when running commands in the container.
