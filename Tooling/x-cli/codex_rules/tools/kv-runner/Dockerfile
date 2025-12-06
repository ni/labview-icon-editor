FROM python:3.12-slim

# Optional: PDF probe support (pdftotext)
RUN apt-get update && apt-get install -y --no-install-recommends \
    poppler-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Non-root user & working dir
RUN useradd -m -u 1001 -s /usr/sbin/nologin kv && mkdir -p /work && chown -R kv:kv /work
USER kv
WORKDIR /work

# Preinstall Python deps the validator needs
RUN python -m pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ruamel.yaml

# No entrypoint; GH Actions will run commands. Workspace mounts at /__w/...
