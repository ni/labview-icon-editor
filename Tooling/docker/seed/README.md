# Seed Docker helper

Run the Seed CLI from a locally built image (no GHCR dependency). The repo is bind-mounted to `/workspace` inside the container.

- Build context: `Tooling/seed` (vendored source + Dockerfile)
- Tag produced: `seed-local:latest`
- Compose file: `Tooling/docker/seed/docker-compose.yml`

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

## Notes
- Paths inside the container should use `/workspace/...` since the repo root is mounted there.
- The image builds locally; each fork can retag as desired by changing `image:` in `docker-compose.yml`.
- To rebuild after source changes: `docker compose -f Tooling/docker/seed/docker-compose.yml build --no-cache seed`.
