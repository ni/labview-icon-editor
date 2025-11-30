# Multi-stage Docker build: first build the .NET conversion tool, then assemble the final image
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy and restore dependencies for VipbJsonTool
COPY Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj Tooling/dotnet/VipbJsonTool/
RUN dotnet restore Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj

# Copy source code and build/publish a self-contained Linux binary
COPY Tooling/dotnet/VipbJsonTool/ Tooling/dotnet/VipbJsonTool/
RUN dotnet publish Tooling/dotnet/VipbJsonTool -c Release -r linux-x64 --self-contained \
    -p:PublishSingleFile=true -o /app/publish

# Use a minimal Ubuntu base for the final image
FROM ubuntu:22.04

# Install core dependencies and required tools (include yq from upstream release)
RUN apt-get update && \
    apt-get install -y git curl unzip patch wget libicu70 && \
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.2/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq && \
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

# Copy golden sample template files for seeding (included in the image for reference)
COPY Tooling/seed/tests/Samples/seed.lvproj /github/workspace/tests/Samples/

# Copy the published VipbJsonTool binary from the build stage
COPY --from=build /app/publish/VipbJsonTool /usr/local/bin/VipbJsonTool

# Generate CLI wrapper scripts inside the image (flag-parsing shells).
RUN /bin/bash -c 'set -e; \
  for cmd in vipb2json json2vipb lvproj2json json2lvproj buildspec2json json2buildspec; do \
    printf "%s\n" \
      "#!/bin/bash" \
      "set -euo pipefail" \
      "input=\"\"" \
      "output=\"\"" \
      "while [[ \$# -gt 0 ]]; do" \
      "  case \"\$1\" in" \
      "    -i|--input) input=\"\$2\"; shift 2;;" \
      "    -o|--output) output=\"\$2\"; shift 2;;" \
      "    --) shift; break;;" \
      "    *) echo \"ERROR: Unknown arg \$1\" >&2; exit 1;;" \
      "  esac" \
      "done" \
      "if [[ -z \"\$input\" || -z \"\$output\" ]]; then" \
      "  echo \"Usage: ${cmd} --input <in> --output <out>\" >&2" \
      "  exit 1" \
      "fi" \
      "exec /usr/local/bin/VipbJsonTool \"${cmd}\" \"\$input\" \"\$output\"" \
      > "/usr/local/bin/${cmd}"; \
    chmod +x "/usr/local/bin/${cmd}"; \
  done; \
  chmod +x /entrypoint.sh /usr/local/bin/VipbJsonTool'

# Set the default entrypoint to the action's script (prints help if no inputs provided)
ENTRYPOINT ["/entrypoint.sh"]
