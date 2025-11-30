#!/usr/bin/env python3
import sys
from pathlib import Path
import xml.etree.ElementTree as ET


def parse_trx(path: Path) -> tuple[int, int, int]:
    tree = ET.parse(path)
    ns = {'t': 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010'}
    counters = tree.find('.//t:Counters', ns)
    if counters is None:
        return 0, 0, 0
    passed = int(counters.get('passed', 0))
    failed = int(counters.get('failed', 0))
    skipped = int(counters.get('notExecuted', 0))
    return passed, failed, skipped


def main(root: Path) -> None:
    if root.is_dir():
        # Prefer current run files named 'test-results.trx' written by QA.
        preferred = list(root.rglob('test-results.trx'))
        if preferred:
            files = preferred
        else:
            files = list(root.rglob('*.trx'))
    else:
        files = [root]
    total_passed = total_failed = total_skipped = 0
    for file in files:
        p, f, s = parse_trx(file)
        total_passed += p
        total_failed += f
        total_skipped += s
    print(f"Summary: Passed {total_passed}, Failed {total_failed}, Skipped {total_skipped}")


if __name__ == '__main__':
    arg = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
    main(arg)
