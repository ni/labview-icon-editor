#!/usr/bin/env python3
"""Check telemetry modules expose agent feedback.

Walks ``codex_rules/`` to find modules that import
``record_telemetry_entry`` (or the legacy ``append_telemetry_entry``)
or define a ``--record-telemetry`` CLI flag.
Any such module must also expose an ``agent_feedback`` argument or
``--agent-feedback`` flag. Emits offending file paths and exits with a
non-zero status when violations are found.
"""
from __future__ import annotations

import ast
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CODEX_RULES = REPO_ROOT / "codex_rules"


def _imports_telemetry_helper(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            for alias in node.names:
                if alias.name in {"append_telemetry_entry", "record_telemetry_entry"}:
                    return True
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name in {"append_telemetry_entry", "record_telemetry_entry"}:
                    return True
    return False


def _has_agent_feedback(tree: ast.AST, text: str) -> bool:
    """Return True when module exposes agent_feedback."""
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = []
            args.extend(getattr(node.args, "posonlyargs", []))
            args.extend(node.args.args)
            args.extend(node.args.kwonlyargs)
            if any(arg.arg == "agent_feedback" for arg in args):
                return True
    return "--agent-feedback" in text


def main() -> int:
    violations: list[str] = []

    for path in CODEX_RULES.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        try:
            tree = ast.parse(text, filename=str(path))
        except SyntaxError:
            # Skip files with syntax errors; they will be caught elsewhere.
            continue

        uses_helper = _imports_telemetry_helper(tree)
        defines_record_flag = "--record-telemetry" in text
        if uses_helper or defines_record_flag:
            if not _has_agent_feedback(tree, text):
                violations.append(path.relative_to(REPO_ROOT).as_posix())

    if violations:
        print("Agent feedback not exposed in:")
        for v in violations:
            print(f" - {v}")
        print(
            "\nAdd an 'agent_feedback' parameter or '--agent-feedback' CLI flag to"
            " these modules. This satisfies FGC-REQ-DEV-003; see AGENTS.md"
            " for contract details."
        )
        return 1

    print("All telemetry modules expose agent feedback")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
