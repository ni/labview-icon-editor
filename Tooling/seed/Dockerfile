# Multi-stage Docker build: first build the .NET conversion tool, then assemble the final image
FROM mcr.microsoft.com/dotnet/sdk:8.0@sha256:ed79c2e51544a203afb020bd7aeef5ac12cf7643ba17192eb6d4442e9c463bff AS build
WORKDIR /src

# Copy and restore dependencies for VipbJsonTool
COPY Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj Tooling/dotnet/VipbJsonTool/
RUN dotnet restore Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj

# Copy source code and build/publish a self-contained Linux binary
COPY Tooling/dotnet/VipbJsonTool/ Tooling/dotnet/VipbJsonTool/
RUN dotnet publish Tooling/dotnet/VipbJsonTool -c Release -r linux-x64 --self-contained \
    -p:PublishSingleFile=true -o /app/publish

# Use a minimal Ubuntu base for the final image
FROM ubuntu:22.04@sha256:1c4cc37c10c4678fd5369d172a4e079af8a28a6e6f724647ccaa311b4801c3c9

# Install core dependencies and required tools (include yq from upstream release)
RUN apt-get update && \
  apt-get install -y git curl unzip patch wget libicu70 ca-certificates && \
  wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb && \
  dpkg -i /tmp/packages-microsoft-prod.deb && \
  apt-get update && \
  apt-get install -y powershell && \
  wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64 && \
  chmod +x /usr/local/bin/yq && \
  rm -f /tmp/packages-microsoft-prod.deb && \
  rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh) for auto PR functionality
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Set working directory to GitHub Actions workspace
WORKDIR /github/workspace

# Copy entrypoint script and GitHub Action metadata
COPY Tooling/seed/scripts/entrypoint.sh /entrypoint.sh
COPY Tooling/seed/action.yml /action.yml
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

# Copy golden sample template files for seeding (included in the image for reference)
COPY Tooling/seed/tests/Samples/seed.lvproj /github/workspace/tests/Samples/

# Copy the published VipbJsonTool binary from the build stage
COPY --from=build /app/publish/VipbJsonTool /usr/local/bin/VipbJsonTool

# SD manifest helpers (PowerShell entrypoint uses these)
COPY scripts/source-distribution/Generate-SD-Manifest.ps1 /usr/local/bin/Generate-SD-Manifest.ps1
COPY scripts/source-distribution/Prepare-SDBundle.ps1 /usr/local/bin/Prepare-SDBundle.ps1

# Generate CLI wrapper scripts inside the image (flag-parsing shells).
COPY Tooling/seed/scripts/gen-wrappers.sh /usr/local/bin/gen-wrappers.sh
RUN sed -i 's/\r$//' /usr/local/bin/gen-wrappers.sh \
  && chmod +x /usr/local/bin/gen-wrappers.sh \
  && /bin/bash /usr/local/bin/gen-wrappers.sh

# Set the default entrypoint to the action's script (prints help if no inputs provided)
ENTRYPOINT ["/entrypoint.sh"]
