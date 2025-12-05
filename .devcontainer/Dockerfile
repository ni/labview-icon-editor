FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set environment to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Prevent services from starting during package installation
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d

# Install PowerShell, Docker CLI, and utilities
# Note: apt-get install will trigger dbus which cannot connect to system bus in containers.
# This is expected and harmless. We use semicolons after install to continue despite the trigger error,
# then verify the packages were installed successfully.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        apt-transport-https \
        software-properties-common \
        git \
        curl \
        unzip \
        ca-certificates \
        less \
        docker.io; \
    dpkg -l | grep -q wget; \
    dpkg -l | grep -q docker.io; \
    wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends powershell; \
    pwsh --version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -f /usr/sbin/policy-rc.d

WORKDIR /workspaces/labview-icon-editor-sandbox
