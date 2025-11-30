#!/usr/bin/env bash
# Sets up the x-cli Codex environment on Linux containers.
# - Verifies/installs .NET 8 SDK (user-scoped) only if missing
# - Installs PowerShell 7.4.11 (pinned) if missing or wrong version
# - Installs Pester & PSReadLine modules (pinned) for PowerShell
# - Warms NuGet cache for any sln/csproj in repo
#
# Assumptions:
# - Debian/Ubuntu-based container with apt available
# - Network access to download required artifacts
# - Running as root (recommended in CI). If not root, 'sudo' must be available.

set -Eeuo pipefail

### -------- Config (override via env if needed) --------
: "${DOTNET_CHANNEL:=8.0}"
: "${DOTNET_ROOT:=$HOME/.dotnet}"

: "${POWERSHELL_VERSION:=7.4.11}"
: "${PSESTER_VERSION:=5.6.0}"
: "${PSREADLINE_VERSION:=2.3.6}"

# GitHub release URL pattern for pwsh .deb (amd64)
POWERSHELL_DEB_URL="https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell_${POWERSHELL_VERSION}-1.deb_amd64.deb"

### -------- Helpers --------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_root_or_sudo() {
  if [[ $EUID -ne 0 ]]; then
    if have_cmd sudo; then
      SUDO="sudo"
    else
      echo "ERROR: This script needs root privileges (or sudo)."
      exit 1
    fi
  else
    SUDO=""
  fi
}

apt_install() {
  # shellcheck disable=SC2086
  $SUDO apt-get update -y
  # shellcheck disable=SC2086
  $SUDO apt-get install -y --no-install-recommends "$@"
}

### -------- Bootstrap OS deps --------
require_root_or_sudo
apt_install ca-certificates curl wget gnupg apt-transport-https

### -------- .NET SDK (user-scoped) --------
if ! have_cmd dotnet; then
  echo "Installing .NET SDK channel ${DOTNET_CHANNEL} to ${DOTNET_ROOT} ..."
  mkdir -p "${DOTNET_ROOT}"
  curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  bash /tmp/dotnet-install.sh --channel "${DOTNET_CHANNEL}" --install-dir "${DOTNET_ROOT}"
else
  echo "dotnet already present: $(dotnet --version)"
fi

# Export env for current shell and append to bashrc for future shells
export DOTNET_ROOT PATH DOTNET_CLI_TELEMETRY_OPTOUT
export DOTNET_CLI_TELEMETRY_OPTOUT=1
case ":$PATH:" in
  *":${DOTNET_ROOT}:"*) : ;;
  *) export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${PATH}" ;;
 esac

{
  echo "export DOTNET_ROOT=\"${DOTNET_ROOT}\""
  echo "export PATH=\"${DOTNET_ROOT}:${DOTNET_ROOT}/tools:$PATH\""
  echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1"
} >> "${HOME}/.bashrc"

### -------- PowerShell (pwsh) --------
need_pwsh=true
if have_cmd pwsh; then
  current_pwsh="$(pwsh --version | awk '{print $1}')"
  if [[ "${current_pwsh}" == "${POWERSHELL_VERSION}" ]]; then
    need_pwsh=false
    echo "pwsh ${current_pwsh} already installed."
  else
    echo "pwsh present (${current_pwsh}) but not ${POWERSHELL_VERSION}; will replace."
  fi
fi

if [[ "${need_pwsh}" == true ]]; then
  echo "Installing PowerShell ${POWERSHELL_VERSION} ..."
  # Try pinned .deb first
  if curl -fsSL --retry 3 -o /tmp/powershell.deb "${POWERSHELL_DEB_URL}"; then
    $SUDO dpkg -i /tmp/powershell.deb || $SUDO apt-get -y -f install
    rm -f /tmp/powershell.deb
  else
    echo "Pinned .deb fetch failed; attempting Microsoft repo install ..."
    # Register Microsoft packages repo for this Ubuntu/Debian
    . /etc/os-release
    curl -fsSL "https://packages.microsoft.com/config/${ID}/${VERSION_ID:-}/packages-microsoft-prod.deb" -o /tmp/packages-microsoft-prod.deb || true
    if [[ -s /tmp/packages-microsoft-prod.deb ]]; then
      $SUDO dpkg -i /tmp/packages-microsoft-prod.deb
      rm -f /tmp/packages-microsoft-prod.deb
      $SUDO apt-get update -y
      $SUDO apt-get install -y powershell
    else
      echo "ERROR: Could not configure Microsoft package repo. Aborting pwsh install."
      exit 1
    fi
  fi

  installed_pwsh="$(pwsh --version | awk '{print $1}')"
  if [[ "${installed_pwsh}" != "${POWERSHELL_VERSION}" ]]; then
    echo "WARNING: Installed pwsh version is ${installed_pwsh}, expected ${POWERSHELL_VERSION}."
  else
    echo "pwsh ${installed_pwsh} installed."
  fi
fi

### -------- PowerShell modules (Pester, PSReadLine) --------
echo "Installing PowerShell modules (Pester ${PSESTER_VERSION}, PSReadLine ${PSREADLINE_VERSION}) ..."
pwsh -NoLogo -NoProfile -NonInteractive -Command '
  $ErrorActionPreference = "Stop";
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted;
  $mods = @(
    @{ Name="Pester";     Ver=$env:PSESTER_VERSION },
    @{ Name="PSReadLine"; Ver=$env:PSREADLINE_VERSION }
  );
  foreach ($m in $mods) {
    $installed = Get-Module -ListAvailable $m.Name | Sort-Object Version | Select-Object -Last 1
    if (-not $installed -or $installed.Version.ToString() -ne $m.Ver) {
      Install-Module -Name $m.Name -RequiredVersion $m.Ver -Scope AllUsers -Force -SkipPublisherCheck
    }
  }
  Write-Host "Pester:"; (Get-Module -ListAvailable Pester | Sort-Object Version | Select-Object -Last 1).Version
  Write-Host "PSReadLine:"; (Get-Module -ListAvailable PSReadLine | Sort-Object Version | Select-Object -Last 1).Version
'

### -------- Warm caches (NuGet) --------
if git ls-files '*.sln' >/dev/null 2>&1; then
  while IFS= read -r sln; do
    echo "Restoring ${sln} ..."
    dotnet restore "${sln}" || true
  done < <(git ls-files '*.sln')
elif git ls-files '*.csproj' >/dev/null 2>&1; then
  while IFS= read -r proj; do
    echo "Restoring ${proj} ..."
    dotnet restore "${proj}" || true
  done < <(git ls-files '*.csproj')
else
  echo "No .sln or .csproj detected; skipping NuGet restore."
fi

### -------- Summary --------
echo "Setup complete."
echo "dotnet: $(dotnet --version || true)"
echo "pwsh:   $(pwsh --version || true)"

