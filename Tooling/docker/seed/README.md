# Seed Docker helper

Use the Seed CLI via a locally built Docker image. The repo is bind-mounted to `/workspace` inside the container, so reference paths accordingly.

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
- Use `/workspace/...` paths inside the container (that’s where the repo mounts).
- The image builds locally; retag via `image:` in `docker-compose.yml` if you want a different name.
- Rebuild after source changes: `docker compose -f Tooling/docker/seed/docker-compose.yml build --no-cache seed`.
