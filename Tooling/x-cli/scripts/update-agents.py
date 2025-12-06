#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SNIPPET_PATH = ROOT / 'commit-template.snippet.md'
COMMIT_TEMPLATE = ROOT / 'scripts' / 'commit-template.txt'
start = '<!-- agent:commit_message_template:start -->'
end = '<!-- agent:commit_message_template:end -->'
note = '<!-- do not edit: generated from commit-template.snippet.md; run `python scripts/update-agents.py` only when the commit template or AGENTS snippets change -->'

snippet = SNIPPET_PATH.read_text(encoding='utf-8').rstrip()

def replace_block(path: Path) -> None:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r'(^[ \t]*)' + re.escape(start) + r'.*?' + re.escape(end), re.DOTALL | re.MULTILINE)

    def repl(match: re.Match) -> str:
        indent = match.group(1)
        snippet_body = '\n'.join(f'{indent}{line}' for line in snippet.splitlines())
        return (
            f'{indent}{start}\n'
            f'{indent}{note}\n'
            f'{indent}```\n'
            f'{snippet_body}\n'
            f'{indent}```\n'
            f'{indent}{end}'
        )

    new_text, count = pattern.subn(repl, text)
    if count != 1:
        raise RuntimeError(f'Markers not found in {path}')
    path.write_text(new_text, encoding='utf-8')


def write_commit_template(path: Path) -> None:
    example = (
        "# SRS IDs are validated against the repository's registry.\n"
        "# If an ID exists in multiple specs or versions, append '@<spec-version>' to disambiguate.\n"
        "# Unknown or ambiguous IDs (missing or mismatched version) will cause the commit to be rejected.\n"
        "# Tip: The commit-msg hook may enrich the first line with a short bracketed suffix\n"
        "# (e.g., [r3] for CI run attempt 3 or [n2] for a local retry).\n"
        "# You can add your own tags via XCLI_SUMMARY_TAGS=\"tag1 tag2\".\n"
        "# Enrichment is best-effort and always respects the 50-char summary limit.\n"
        "# If tags are dropped to fit, they are preserved in the commit body as\n"
        "# a trailer line (X-Tags: ...) and recorded in .codex/telemetry.json.\n"
        "# To include an issue reference in the meta line, create an issue and append its number:\n"
        "#   python scripts/create_issue.py --title \"<brief summary>\" [--body \"...\"]\n"
        "# Then add:  | issue: #<ISSUE-NUMBER>  at the end of the third line.\n\n"
        "# Example:\n"
        "# Update docs and rules engine\n"
        "#\n"
        "# codex: impl | SRS: FGC-REQ-DEV-005@1.1, FGC-REQ-SPEC-001@1.0 | issue: #123\n"
    )
    content = (
        '# do not edit: generated from commit-template.snippet.md; run `python scripts/update-agents.py` only when the commit template or AGENTS snippets change\n'
        f'{snippet}\n'
        f'{example}'
    )
    path.write_text(content, encoding='utf-8')


for rel in ['AGENTS.md', 'scripts/commit-template.txt']:
    path = ROOT / rel
    if path == COMMIT_TEMPLATE:
        write_commit_template(path)
    else:
        replace_block(path)
