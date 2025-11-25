FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         ca-certificates \
         curl \
         unzip \
         gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         docker-ce-cli \
         docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (optional source for Pester) from release tarball.
ARG GH_VERSION=2.83.1
ARG GH_SHA256=1c5252d4ce3db07b51c01ff0b909583da6364ff3fdc06d0c2e75e62dc0380a34
RUN curl --fail -L "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tgz \
    && echo "${GH_SHA256}  /tmp/gh.tgz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/gh.tgz \
    && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
    && rm -rf /tmp/gh.tgz /tmp/gh_${GH_VERSION}_linux_amd64

ARG CA_CERT_BUNDLE_BASE64=""
RUN if [ -n "$CA_CERT_BUNDLE_BASE64" ]; then \
      echo "$CA_CERT_BUNDLE_BASE64" | base64 -d > /usr/local/share/ca-certificates/custom-ca.crt; \
      update-ca-certificates; \
    fi
ARG ALLOW_INSECURE_PESTER_DOWNLOAD=0
ARG PESTER_GH_REPO=""
ARG PESTER_GH_TAG=""
ARG PESTER_GH_ASSET=""
ARG GH_TOKEN=""

# Install Pester (download from PowerShell Gallery with cert validation + checksum pin).
ARG PESTER_VERSION=5.7.1
ARG PESTER_SHA256=3c6dad5fb143faf19709dfb28c31c873989944705a087e160e23b7ce462e37a1
ARG PESTER_URL="https://globalcdn.nuget.org/packages/pester.${PESTER_VERSION}.nupkg"
RUN curlFlags=""; if [ "$ALLOW_INSECURE_PESTER_DOWNLOAD" = "1" ]; then curlFlags="-k"; fi; \
    PESTER_URL="${PESTER_URL:-https://globalcdn.nuget.org/packages/pester.${PESTER_VERSION}.nupkg}"; \
    if [ -n "$PESTER_GH_REPO" ]; then \
      asset="${PESTER_GH_ASSET:-Pester.${PESTER_VERSION}.nupkg}"; \
      tag="${PESTER_GH_TAG:-$PESTER_VERSION}"; \
      export GH_TOKEN="$GH_TOKEN"; \
      gh release download "$tag" -R "$PESTER_GH_REPO" --pattern "$asset" --dir /tmp --clobber; \
      mv "/tmp/$asset" /tmp/pester.nupkg; \
    else \
      curl $curlFlags --fail -L "${PESTER_URL}" -o /tmp/pester.nupkg; \
    fi \
    && echo "${PESTER_SHA256}  /tmp/pester.nupkg" | sha256sum -c - \
    && mkdir -p "/usr/local/share/powershell/Modules/Pester/${PESTER_VERSION}" \
    && unzip -q /tmp/pester.nupkg -d /tmp/pester_extract \
    && cp -a /tmp/pester_extract/tools/. "/usr/local/share/powershell/Modules/Pester/${PESTER_VERSION}/" \
    && rm -rf /tmp/pester.nupkg /tmp/pester_extract

WORKDIR /workspace
