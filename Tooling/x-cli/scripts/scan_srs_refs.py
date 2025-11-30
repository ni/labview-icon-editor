#!/usr/bin/env python
"""Scan source directories for files lacking SRS references."""
import argparse
import os
import sys
from typing import Dict, List

# Parse module-srs-map.yaml without external deps

def load_map(path: str) -> Dict[str, List[str]]:
    mapping: Dict[str, List[str]] = {}
    if not os.path.exists(path):
        return mapping
    current = None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            if not line.startswith(' ') and line.endswith(':'):
                current = line.strip().rstrip(':')
                if not current.endswith('/'):
                    current += '/'
                mapping[current] = []
            elif line.startswith('  - ') and current:
                mapping[current].append(line.strip()[2:].strip())
    return mapping


def get_requirements(path: str, mapping: Dict[str, List[str]]):
    path = path.replace('\\', '/')
    reqs: List[str] = []
    for prefix, ids in mapping.items():
        if path.startswith(prefix):
            reqs.extend(ids)
    return reqs


def scan(root: str, targets: List[str], map_path: str) -> int:
    mapping = load_map(map_path)
    missing = []
    for target in targets:
        base = os.path.join(root, target)
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for name in files:
                rel = os.path.relpath(os.path.join(dirpath, name), root)
                rel_norm = rel.replace(os.sep, '/')
                if not get_requirements(rel_norm, mapping):
                    missing.append(rel_norm)
    if missing:
        for m in missing:
            print(f"::error file={m}::No SRS ID mapped; add entry in docs/module-srs-map.yaml", file=sys.stderr)
        print(f"{len(missing)} files missing SRS IDs", file=sys.stderr)
        return 1
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Scan for SRS reference coverage")
    parser.add_argument('--root', default=os.getcwd(), help='Repository root path')
    parser.add_argument('--map', default='docs/module-srs-map.yaml', help='Path to module-srs map')
    parser.add_argument('paths', nargs='*',
                        default=['src', 'notifications', 'scripts', '.github/workflows'],
                        help='Directories to scan')
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    map_path = os.path.join(root, args.map)
    code = scan(root, args.paths, map_path)
    return code

if __name__ == '__main__':
    sys.exit(main())
