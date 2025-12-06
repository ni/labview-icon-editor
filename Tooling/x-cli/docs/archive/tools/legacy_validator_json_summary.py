#!/usr/bin/env python3
import sys, json
if len(sys.argv) < 2:
    print("usage: legacy_validator_json_summary.py <result.json>", file=sys.stderr); sys.exit(2)
data = json.load(open(sys.argv[1]))
overall = data.get("overallPassed", data.get("isValid", False))
ingested = data.get("ingested", False)
title = data.get("manifestTitle") or ""
version = data.get("manifestVersion") or ""
print(f"overallPassed: {overall}")
print(f"ingested: {ingested}")
print(f"title: {title}")
print(f"version: {version}")
if data.get("errors"):
    print("errors:")
    for e in data["errors"]:
        print(f" - {e}")
if data.get("warnings"):
    print("warnings:")
    for w in data["warnings"]:
        print(f" - {w}")
