#!/usr/bin/env python3
"""
Render docs/srs/*.md into a small static HTML site:
 - One HTML per SRS page + index.html
 - Aggregated site/srs.html (all pages) for PDF conversion
 - Zips to site/srs-html.zip
Requires: pip install markdown jinja2 pygments
"""
from pathlib import Path
import re, shutil, zipfile, sys
from datetime import datetime
try:
    import markdown
    from jinja2 import Template
except ImportError as e:
    print("Missing dependency. Run: pip install markdown jinja2 pygments", file=sys.stderr)
    raise

ROOT = Path(".").resolve()
SRS = ROOT / "docs" / "srs"
SITE = ROOT / "site" / "srs-html"
AGG_HTML = ROOT / "site" / "srs.html"
ZIP = ROOT / "site" / "srs-html.zip"

ID_RE = re.compile(r"\b([A-Z]{3}-REQ-([A-Z]+)-(\d{3}))\b")

BASE_TMPL = Template("""<!doctype html>
<html lang="en"><head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>{{ title }}</title>
  <style>
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,'Helvetica Neue',Arial,sans-serif;line-height:1.55;margin:0;background:#fff;color:#222}
    header,nav,main,footer{max-width:1100px;margin:0 auto;padding:1.2rem}
    header{border-bottom:1px solid #eee}
    nav{background:#fafafa;border-bottom:1px solid #eee}
    nav a{margin-right:1rem;text-decoration:none}
    .toc{font-size:.95rem}
    pre{overflow:auto;padding:.75rem;border:1px solid #eee;border-radius:6px;background:#f7f7f7}
    code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,'Liberation Mono',monospace}
    h1,h2,h3{line-height:1.25}
    .meta{color:#666;font-size:.9rem}
    footer{border-top:1px solid #eee;color:#666;font-size:.9rem}
  </style>
</head><body>
  <header><h1>{{ header }}</h1><div class="meta">{{ meta }}</div></header>
  <nav class="toc">{{ nav|safe }}</nav>
  <main>{{ content|safe }}</main>
  <footer>Generated {{ now }} UTC · ISO/IEC/IEEE 29148:2018 evidence</footer>
</body></html>""")

def load_pages():
    pages = []
    for p in sorted(SRS.glob("*.md")):
        if p.name == "_template.md": continue
        t = p.read_text(encoding="utf-8", errors="ignore")
        title_m = re.search(r"^#\s+(.+)$", t, re.M)
        title = title_m.group(1).strip() if title_m else p.stem
        id_m = ID_RE.search(t)
        if id_m:
            rid, domain, num = id_m.group(1), id_m.group(2), int(id_m.group(3))
            order = (0, "", 0)
        else:
            rid, domain, num = "", "", 0
            order = (-1, "", 0)
        if p.name == "core.md":
            order = (-2, "CORE", -1)  # core first
        else:
            order = (1, domain, num)
        pages.append({"path": p, "title": title, "rid": rid, "domain": domain, "num": num, "order": order})
    # sort: core → domain → number
    pages.sort(key=lambda x: x["order"])
    return pages

def md_to_html(md_text: str) -> str:
    exts = ["toc", "fenced_code", "codehilite"]
    return markdown.markdown(md_text, extensions=exts, output_format="html5")

def render_site():
    pages = load_pages()
    if SITE.exists(): shutil.rmtree(SITE)
    SITE.mkdir(parents=True, exist_ok=True)
    links = []
    # Per-page render
    for pg in pages:
        raw = pg["path"].read_text(encoding="utf-8", errors="ignore")
        html = md_to_html(raw)
        fname = pg["path"].stem + ".html"
        links.append(f'<a href="{fname}">{pg["title"]}</a>')
        page_html = BASE_TMPL.render(
            title=pg["title"],
            header=pg["title"],
            meta=pg["rid"] or "",
            nav=" · ".join(links),
            content=html,
            now=datetime.utcnow().isoformat(timespec="seconds")+"Z"
        )
        (SITE / fname).write_text(page_html, encoding="utf-8")
    # Index
    toc = "<ul>" + "".join([f'<li><a href="{pg["path"].stem}.html">{pg["title"]}</a></li>' for pg in pages]) + "</ul>"
    idx_html = BASE_TMPL.render(
        title="SRS — Index",
        header="SRS — Index",
        meta=f"{len(pages)} pages",
        nav="",
        content=toc,
        now=datetime.utcnow().isoformat(timespec="seconds")+"Z"
    )
    (SITE / "index.html").write_text(idx_html, encoding="utf-8")
    # Aggregated single HTML
    agg_parts = []
    for pg in pages:
        raw = pg["path"].read_text(encoding="utf-8", errors="ignore")
        section = md_to_html(raw)
        hdr = f'<h1 id="{pg["path"].stem}">{pg["title"]}</h1>'
        agg_parts.append(hdr + section)
    agg_html = BASE_TMPL.render(
        title="SRS — Complete",
        header="SRS — Complete",
        meta=f"{len(pages)} pages",
        nav="",
        content="\n<hr/>\n".join(agg_parts),
        now=datetime.utcnow().isoformat(timespec="seconds")+"Z"
    )
    AGG_HTML.parent.mkdir(parents=True, exist_ok=True)
    AGG_HTML.write_text(agg_html, encoding="utf-8")
    # Zip the site
    if ZIP.exists(): ZIP.unlink()
    with zipfile.ZipFile(ZIP, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for p in SITE.rglob("*"):
            if p.is_file():
                z.write(p, arcname=p.relative_to(SITE.parent).as_posix())
    print(f"Wrote site: {SITE.relative_to(ROOT).as_posix()}")
    print(f"Wrote aggregated: {AGG_HTML.relative_to(ROOT).as_posix()}")
    print(f"Wrote zip: {ZIP.relative_to(ROOT).as_posix()}")

if __name__ == "__main__":
    render_site()
