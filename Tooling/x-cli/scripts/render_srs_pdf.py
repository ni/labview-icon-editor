#!/usr/bin/env python3
"""
Produce site/srs.pdf from site/srs.html using wkhtmltopdf.
Prereqs in CI: sudo apt-get update && sudo apt-get install -y wkhtmltopdf
Falls back gracefully (skips PDF) if wkhtmltopdf is unavailable.
"""
from pathlib import Path
import shutil, subprocess, sys

ROOT = Path(".").resolve()
AGG_HTML = ROOT / "site" / "srs.html"
OUT_PDF = ROOT / "site" / "srs.pdf"

def main():
    if not AGG_HTML.exists():
        print("Aggregated HTML not found; rendering HTML first...")
        subprocess.run(["python", "scripts/render_srs_html.py"], check=True)
    exe = shutil.which("wkhtmltopdf")
    if not exe:
        print("wkhtmltopdf not found; skipping PDF generation.", file=sys.stderr)
        sys.exit(0)
    cmd = [exe, "--enable-local-file-access", str(AGG_HTML), str(OUT_PDF)]
    print("→", " ".join(cmd))
    r = subprocess.run(cmd)
    if r.returncode != 0:
        print("wkhtmltopdf failed; skipping PDF.", file=sys.stderr)
        sys.exit(0)
    print(f"Wrote PDF: {OUT_PDF.relative_to(ROOT).as_posix()}")

if __name__ == "__main__":
    main()
