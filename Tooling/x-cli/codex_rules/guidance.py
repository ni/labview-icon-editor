"""Guidance generation and documentation update logic.

This module materializes candidate rules into guidance entries, merges them
into storage, and rewrites AGENTS.md with a managed section delimited by
sentinel comments.  When no rules are active, the block remains empty.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Iterable, List

def create_guidance_entries(candidates: Iterable[Dict], templates: Dict) -> List[Dict]:
    """Materialize guidance entries from candidate statistics and templates."""
    default_tpl = templates.get("default", "After touching {component}, run {command} to pre‑empt {test} failures.")
    overrides = templates.get("overrides", {}) or {}
    commands = templates.get("commands", {}) or {}
    guidance: List[Dict] = []
    for cand in candidates:
        component = cand["component"]
        test_id = cand["test_id"]
        rule_id = f"{component}->{test_id}"
        # Choose the best template
        tpl = overrides.get(rule_id, default_tpl)
        command = commands.get(component)
        if not command:
            # Fallback to a generic command using pytest/junit style
            command = f"pytest -k {test_id.split('#')[-1]}"
        description = tpl.format(component=component, test=test_id, command=command)
        guidance.append(
            {
                "rule_id": rule_id,
                "component": component,
                "test_id": test_id,
                "support_prs": cand["support_prs"],
                "confidence": cand["confidence"],
                "baseline": cand["baseline"],
                "lift": cand["lift"],
                "p_value": cand["p_value"],
                "template": tpl,
                "command": command,
                "description": description,
            }
        )
    return guidance


def update_agents_md(path: str | Path, guidance: List[Dict], section_title: str) -> None:
    """Rewrite the managed guidance block in AGENTS.md.

    The block is delimited by sentinel comments:
      <!-- BEGIN: codex-rules (auto-generated; do not edit) -->
      ... contents ...
      <!-- END: codex-rules -->

    If no guidance is provided, the block remains empty.  A header with
    the section title is inserted above the sentinel block if not present.
    """
    p = Path(path)
    if not p.exists():
        original = ""
    else:
        original = p.read_text(encoding="utf-8")
    begin_marker = "<!-- BEGIN: codex-rules (auto-generated; do not edit) -->"
    end_marker = "<!-- END: codex-rules -->"

    # Build the new block
    lines: List[str] = []
    lines.append(f"## {section_title}")
    lines.append("")
    lines.append(begin_marker)
    if guidance:
        for rule in guidance:
            comp = rule["component"]
            test_id = rule["test_id"]
            cmd = rule["command"]
            support = rule["support_prs"]
            lift = rule["lift"]
            # Use the rendered description from the template, but wrap in bullet
            desc = rule["description"]
            lines.append(f"- **{comp.capitalize()}**: {desc} _(support: {support} PRs, lift: {lift:.2f})_")
    lines.append(end_marker)
    block = "\n".join(lines)

    # If the file already has a sentinel block, replace it
    if begin_marker in original and end_marker in original:
        pre = original.split(begin_marker)[0]
        post = original.split(end_marker)[-1]
        new_content = f"{pre}{block}{post}"
    else:
        # Append at the end, ensuring a trailing newline
        if original and not original.endswith("\n"):
            original += "\n"
        new_content = original + "\n" + block + "\n"
    p.write_text(new_content, encoding="utf-8")
