#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE=/workspace
LOG_DIR="$WORKSPACE/builds/logs/linux-vip"
VIPM_DEB_URL="https://traffic.libsyn.com/secure/jkinc/vipm_26.3.1-4025_amd64.deb"
VIPM_DESKTOP_LIVELINESS_TIMEOUT="${VIPM_DESKTOP_LIVELINESS_TIMEOUT:-300}"
XVFB_PID=""

mkdir -p "$LOG_DIR" "$WORKSPACE/builds/VI Package"

redact_secrets() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    perl -0777 -i -pe '
        for my $key (qw(VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL)) {
            my $value = $ENV{$key};
            next unless defined($value) && length($value);
            s/\Q$value\E/[REDACTED]/g;
        }
    ' "$file"
}

collect_diagnostics() {
    local status="${1:-unknown}"
    local base
    local index=0
    {
        printf 'timestamp: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'exit status: %s\n' "$status"
        printf 'display: %s\n' "${DISPLAY:-unset}"
        printf 'LabVIEW version: %s\n' "${LABVIEW_VERSION:-unset}"
        printf '\n-- OS --\n'
        cat /etc/os-release 2>/dev/null || true
        printf '\n-- memory --\n'
        free -h 2>/dev/null || true
        printf '\n-- disk --\n'
        df -h "$WORKSPACE" /tmp 2>/dev/null || true
        printf '\n-- VIPM/LabVIEW processes --\n'
        ps -eo pid,ppid,stat,etime,comm 2>/dev/null | grep -iE 'vipm|labview|xvfb' || true
        printf '\n-- Xvfb log --\n'
        tail -n 100 "$LOG_DIR/xvfb.log" 2>/dev/null || true
    } > "$LOG_DIR/diagnostics.log"

    mkdir -p "$LOG_DIR/vipm-desktop-logs"
    for base in "$HOME/.config/JKI/VIPM" "$HOME/.local/share/JKI/VIPM" "$HOME/.cache/JKI/VIPM" /var/log/JKI/VIPM; do
        [[ -d "$base" ]] || continue
        while IFS= read -r -d '' file; do
            index=$((index + 1))
            cp "$file" "$LOG_DIR/vipm-desktop-logs/vipm-${index}.log" 2>/dev/null || true
        done < <(find "$base" -type f -iname '*.log' -print0 2>/dev/null)
    done
}

on_exit() {
    local status=$?
    if (( status != 0 )); then
        printf 'Container VIP build failed with status %s; collecting diagnostics.\n' "$status" >&2
        collect_diagnostics "$status" || true
    fi
    while IFS= read -r -d '' file; do
        redact_secrets "$file" || true
    done < <(find "$LOG_DIR" -type f -print0 2>/dev/null)
    if [[ -n "$XVFB_PID" ]]; then
        kill "$XVFB_PID" 2>/dev/null || true
    fi
    return "$status"
}
trap on_exit EXIT

run_logged() {
    local name="$1"
    local timeout_seconds="$2"
    local log_file="$LOG_DIR/${name}.log"
    local status
    shift 2
    printf '\n[%s] Running %s (timeout %ss)\n' "$(date --iso-8601=seconds 2>/dev/null || date)" "$name" "$timeout_seconds"
    set +e
    timeout --signal=TERM --kill-after=30s "${timeout_seconds}s" "$@" 2>&1 | tee "$log_file"
    status=${PIPESTATUS[0]}
    set -e
    redact_secrets "$log_file"
    if (( status != 0 )); then
        printf '[%s] failed with exit status %s\n' "$name" "$status" >&2
        return "$status"
    fi
}

if [[ "$(id -u)" -ne 0 ]]; then
    echo 'The NI container helper must run as root to install VIPM.' >&2
    exit 1
fi
for name in LABVIEW_VERSION VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL; do
    if [[ -z "${!name:-}" ]]; then
        echo "Required environment variable $name is missing." >&2
        exit 1
    fi
done
if [[ ! "$LABVIEW_VERSION" =~ ^([0-9]{4})q([13])$ ]]; then
    echo "Unsupported LabVIEW version '$LABVIEW_VERSION'; expected YYYYq1 or YYYYq3." >&2
    exit 1
fi
LV_YEAR="${BASH_REMATCH[1]}"
LV_QUARTER="${BASH_REMATCH[2]}"
LV_NUMERIC_VERSION="$((LV_YEAR - 2000)).${LV_QUARTER}"
export LV_YEAR LV_QUARTER LV_NUMERIC_VERSION
export DISPLAY=:99
export VIPM_NONINTERACTIVE=1
export VIPM_DEBUG=1
export VIPM_TIMEOUT=900
export VIPM_DESKTOP_LIVELINESS_TIMEOUT
export VIPM_LABVIEW_LAUNCH_TIMEOUT=300

run_logged apt-update 600 apt-get update
run_logged apt-install 900 apt-get install -y --no-install-recommends ca-certificates curl perl procps python3 x11-utils xvfb

mkdir -p /tmp/natinst
printf '1\n' > /tmp/natinst/LVContainer.txt
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset > "$LOG_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
for attempt in $(seq 1 30); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then break; fi
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        cat "$LOG_DIR/xvfb.log" >&2 || true
        echo 'Xvfb exited before the headless display became ready.' >&2
        exit 1
    fi
    sleep 1
