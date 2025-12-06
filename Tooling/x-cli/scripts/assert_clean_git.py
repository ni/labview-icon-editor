#!/usr/bin/env python3
"""
Fail if tests left the working tree dirty outside of pytest temp dirs.
"""
import subprocess, sys, os

def main():
    # Detect changes after tests. If anything under repo root is modified, fail.
    res = subprocess.run(["git","status","--porcelain"], capture_output=True, text=True)
    if res.returncode != 0:
        print("git status failed; is this a git checkout?", file=sys.stderr)
        sys.exit(2)
    dirty = [ln for ln in res.stdout.splitlines() if ln.strip()]
    # Ignore artifacts under pytest's temp naming if present
    dirty = [d for d in dirty if "/tmp" not in d and "\\tmp" not in d]
    if dirty:
        print("Tests modified the working tree:", *dirty, sep="\n- ")
        sys.exit(1)
    print("Working tree is clean.")

if __name__ == "__main__":
    main()
