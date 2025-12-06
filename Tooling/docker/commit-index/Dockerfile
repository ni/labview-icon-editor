# Lightweight image to run commit-index generation reproducibly
ARG BASE_IMAGE=mcr.microsoft.com/powershell:7.4-ubuntu-22.04@sha256:62300a213a9293916333df2b014cd3a8f22fb0b0b65f2bb446aaf436bcf8c868
FROM ${BASE_IMAGE}

ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Git is required to query history for each path
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/* /var/log/apt/*

# Harden: non-root user with write access to workspace and tooling
RUN groupadd --system app \
    && useradd --system --create-home --gid app app \
    && mkdir -p /workspace /tooling \
    && chown -R app:app /workspace /tooling \
    && git config --system --add safe.directory /workspace

# Place tooling under /tooling; expect repo bind-mounted at /workspace
WORKDIR /workspace
COPY --chown=app:app scripts/build-source-distribution/New-CommitIndex.ps1 /tooling/New-CommitIndex.ps1

USER app

ENTRYPOINT ["pwsh", "/tooling/New-CommitIndex.ps1"]
