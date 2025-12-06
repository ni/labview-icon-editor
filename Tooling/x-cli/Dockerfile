# Multi-stage Dockerfile supporting two flows:
#  - package-image: build from a pre-packed .nupkg placed under package/
#  - source-image:  build from source using dotnet publish (local/dev convenience)

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY XCli.sln ./
COPY src/XCli/XCli.csproj src/XCli/
COPY src/SrsApi/SrsApi.csproj src/SrsApi/
RUN dotnet restore src/XCli/XCli.csproj
COPY . .
RUN dotnet publish src/XCli/XCli.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/runtime:8.0@sha256:55277015b7d570ac6cc9aa2ba78fe16eb9f6b214f251d1d49857faea26ce18a2 AS base
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates unzip && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /github/workspace
COPY scripts/action-entrypoint.sh /entrypoint.sh
COPY action.yml /action.yml
RUN chmod +x /entrypoint.sh

# Package-first image (default)
FROM base AS package-image
ARG XCLI_VERSION=0.0.0
LABEL org.opencontainers.image.version=$XCLI_VERSION
WORKDIR /tmp
COPY package/XCli*.nupkg /tmp/XCli.nupkg
RUN mkdir /app \
    && unzip /tmp/XCli.nupkg -d /tmp/cli \
    && cp /tmp/cli/lib/net8.0/* /app/ \
    && rm -rf /tmp/cli /tmp/XCli.nupkg \
    && printf '#!/usr/bin/env bash\nexec dotnet /app/XCli.dll "$@"\n' > /usr/local/bin/x-cli \
    && chmod +x /usr/local/bin/x-cli
ENTRYPOINT ["/entrypoint.sh"]

# Source-based image (for local developer convenience)
FROM base AS source-image
COPY --from=build /app /app
RUN printf '#!/usr/bin/env bash\nexec dotnet /app/XCli.dll "$@"\n' > /usr/local/bin/x-cli && chmod +x /usr/local/bin/x-cli
ENTRYPOINT ["/entrypoint.sh"]
