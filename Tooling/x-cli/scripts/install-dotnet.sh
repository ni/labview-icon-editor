#!/usr/bin/env bash
set -euo pipefail

if command -v dotnet >/dev/null 2>&1; then
  echo ".NET SDK already installed"
  exit 0
fi

unameOut="$(uname -s)"
case "$unameOut" in
  Linux*)
    wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    apt-get update
    apt-get install -y dotnet-sdk-8.0
    ;;
  Darwin*)
    if command -v brew >/dev/null 2>&1; then
      brew update
      brew install --cask dotnet-sdk
    else
      curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
      chmod +x dotnet-install.sh
      ./dotnet-install.sh --version latest
      rm dotnet-install.sh
    fi
    ;;
  *)
    echo "Unsupported platform: $unameOut. Supported platforms are Linux and macOS." >&2
    exit 1
    ;;
esac
