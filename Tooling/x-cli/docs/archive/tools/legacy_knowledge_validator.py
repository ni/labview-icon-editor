#!/usr/bin/env python3
"""
Legacy knowledge bundle validator (root or ZIP).

Prints in this exact order:
  Root: …
  Manifest: …
  Crosswalks: PASS|FAIL (files=…, parsed_ok=…, rows_ok=…) [Notes: …]
  Glossary DoD: PASS|FAIL
  Edition Appendix: PASS|FAIL (path|—)
  Policies PDFs: OK|WARN: …
  OVERALL: PASS|FAIL
  --JARVIS-VALIDATOR-JSON--
  { … JSON … }

Exit codes: 0 PASS · 1 FAIL · 2 fatal error.
"""
from __future__ import annotations
import argparse, csv, json, re, sys, zipfile
from pathlib import Path

ALIASES = {
    "crosswalks": ["crosswalks", "mappings"],
    "glossary":   ["glossary", "terms", "dictionary"],
    "appendix":   ["appendix", "edition-appendix", "editionappendix", "annex"],
    "policies":   ["policies", "policy", "plans", "planning", "procedures"]
}

def _safe_unzip(zpath: Path, dest: Path) -> list[Path]:
    dest = dest.resolve()
    out = []
    with zipfile.ZipFile(str(zpath), "r") as zf:
        for m in zf.infolist():
            p = (dest / m.filename).resolve()
            if not str(p).startswith(str(dest)):
                raise RuntimeError(f"unsafe ZIP entry blocked: {m.filename}")
            if m.is_dir():
                p.mkdir(parents=True, exist_ok=True)
            else:
                p.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(m) as src, open(p, "wb") as dst:
                    dst.write(src.read())
                out.append(p)
    return out

def _first_role(root: Path, names: list[str]) -> Path|None:
    for cand in names:
        p = (root / cand)
        if p.exists():
            return p
        for child in root.iterdir():
            if child.name.lower() == cand.lower():
                return child
    return None

def _detect_roles(root: Path) -> dict[str, Path|None]:
    return {k: _first_role(root, v) for k, v in ALIASES.items()}

def _count_rows_csv(p: Path) -> int:
    with p.open("r", encoding="utf-8", errors="ignore", newline="") as f:
        return sum(1 for _ in csv.reader(f))

def _count_rows_yaml(txt: str) -> int:
    try:
        from ruamel.yaml import YAML
        y = YAML(typ="safe")
        data = y.load(txt)
    except Exception:
        return 0
    if data is None: return 0
    if isinstance(data, list): return len(data)
    if isinstance(data, dict): return len(data)
    return 1

def _count_rows_json(txt: str) -> int:
    data = json.loads(txt)
    if isinstance(data, list): return len(data)
    if isinstance(data, dict): return len(data)
    return 1

def _scan_crosswalks(d: Path|None):
    files, parsed_ok, rows_ok, errors, fmts = [], 0, 0, [], []
    if d and d.exists():
        for p in sorted(d.rglob("*")):
            if not p.is_file(): continue
            ext = p.suffix.lower()
            try:
                if ext == ".csv":
                    rows = _count_rows_csv(p)
                    parsed_ok += 1; rows_ok += rows; fmts.append("csv")
                    files.append({"path": p.as_posix(), "format": "csv", "rows": rows})
                elif ext in (".yaml", ".yml"):
                    rows = _count_rows_yaml(p.read_text(encoding="utf-8", errors="ignore"))
                    parsed_ok += 1; rows_ok += rows; fmts.append("yaml")
                    files.append({"path": p.as_posix(), "format": "yaml", "rows": rows})
                elif ext == ".json":
                    rows = _count_rows_json(p.read_text(encoding="utf-8", errors="ignore"))
                    parsed_ok += 1; rows_ok += rows; fmts.append("json")
                    files.append({"path": p.as_posix(), "format": "json", "rows": rows})
            except Exception as e:
                errors.append(f"{p.name}: {e}")
    return files, parsed_ok, rows_ok, errors, sorted(set(fmts))

def _has_dod(glossary: Path|None) -> bool:
    if not glossary or not glossary.exists(): return False
    rx = re.compile(r"\b(definition\s+of\s+done|DoD)\b", re.I)
    for p in glossary.rglob("*"):
        if p.suffix.lower() in (".md", ".txt", ".adoc"):
            try:
                if rx.search(p.read_text(encoding="utf-8", errors="ignore")):
                    return True
            except Exception:
                pass
    return False

