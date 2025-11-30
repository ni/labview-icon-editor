#!/usr/bin/env python3
"""Utility to write Markdown files with consistent encoding and newlines.

Example:
    python scripts/write_markdown.py docs/templates/markdown/guide.md.tpl docs/example-guide.md --allow-overwrite
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def read_source(source: str) -> str:
    if source == "-":
        return sys.stdin.read()
    return Path(source).read_text(encoding="utf-8")


def ensure_newlines(content: str, ensure_final_newline: bool) -> str:
    normalized = content.replace("\r\n", "\n").replace("\r", "\n")
    if ensure_final_newline and not normalized.endswith("\n"):
        normalized += "\n"
    return normalized


def write_destination(destination: Path, content: str, overwrite: bool) -> None:
    if destination.exists() and not overwrite:
        raise FileExistsError(f"Refusing to overwrite existing file: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Write Markdown to a target file with UTF-8 encoding and LF newlines. "
            "Read from a source file or stdin and normalise line endings."
        )
    )
    parser.add_argument(
        "source",
        help="Path to the Markdown source file, or '-' to read from stdin.",
    )
    parser.add_argument(
        "destination",
        help="Path to the Markdown file to write.",
    )
    parser.add_argument(
        "--allow-overwrite",
        action="store_true",
        help="Overwrite destination if it already exists (default: abort).",
    )
    parser.add_argument(
        "--no-final-newline",
        dest="ensure_final_newline",
        action="store_false",
        default=True,
        help="Do not append a trailing newline to the output.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        content = read_source(args.source)
    except FileNotFoundError as exc:
        parser.error(f"Source file not found: {exc.filename}")

    normalized = ensure_newlines(content, args.ensure_final_newline)

    destination = Path(args.destination)
    try:
        write_destination(destination, normalized, overwrite=args.allow_overwrite)
    except FileExistsError as exc:
        parser.error(str(exc))

    return 0


if __name__ == "__main__":
    sys.exit(main())
