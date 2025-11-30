#!/usr/bin/env python3
"""Render the Preventative Measures section from codex_rules.

Reads the codex rules engine's active guidance entries and emits a
markdown section titled "Preventative Measures" (configurable via
`codex_rules.config`). The output is suitable for inclusion in
GitHub PR summaries or documentation.
"""
from __future__ import annotations

from scripts.lib.config import load_config
from scripts.lib.storage import Storage


def render_section() -> str:
    """Return the Preventative Measures section as markdown."""
    config = load_config()
    storage = Storage(config["storage"]["sqlite_path"])
    guidance = storage.get_active_guidance()
    title = config.get("docs", {}).get("section_title", "Preventative Measures")
    lines = [f"## {title}", ""]
    for rule in guidance:
        component = rule["component"].capitalize()
        description = rule["description"]
        support = rule["support_prs"]
        lift = rule["lift"]
        lines.append(
            f"- **{component}**: {description} _(support: {support} PRs, lift: {lift:.2f})_"
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    print(render_section(), end="")


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    main()
