#!/usr/bin/env python3
"""
md_emit.py — Safe Markdown template emitter

Purpose
- Render Markdown from simple {{PLACEHOLDER}} templates with a small JSON/YAML context.
- Avoid quoting/brace pitfalls by using a tolerant replacement engine.
- Write only when contents change; support dry-run and stdout modes.

Usage
  python scripts/md_emit.py \
    --template docs/templates/markdown/examples/repo-guidelines.tpl.md \
    --context  docs/templates/markdown/examples/repo-guidelines.context.json \
    --out      docs/templates/markdown/examples/repo-guidelines.example.md

Options
  --template   Path to a .tpl.md file with {{PLACEHOLDER}} tokens
  --context    Path to JSON or YAML (if PyYAML is available); or omit to use key=val pairs
  --var        Inline key=value (repeatable). Lower precedence than --context
  --out        Output file. If omitted, prints to stdout
  --meta-out   Optional path to write metadata JSON (placeholders, resolution)
  --dry-run    Do not write; print a unified diff when --out is provided

Notes
- Unknown placeholders are left untouched to facilitate iterative authoring.
- Only line-ending normalization is applied (LF). No formatting is enforced.
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import sys
from typing import Dict, List, Set


def _load_context(path: str | None) -> Dict[str, str]:
    data: Dict[str, str] = {}
    if not path:
        return data
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    # Try JSON first
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return {str(k): str(v) for k, v in obj.items()}
    except Exception:
        pass
    # Try YAML if available (optional dependency)
    try:
        import yaml  # type: ignore

        obj = yaml.safe_load(text)
        if isinstance(obj, dict):
            return {str(k): str(v) for k, v in obj.items()}
    except Exception:
        # Fallback: empty context when YAML missing or invalid
        return {}
    return {}


PLACEHOLDER_RE = re.compile(r"\{\{\s*([A-Za-z0-9_\-\.]+)\s*\}\}")


def extract_placeholders(template: str) -> List[str]:
    found: Set[str] = set(m.group(1) for m in PLACEHOLDER_RE.finditer(template))
    return sorted(found)


def render(template: str, ctx: Dict[str, str]) -> str:
    def repl(m: re.Match[str]) -> str:
        key = m.group(1)
        return ctx.get(key, m.group(0))

    return PLACEHOLDER_RE.sub(repl, template)


def normalize_lf(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="Emit Markdown from a simple template and context")
    p.add_argument("--template", required=True)
    p.add_argument("--context", default=None)
    p.add_argument("--var", action="append", default=[], help="Inline key=value (repeat)")
    p.add_argument("--out", default=None)
    p.add_argument("--meta-out", dest="meta_out", default=None)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args(argv)

    # Load template
    with open(args.template, "r", encoding="utf-8") as f:
        tpl = f.read()

    # Load context
    ctx = _load_context(args.context)
    for pair in args.var:
        if "=" in pair:
            k, v = pair.split("=", 1)
            ctx.setdefault(k, v)

    placeholders = extract_placeholders(tpl)
    rendered = normalize_lf(render(tpl, ctx))

    if not args.out:
        sys.stdout.write(rendered)
        # When writing to stdout, optionally still write metadata if requested
        if args.meta_out:
            meta = {
                "template": os.path.abspath(args.template),
                "out": None,
                "placeholdersUsed": placeholders,
                "placeholdersMissing": [k for k in placeholders if k not in ctx],
                "contextKeys": sorted(list(ctx.keys())),
                "changed": True,
            }
            os.makedirs(os.path.dirname(args.meta_out) or ".", exist_ok=True)
            with open(args.meta_out, "w", encoding="utf-8", newline="\n") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
        return 0

    # Write-on-change with optional diff
    prior = None
    if os.path.exists(args.out):
        with open(args.out, "r", encoding="utf-8") as f:
            prior = normalize_lf(f.read())

    changed = prior != rendered
    if not changed:
        print(f"No changes: {args.out}")
        # Still emit meta if requested for analytics
        if args.meta_out:
            meta = {
                "template": os.path.abspath(args.template),
                "out": os.path.abspath(args.out),
                "placeholdersUsed": placeholders,
                "placeholdersMissing": [k for k in placeholders if k not in ctx],
                "contextKeys": sorted(list(ctx.keys())),
                "changed": False,
            }
            os.makedirs(os.path.dirname(args.meta_out) or ".", exist_ok=True)
            with open(args.meta_out, "w", encoding="utf-8", newline="\n") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
        return 0

    if args.dry_run:
        a = (prior or "").splitlines(keepends=True)
        b = rendered.splitlines(keepends=True)
        diff = difflib.unified_diff(a, b, fromfile=f"a/{args.out}", tofile=f"b/{args.out}")
        sys.stdout.writelines(diff)
        # Emit meta if requested
        if args.meta_out:
            meta = {
                "template": os.path.abspath(args.template),
                "out": os.path.abspath(args.out),
                "placeholdersUsed": placeholders,
                "placeholdersMissing": [k for k in placeholders if k not in ctx],
                "contextKeys": sorted(list(ctx.keys())),
                "changed": True,
            }
            os.makedirs(os.path.dirname(args.meta_out) or ".", exist_ok=True)
            with open(args.meta_out, "w", encoding="utf-8", newline="\n") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
        return 0

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(rendered)
    print(f"Wrote: {args.out}")
    # Emit meta if requested
    if args.meta_out:
        meta = {
            "template": os.path.abspath(args.template),
            "out": os.path.abspath(args.out),
            "placeholdersUsed": placeholders,
            "placeholdersMissing": [k for k in placeholders if k not in ctx],
            "contextKeys": sorted(list(ctx.keys())),
            "changed": True,
        }
        os.makedirs(os.path.dirname(args.meta_out) or ".", exist_ok=True)
        with open(args.meta_out, "w", encoding="utf-8", newline="\n") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
