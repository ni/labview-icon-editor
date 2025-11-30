#!/usr/bin/env python3
import json
import sys
import time
from pathlib import Path

def main(raw_path: str, out_path: str) -> None:
    src = Path(raw_path)
    dst = Path(out_path)
    timestamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    entries = []
    if src.exists():
        with src.open() as f:
            for line in f:
                line = line.strip()
                if not line or '|' not in line:
                    continue
                name, code = line.split('|', 1)
                try:
                    code_int = int(code)
                except ValueError:
                    # skip malformed lines
                    continue
                entries.append({
                    'step': name,
                    'success': code_int == 0,
                    'exit_code': code_int,
                    'timestamp': timestamp,
                })
    with dst.open('w') as out:
        for obj in entries:
            out.write(json.dumps(obj) + '\n')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('usage: aggregate_ci_logs.py <raw_log> <out_jsonl>', file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
