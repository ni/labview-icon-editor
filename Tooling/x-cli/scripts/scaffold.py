#!/usr/bin/env python3
"""Scaffold source, test, and docs files for a new module."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

HANDLER_TEMPLATE = """using System;

namespace XCli.{{MODULE}};

public static class {{MODULE}}Command
{
    public static void Execute()
    {
        throw new NotImplementedException();
    }
}
"""

TEST_TEMPLATE = """using Xunit;

namespace XCli.Tests;

public class {{MODULE}}Tests
{
    [Fact]
    public void Placeholder()
    {
        Assert.Fail("scaffolded");
    }
}
"""

DOC_TEMPLATE = """# {{MODULE}}

Documentation for {{MODULE}} is not yet available.
"""


def validate_template(content: str, name: str) -> str:
    """Ensure template contains the ``{{MODULE}}`` placeholder."""
    if "{{MODULE}}" not in content:
        raise SystemExit(f"{name} template missing {{MODULE}} placeholder")
    return content


def read_template(path: str | None, default: str) -> str:
    """Return template text from ``path`` or ``default`` if path is None."""
    if path:
        text = Path(path).read_text(encoding="utf-8")
        name = Path(path).name
    else:
        text = default
        name = "inline"
    return validate_template(text, name)


def lint_files(paths: list[Path]) -> None:
    """Run ``dotnet format`` on the provided paths, if available."""
    try:
        subprocess.run(
            ["dotnet", "format", "--include", *map(str, paths)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except FileNotFoundError:
        print("dotnet format not installed; skipping lint")
    except subprocess.CalledProcessError as exc:
        print(exc.stdout)
        print("dotnet format failed; see output above")

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Scaffold module source, tests, and docs.",
    )
    parser.add_argument("module", help="PascalCase name of the module.")
    parser.add_argument(
        "--test-template",
        help="Path to a test template file using {{MODULE}} placeholders.",
        default=None,
    )
    parser.add_argument(
        "--doc-template",
        help="Path to a documentation template file using {{MODULE}} placeholders.",
        default=None,
    )
    parser.add_argument(
        "--lint",
        action="store_true",
        help="Run dotnet format on generated C# files.",
    )
    args = parser.parse_args(argv)

    module = args.module

    handler_dir = ROOT / "src" / "XCli" / module
    handler_dir.mkdir(parents=True, exist_ok=True)
    handler_path = handler_dir / f"{module}Command.cs"
    if handler_path.exists():
        raise SystemExit(f"{handler_path} already exists")
    handler_template = validate_template(HANDLER_TEMPLATE, "handler")
    handler_path.write_text(
        handler_template.replace("{{MODULE}}", module),
        encoding="utf-8",
    )

    test_path = ROOT / "tests" / "XCli.Tests" / f"{module}Tests.cs"
    if test_path.exists():
        raise SystemExit(f"{test_path} already exists")
    test_content = read_template(args.test_template, TEST_TEMPLATE)
    test_path.write_text(
        test_content.replace("{{MODULE}}", module),
        encoding="utf-8",
    )

    doc_path = ROOT / "docs" / f"{module}.md"
    if doc_path.exists():
        raise SystemExit(f"{doc_path} already exists")
    doc_content = read_template(args.doc_template, DOC_TEMPLATE)
    doc_path.write_text(
        doc_content.replace("{{MODULE}}", module),
        encoding="utf-8",
    )

    if args.lint:
        lint_files([handler_path, test_path])

    print(f"Created {handler_path}")
    print(f"Created {test_path}")
    print(f"Created {doc_path}")

    return 0

if __name__ == "__main__":  # pragma: no cover - script entrypoint
    raise SystemExit(main())
