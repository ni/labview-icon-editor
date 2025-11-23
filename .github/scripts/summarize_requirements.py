#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path
from textwrap import shorten
import sys
import io


def build_summary(csv_path: Path, sample_rows: int, title: str, repo: str, summary_full: bool) -> str:
    def clean(text: str) -> str:
        return text.replace("\r", "").replace("\n", "<br>")

    rows = list(csv.reader(csv_path.open("r", encoding="utf-8", newline="")))
    header_title = f"{title} ({repo})" if repo else title
    summary = [f"### {header_title}", ""]
    if not rows:
        summary.append(f"{csv_path} is empty.")
        return "\n".join(summary)

    header, body = rows[0], rows[1:]
    summary.append(f"- File: `{csv_path}`")
    summary.append(f"- Rows: {len(rows)} (1 header + {len(body)} data)")
    summary.append(f"- Columns: {len(header)}")
    summary.append("")

    sample = body if summary_full else body[:sample_rows]
    if sample:
        summary.append("| " + " | ".join(header) + " |")
        summary.append("| " + " | ".join(["---"] * len(header)) + " |")
        for row in sample:
            cells = [shorten(clean(val), width=50, placeholder="...") for val in row]
            summary.append("| " + " | ".join(cells) + " |")
        summary.append("")

    return "\n".join(summary)


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except Exception:
        sys.stdout = io.TextIOWrapper(sys.stdout.detach(), encoding="utf-8")

    parser = argparse.ArgumentParser(description="Summarize TRW checklist CSV as markdown.")
    parser.add_argument("--csv", default="docs/requirements/Requirements.csv", help="Path to requirements checklist CSV")
    parser.add_argument("--rows", type=int, default=5, help="Number of data rows to include in the sample table")
    parser.add_argument("--title", default="Requirements Checklist", help="Title to use for the summary/full outputs")
    parser.add_argument("--repo", default="", help="Repository identifier (e.g., owner/repo) to show alongside the title")
    parser.add_argument("--summary-full", action="store_true", help="Include the full table in the summary output (ignores --rows for summary)")
    parser.add_argument("--summary-output", default="", help="Path to write summary (e.g., GITHUB_STEP_SUMMARY)")
    parser.add_argument("--full-output", default="", help="Path to write full table markdown (all rows)")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        raise SystemExit(f"CSV not found at {csv_path}")

    repo = args.repo or os.environ.get("GITHUB_REPOSITORY", "")
    summary = build_summary(csv_path, args.rows, args.title, repo, args.summary_full)

    if args.summary_output:
        out_path = Path(args.summary_output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(summary + "\n", encoding="utf-8")
    if args.full_output:
        out_path = Path(args.full_output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        # Full table: header + all rows
        rows = list(csv.reader(csv_path.open("r", encoding="utf-8", newline="")))
        if rows:
            def clean(text: str) -> str:
                return text.replace("\r", "").replace("\n", "<br>")
            header, body = rows[0], rows[1:]
            full_lines = []
            header_title = f"{args.title} ({repo})" if repo else args.title
            full_lines.append(f"### {header_title} (Full)")
            full_lines.append("")
            full_lines.append("| " + " | ".join(header) + " |")
            full_lines.append("| " + " | ".join(["---"] * len(header)) + " |")
            for row in body:
                cells = [clean(val) for val in row]
                full_lines.append("| " + " | ".join(cells) + " |")
            full_lines.append("")
            out_path.write_text("\n".join(full_lines), encoding="utf-8")
        else:
            out_path.write_text(f"{csv_path} is empty.\n", encoding="utf-8")

    if not args.summary_output and not args.full_output:
        sys.stdout.write(summary + "\n")


if __name__ == "__main__":
    main()
