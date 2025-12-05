# Minimal image for consuming the SD handshake (lock/run-key) via OrchestrationCli inside Docker Desktop.
FROM mcr.microsoft.com/dotnet/sdk:8.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates apt-transport-https gnupg \
    && wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Publish the Linux OrchestrationCli binary into /app before building.
COPY OrchestrationCli/ /app/
