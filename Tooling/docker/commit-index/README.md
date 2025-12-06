# Commit Index Docker Image

A minimal, host-neutral container for generating the commit index via `scripts/build-source-distribution/New-CommitIndex.ps1`.

## Build

```bash
docker build \
  --pull=always \
  --build-arg BASE_IMAGE=mcr.microsoft.com/powershell:7.4-ubuntu-22.04@sha256:62300a213a9293916333df2b014cd3a8f22fb0b0b65f2bb446aaf436bcf8c868 \
  -t ghcr.io/svelderrainruiz/labview-icon-editor-commit-index:commit-index \
  Tooling/docker/commit-index
```

## Run (local or CI)

Assuming the repo is bind-mounted at `/workspace`:

```bash
docker run --rm \
  -v "${PWD}:/workspace" \
  -w /workspace \
  ghcr.io/svelderrainruiz/labview-icon-editor-commit-index:commit-index \
  -RepositoryPath /workspace \
  -OutputPath /workspace/builds/cache/commit-index.json \
  -CsvOutputPath /workspace/builds/cache/commit-index.csv \
  -AllowDirty
```

Notes:

- Runs as a non-root `app` user; `/workspace` is writable and marked as a git safe.directory so history lookups work on bind mounts.
- The container needs access to `.git` to compute history; ensure it is included in the mount.
- Adjust `-IncludePaths`/`-InputPaths`/`-UseLvproj` flags as needed; all script parameters are supported and passed directly to `New-CommitIndex.ps1`.
- For extra isolation, you may add `--network none` when you do not need to fetch from remotes.
- Keep image lean: only pwsh + git are installed.

## CI pipeline (build, scan, sign)

- Workflow: `.github/workflows/commit-index-image.yml` builds on pushes to commit-index files and on demand.
- Images are tagged `commit-index`, `commit-index-<channel>`, and `commit-index-sha-<gitsha>` under `ghcr.io/<owner>/<repo>-commit-index` by default (override via workflow inputs).
- Base image is pinned to the digest shown above for reproducibility.
- SBOM: generated with Syft (SPDX) and uploaded as an artifact.
- Vulnerability scans: Trivy (CRITICAL/HIGH, ignore-unfixed) and Grype (severity-cutoff high) run against the pushed digest.
- Signing: cosign keyless against GitHub OIDC; verification runs in a follow-up job.

To verify the published image locally (replace owner/repo as needed):

```bash
IMAGE=ghcr.io/svelderrainruiz/labview-icon-editor-commit-index:commit-index
DIGEST=$(docker buildx imagetools inspect "$IMAGE" | awk '/Digest/ {print $2; exit}')
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp="^https://github.com/svelderrainruiz/labview-icon-editor-fork@.*$" \
  "${IMAGE%@*}@${DIGEST}"
```
