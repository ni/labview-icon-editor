FROM mcr.microsoft.com/dotnet/sdk:8.0

ARG PYLAVI_URL="https://files.pythonhosted.org/packages/source/p/pylavi/pylavi-0.3.2.tar.gz"
ARG PYLAVI_SHA256="49165a197f7a1dd234294e12156bbb0db143da5b60b5ae4c2dd4b25ade6f40b4"

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl git python3 python3-venv python3-pip; \
    curl -fsSL "${PYLAVI_URL}" -o /tmp/pylavi.tar.gz; \
    echo "${PYLAVI_SHA256}  /tmp/pylavi.tar.gz" | sha256sum -c -; \
    python3 -m venv /opt/pylavi-venv; \
    /opt/pylavi-venv/bin/python -m pip install --no-cache-dir --upgrade pip; \
    /opt/pylavi-venv/bin/python -m pip install --no-cache-dir /tmp/pylavi.tar.gz; \
    ln -sf /opt/pylavi-venv/bin/vi_validate /usr/local/bin/vi_validate; \
    command -v vi_validate >/dev/null 2>&1; \
    rm -f /tmp/pylavi.tar.gz; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /repo
