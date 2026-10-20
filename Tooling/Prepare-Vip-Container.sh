#!/usr/bin/env bash
# Pre-build hook for ni/open-source reusable-build-vip-linux.yml; runs as root in the LabVIEW container.
set -Eeuo pipefail

: "${WORKSPACE:?WORKSPACE must be set}"
: "${LV_NUMERIC_VERSION:?LV_NUMERIC_VERSION must be set}"

ppl_dir="$WORKSPACE/builds/ppl-artifact"
ppl_dest="$WORKSPACE/builds/lv_icon_x64.lvlibp"
deploy_dir="$WORKSPACE/Tooling/deployment"
out_vipb="$deploy_dir/NI Icon editor.linux.shared.vipb"

if [[ ! -d "$ppl_dir" ]]; then
  echo "ERROR: PPL artifact directory not found: $ppl_dir" >&2
  exit 1
fi

mapfile -d '' ppls < <(find "$ppl_dir" -type f -name '*.lvlibp' -print0)
if (( ${#ppls[@]} != 1 )); then
  echo "ERROR: expected exactly one *.lvlibp under $ppl_dir, found ${#ppls[@]}:" >&2
  for p in "${ppls[@]}"; do echo "  $p" >&2; done
  exit 1
fi

echo "Copying PPL: ${ppls[0]} -> $ppl_dest"
cp -f -- "${ppls[0]}" "$ppl_dest"

src_vipb="$deploy_dir/NI Icon editor.vipb"
if [[ -f "$deploy_dir/NI Icon editor.ci.vipb" ]]; then
  src_vipb="$deploy_dir/NI Icon editor.ci.vipb"
fi
if [[ ! -f "$src_vipb" ]]; then
  echo "ERROR: source VIPB not found: $src_vipb" >&2
  exit 1
fi

echo "Source VIPB: $src_vipb"
echo "Output VIPB: $out_vipb"

python3 - "$src_vipb" "$out_vipb" "${LV_NUMERIC_VERSION} (64-bit)" <<'PY'
import sys
import xml.etree.ElementTree as ET

src, dst, lv_version = sys.argv[1:4]
tree = ET.parse(src)
root = tree.getroot()


def require(path):
    node = root.find(path)
    if node is None:
        sys.exit(f"ERROR: required VIPB node missing: {path}")
    return node


def norm(text):
    return (text or "").strip().replace("\\", "/")


require("Library_General_Settings/Package_LabVIEW_Version").text = lv_version
require("Advanced_Settings/Install_Requirements/LV_32-Bit").text = "false"
require("Advanced_Settings/Install_Requirements/LV_64-Bit").text = "true"

source_files = require("Advanced_Settings/Source_Files")
overrides = source_files.findall("Destination_Overrides")

for ov in overrides:
    if norm(ov.findtext("Path")) == "builds/lv_icon_x86.lvlibp":
        source_files.remove(ov)

if not any(norm(ov.findtext("Path")) == "builds/lv_icon_x64.lvlibp"
           for ov in source_files.findall("Destination_Overrides")):
    sys.exit("ERROR: VIPB has no Destination_Overrides entry for builds/lv_icon_x64.lvlibp")

tree.write(dst, encoding="utf-8", xml_declaration=False)
print(f"Wrote {dst} (Package_LabVIEW_Version={lv_version}, LV_64-Bit only)")
PY
