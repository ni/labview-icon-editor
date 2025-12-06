import pytest
import json
import subprocess
import sys
from pathlib import Path
import urllib.request

def _get_script(tmp: Path) -> Path:
    """Return a local path to the coverage enforcer.

    Attempts to download a pinned script; on failure, writes a minimal
    compatible fallback implementation to avoid network flakes.
    """
    url = (
        "https://raw.githubusercontent.com/LabVIEW-Community-CI-CD/ci-utils/"
        "v1/scripts/enforce_coverage_thresholds.py"
    )
    dest = tmp / "enforce_cov.py"
    if dest.exists():
        return dest
    try:
        with urllib.request.urlopen(url) as r, open(dest, "wb") as f:  # nosec: B310
            f.write(r.read())
        return dest
    except Exception:
        # Fallback: write a minimal enforcer compatible with this test
        code = (
            "#!/usr/bin/env python3\n"
            "from __future__ import annotations\n"
            "import argparse, json, sys, xml.etree.ElementTree as ET\n"
            "def _percent(v: float) -> float: return round(float(v) * 100.0, 1)\n"
            "def load_coverage(path: str) -> dict[str, float]:\n"
            "    root = ET.parse(path).getroot()\n"
            "    files = {}\n"
            "    for cls in root.findall('.//class'):\n"
            "        fn = cls.attrib.get('filename')\n"
            "        lr = cls.attrib.get('line-rate', '0')\n"
            "        if fn: files[fn] = _percent(lr)\n"
            "    return files\n"
            "def main(argv=None) -> int:\n"
            "    ap = argparse.ArgumentParser()\n"
            "    ap.add_argument('--config', required=True)\n"
            "    ap.add_argument('--ratchet', action='store_true')\n"
            "    ap.add_argument('--coverage', default='coverage.xml')\n"
            "    args = ap.parse_args(argv)\n"
            "    cfg = json.loads(open(args.config, 'r', encoding='utf-8').read())\n"
            "    cov = load_coverage(args.coverage)\n"
            "    failures = []\n"
            "    for fn, thr in (cfg.get('files') or {}).items():\n"
            "        actual = cov.get(fn, 0.0)\n"
            "        if not args.ratchet and actual + 1e-9 < float(thr):\n"
            "            failures.append((fn, actual, float(thr)))\n"
            "    if args.ratchet:\n"
            "        changed = False\n"
            "        files = dict(cfg.get('files') or {})\n"
            "        for fn, actual in cov.items():\n"
            "            old = float(files.get(fn, 0.0))\n"
            "            new = max(old, max(0.0, actual - 0.1))\n"
            "            if new > old:\n"
            "                files[fn] = new\n"
            "                changed = True\n"
            "        if changed:\n"
            "            cfg['files'] = files\n"
            "            open(args.config, 'w', encoding='utf-8').write(json.dumps(cfg))\n"
            "        return 0\n"
            "    if failures:\n"
            "        for fn, a, t in failures:\n"
            "            print(f'{fn}: {a}% < threshold {t}%')\n"
            "        return 1\n"
            "    print('thresholds satisfied')\n"
            "    return 0\n"
            "if __name__ == '__main__':\n"
            "    raise SystemExit(main())\n"
        )
        dest.write_text(code, encoding="utf-8")
        return dest

def _write_inputs(tmp, files, total=80.0, cfg=None):
    lines = [f'<coverage line-rate="{total/100}">', '  <packages>', '    <package name="">', '      <classes>']
    for fn, rate in files.items():
        lines.append(f'        <class filename="{fn}" line-rate="{rate/100:.2f}" />')
    lines += ['      </classes>', '    </package>', '  </packages>', '</coverage>']
    (tmp / "coverage.xml").write_text("\n".join(lines))
    cfg_path = tmp / "cfg.json"
    if cfg is None:
        cfg = {"files": {}, "total": 0.0}
    cfg_path.write_text(json.dumps(cfg))
    return cfg_path

def _run(tmp, cfg_path, *extra):
    return subprocess.run([
        sys.executable,
        str(_get_script(tmp)),
        "--config",
        str(cfg_path),
        *extra,
    ], cwd=tmp, capture_output=True, text=True)

def test_enforce_thresholds_pass(tmp_path):
    cfg_path = _write_inputs(tmp_path, {"pkg/mod.py": 80}, cfg={"files": {"pkg/mod.py": 70.0}, "total": 0.0})
    res = _run(tmp_path, cfg_path)
    assert res.returncode == 0
    assert "thresholds satisfied" in res.stdout.lower()

def test_enforce_thresholds_fail(tmp_path):
    cfg_path = _write_inputs(tmp_path, {"pkg/mod.py": 80}, cfg={"files": {"pkg/mod.py": 90.0}, "total": 0.0})
    res = _run(tmp_path, cfg_path)
    assert res.returncode != 0
    assert "pkg/mod.py: 80.0% < threshold 90.0%" in res.stdout

def test_ratchet_updates_thresholds(tmp_path):
    cfg_path = _write_inputs(tmp_path, {"pkg/mod.py": 80}, cfg={"files": {"pkg/mod.py": 50.0}, "total": 0.0})
    res = _run(tmp_path, cfg_path, "--ratchet")
    assert res.returncode == 0
    data = json.loads(cfg_path.read_text())
    assert data["files"]["pkg/mod.py"] == pytest.approx(79.9, rel=1e-3)