def _find_appendix(appx: Path|None):
    if not appx or not appx.exists(): return False, None
    prefer = None
    for p in appx.rglob("*"):
        if p.is_file():
            n = p.name.lower()
            if "edition-appendix" in n or "editionappendix" in n:
                prefer = p; break
    if not prefer:
        for p in appx.rglob("*.md"):
            try:
                txt = p.read_text(encoding="utf-8", errors="ignore")
                if re.search(r"^#\s*Edition\s+Appendix\b", txt, re.I|re.M):
                    prefer = p; break
            except Exception:
                pass
    return (prefer is not None), (prefer.as_posix() if prefer else None)

def _policies_note(policies: Path|None) -> str:
    if not policies or not policies.exists():
        return "WARN: policies dir missing"
    pdfs = [p for p in policies.rglob("*.pdf")]
    return f"OK: {len(pdfs)} PDFs" if pdfs else "WARN: 0 PDFs found"

def _emit(root: Path|None, manifest: Path|None, roles: dict, cw, dod_ok, appx_ok, appx_path, pol_note, extra_errors: list[str]):
    files, parsed_ok, rows_ok, errs, fmts = cw
    present = bool(roles.get("crosswalks") and (files or parsed_ok))
    overall = "PASS" if (present and dod_ok and appx_ok) else "FAIL"
    root_str = (root.as_posix() if root else "—")
    man_str  = (manifest.as_posix() if manifest else "—")
    notes = f"[Notes: formats={','.join(fmts)}]" if fmts else ""
    print(f"Root: {root_str}")
    print(f"Manifest: {man_str}")
    print(f"Crosswalks: {'PASS' if present else 'FAIL'} (files={len(files)}, parsed_ok={parsed_ok}, rows_ok={rows_ok}) {notes}".rstrip())
    print(f"Glossary DoD: {'PASS' if dod_ok else 'FAIL'}")
    print(f"Edition Appendix: {'PASS' if appx_ok else 'FAIL'} ({appx_path or '—'})")
    print(f"Policies PDFs: {pol_note}")
    print(f"OVERALL: {overall}")
    summary = {
        "overall": overall,
        "root": root_str,
        "manifest": man_str,
        "roles": {k: (v.as_posix() if isinstance(v, Path) else None) for k, v in roles.items()},
        "crosswalks": {"present": present, "files": files, "parsed_ok": parsed_ok, "rows_ok": rows_ok, "errors": errs + (extra_errors or [])},
        "glossary_DoD": dod_ok,
        "appendix_found": appx_ok,
        "appendix_path": appx_path,
        "policies_pdf_note": pol_note
    }
    print("\n--JARVIS-VALIDATOR-JSON--")
    print(json.dumps(summary, indent=2))
    return 0 if overall == "PASS" else 1

def validate_root(root: Path) -> int:
    manifest = (root / "manifest.yaml") if (root / "manifest.yaml").exists() else None
    roles = _detect_roles(root)
    cw = _scan_crosswalks(roles.get("crosswalks"))
    dod_ok = _has_dod(roles.get("glossary"))
    appx_ok, appx_path = _find_appendix(roles.get("appendix"))
    pol_note = _policies_note(roles.get("policies"))
    return _emit(root, manifest, roles, cw, dod_ok, appx_ok, appx_path, pol_note, [])

def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=str, help="Path to knowledge root (default: .)")
    ap.add_argument("--zip", type=str, help="Path to knowledge ZIP")
    args = ap.parse_args(argv)
    try:
        if args.zip:
            tmp = Path(".artifacts/kv_tmp")
            tmp.mkdir(parents=True, exist_ok=True)
            _safe_unzip(Path(args.zip), tmp)
            kz = tmp / "knowledge"
            root = kz if kz.exists() else tmp
            return validate_root(root)
        else:
            root = Path(args.root or ".").resolve()
            # Auto-fallback to ./knowledge if present
            k = root / "knowledge"
            if k.exists() and k.is_dir():
                root = k.resolve()
            return validate_root(root)
    except Exception as e:
        # Fatal: emit full FAIL summary for automation, then exit 2
        roles = {k: None for k in ALIASES}
        pol_note = "WARN: policies dir missing"
        files, parsed_ok, rows_ok, errors, fmts = [], 0, 0, [str(e)], []
        _emit(None, None, roles, (files, parsed_ok, rows_ok, errors, fmts), False, False, None, pol_note, [str(e)])
        return 2

# Back-compat shims
has_dod = _has_dod
find_appendix = _find_appendix

if __name__ == "__main__":
    raise SystemExit(main())
