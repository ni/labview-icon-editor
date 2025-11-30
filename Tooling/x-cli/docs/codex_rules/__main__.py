"""Entry point for the codex rules engine.

Executing ``python -m codex_rules`` forwards to the CLI defined in
``codex_rules.cli``.
"""
from .cli import main


if __name__ == "__main__":
    main()