done
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo 'Xvfb did not become ready within 30 seconds.' >&2
    exit 1
fi

run_logged vipm-download 900 curl --fail --location --retry 3 --retry-all-errors --output /tmp/vipm.deb "$VIPM_DEB_URL"
if ! run_logged vipm-dpkg-install 900 dpkg -i /tmp/vipm.deb; then
    run_logged apt-repair 900 apt-get -f install -y
    run_logged vipm-dpkg-install-retry 900 dpkg -i /tmp/vipm.deb
fi
if ! command -v vipm >/dev/null 2>&1; then
    echo 'VIPM CLI was not found on PATH after installing its Debian package.' >&2
    exit 1
fi
dpkg-query -W -f='${Package} ${Version}\n' vipm | tee "$LOG_DIR/vipm-version.log"

# Activate Pro before VIPM package build commands.
activation_log="$LOG_DIR/vipm-activation.log"
if timeout --signal=TERM --kill-after=30s 600s vipm activate --serial-number "$VIPM_SERIAL_NUMBER" --name "$VIPM_FULL_NAME" --email "$VIPM_EMAIL" > "$activation_log" 2>&1; then
    activation_status=0
else
    activation_status=$?
fi
redact_secrets "$activation_log"
cat "$activation_log"
if (( activation_status != 0 )); then
    printf 'VIPM Pro activation failed with exit status %s.\n' "$activation_status" >&2
    exit "$activation_status"
fi

# Dependency installation is temporarily bypassed to isolate VIPB packaging.

vipb_source="$WORKSPACE/Tooling/deployment/NI Icon editor.vipb"
ci_vipb="$WORKSPACE/Tooling/deployment/NI Icon editor.ci.vipb"
if [[ -f "$ci_vipb" ]]; then vipb_source="$ci_vipb"; fi
vipb_output="$WORKSPACE/Tooling/deployment/NI Icon editor.linux.ci.vipb"
# Prepare a temporary Linux VIPB so the tracked Windows package definition stays unchanged.
vipb_log="$LOG_DIR/vipb-preparation.log"
if ! python3 - "$vipb_source" "$vipb_output" "$WORKSPACE" "$LV_NUMERIC_VERSION" > "$vipb_log" 2>&1 <<'PY'
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source, output, workspace, labview_version = sys.argv[1:]
source = Path(source)
output = Path(output)
if not source.is_file():
    raise FileNotFoundError(f"VIPB source file not found: {source}")

tree = ET.parse(source)
root = tree.getroot()

def require_node(parent, path):
    node = parent.find(path)
    if node is None:
        raise ValueError(f"Required VIPB XML node is missing: {path}")
    return node

general = require_node(root, "Library_General_Settings")
require_node(general, "Library_Source_Folder").text = workspace
require_node(general, "Library_Output_Folder").text = os.path.join(workspace, "builds", "VI Package")
package_version = require_node(general, "Library_Version").text
if not package_version:
    raise ValueError("VIPB Library_Version is empty")
require_node(general, "Package_LabVIEW_Version").text = f"{labview_version} (64-bit)"
install_requirements = require_node(root, "Advanced_Settings/Install_Requirements")
require_node(install_requirements, "LV_32-Bit").text = "false"
require_node(install_requirements, "LV_64-Bit").text = "true"

source_files = root.find("Advanced_Settings/Source_Files")
if source_files is None:
    raise ValueError("VIPB XML node is missing: Source_Files")
selected_ppl = "builds/lv_icon_x64.lvlibp"
has_selected_ppl = False
for override in list(source_files.findall("Destination_Overrides")):
    path_node = override.find("Path")
    if path_node is None or not path_node.text:
        continue
    path = path_node.text.replace("\\", "/")
    if path == selected_ppl:
        has_selected_ppl = True
    elif path == "builds/lv_icon_x86.lvlibp":
        source_files.remove(override)
if not has_selected_ppl:
    raise ValueError(f"VIPB does not include required PPL source: {selected_ppl}")

vipc = root.find("Advanced_Settings/VI_Package_Configuration_File")
if vipc is not None and vipc.text and not (source.parent / vipc.text).is_file():
    vipc.text = ""

output.parent.mkdir(parents=True, exist_ok=True)
ET.indent(tree, space="  ")
tree.write(output, encoding="utf-8", xml_declaration=True)
print(f"Prepared temporary VIPB: {output}")
print(f"Package version from VIPB: {package_version}")
print(f"LabVIEW target: {labview_version} (64-bit)")
PY
then
    cat "$vipb_log" >&2
    exit 1
fi
cat "$vipb_log"

run_logged vipm-build 1800 vipm build "$vipb_output" --labview-version "$LV_YEAR" --labview-bitness 64 --timeout 900 --verbose
shopt -s nullglob
vip_files=("$WORKSPACE/builds/VI Package/"*.vip)
if (( ${#vip_files[@]} == 0 )); then
    echo 'VIPM reported success but produced no .vip under builds/VI Package.' >&2
    exit 1
fi
printf 'Built VIP package(s):\n'
printf '  %s\n' "${vip_files[@]}"