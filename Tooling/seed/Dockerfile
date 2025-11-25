# Multi-stage Docker build: first build the .NET conversion tool, then assemble the final image
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy and restore dependencies for VipbJsonTool
COPY src/VipbJsonTool/VipbJsonTool.csproj src/VipbJsonTool/
RUN dotnet restore src/VipbJsonTool/VipbJsonTool.csproj

# Copy source code and build/publish a self-contained Linux binary
COPY src/VipbJsonTool/ src/VipbJsonTool/
RUN dotnet publish src/VipbJsonTool -c Release -r linux-x64 --self-contained \
    -p:PublishSingleFile=true -o /app/publish

# Use a minimal Ubuntu base for the final image
FROM ubuntu:22.04

# Install core dependencies and required tools
RUN apt-get update && \
    apt-get install -y git curl unzip patch yq && \
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
COPY entrypoint.sh /entrypoint.sh
COPY action.yml /action.yml

# Copy golden sample template files for seeding (included in the image for reference)
COPY tests/Samples/seed.lvproj tests/Samples/seed.vipb /github/workspace/tests/Samples/

# Copy all CLI wrapper scripts from the repository into the image
COPY bin/vipb2json      /usr/local/bin/vipb2json
COPY bin/json2vipb      /usr/local/bin/json2vipb
COPY bin/lvproj2json    /usr/local/bin/lvproj2json
COPY bin/json2lvproj    /usr/local/bin/json2lvproj
COPY bin/buildspec2json /usr/local/bin/buildspec2json
COPY bin/json2buildspec /usr/local/bin/json2buildspec

# Copy the published VipbJsonTool binary from the build stage
COPY --from=build /app/publish/VipbJsonTool /usr/local/bin/VipbJsonTool

# Ensure all copied scripts and binaries have execution permissions
RUN chmod +x /entrypoint.sh \
            /usr/local/bin/vipb2json \
            /usr/local/bin/json2vipb \
            /usr/local/bin/lvproj2json \
            /usr/local/bin/json2lvproj \
            /usr/local/bin/buildspec2json \
            /usr/local/bin/json2buildspec \
            /usr/local/bin/VipbJsonTool

# Set the default entrypoint to the action's script (prints help if no inputs provided)
ENTRYPOINT ["/entrypoint.sh"]
