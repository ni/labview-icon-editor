# Minimal image for testing local-sd lock/run-key coordination (no LabVIEW).
# Relies on mounting the repo into /workspace and using ORCH_SKIP_LOCAL_SD_BUILD=1.

FROM mcr.microsoft.com/dotnet/sdk:8.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates apt-transport-https gnupg \
    && wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy published OrchestrationCli binaries (host publishes into build context before docker build)
COPY OrchestrationCli/ /app/

ENTRYPOINT ["/app/OrchestrationCli"]
