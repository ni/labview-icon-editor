FROM mcr.microsoft.com/dotnet/sdk:8.0

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
        git \
    && python3 -m venv /opt/pylavi-venv \
    && /opt/pylavi-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/pylavi-venv/bin/pip install --no-cache-dir pylavi \
    && ln -s /opt/pylavi-venv/bin/vi_validate /usr/local/bin/vi_validate \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/pylavi-venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /repo
