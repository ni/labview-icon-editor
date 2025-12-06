"""Codex rules engine package.

This package provides a simple rules engine that aggregates test results
and pull request metadata to produce preventative guidance for developers.
The engine computes statistical correlations between components and test
failures and emits actionable guidance into AGENTS.md.  It is designed to
run entirely within the codex runner without reliance on GitHub Actions.
"""

__all__ = ["cli"]
__version__ = "0.2.0"
