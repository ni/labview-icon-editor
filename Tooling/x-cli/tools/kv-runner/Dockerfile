# tools/kv-runner/Dockerfile
FROM python:3.12-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Minimal runtime for the validator:
# - gawk: used to extract the JSON block from validator.log
# - ca-certificates: TLS roots for any HTTPS reads (safe default)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    gawk ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python deps used by the validator/tests
RUN python -m pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir ruamel.yaml

# No entrypoint; Actions will run commands directly
WORKDIR /workspace
