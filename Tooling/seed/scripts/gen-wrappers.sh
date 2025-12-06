#!/bin/bash
set -euo pipefail
for cmd in vipb2json json2vipb lvproj2json json2lvproj buildspec2json json2buildspec; do
cat <<EOF > "/usr/local/bin/${cmd}"
#!/bin/bash
set -euo pipefail
input=""
output=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -i|--input) input="\$2"; shift 2;;
    -o|--output) output="\$2"; shift 2;;
    --) shift; break;;
    *) echo "ERROR: Unknown arg \$1" >&2; exit 1;;
  esac
done
if [[ -z "\$input" || -z "\$output" ]]; then
  echo "Usage: ${cmd} --input <in> --output <out>" >&2
  exit 1
fi
exec /usr/local/bin/VipbJsonTool "${cmd}" "\$input" "\$output"
EOF
chmod +x "/usr/local/bin/${cmd}"
done
chmod +x /entrypoint.sh /usr/local/bin/VipbJsonTool
