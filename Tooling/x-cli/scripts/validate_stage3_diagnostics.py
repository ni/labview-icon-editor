#!/usr/bin/env python3
import argparse, json, sys, os

def err(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def warn(msg):
    print(f"WARN: {msg}", file=sys.stderr)

def main():
    ap = argparse.ArgumentParser(description="Validate Stage 3 diagnostics JSON without external deps")
    ap.add_argument("diagnostics", nargs="?", default="telemetry/stage3-diagnostics.json")
    ap.add_argument("--schema", default="docs/schemas/stage3-diagnostics.schema.json")
    ap.add_argument("--strict", action="store_true", help="fail if schema file missing or unvalidated")
    ap.add_argument("--allow-missing", action="store_true", help="exit 0 when diagnostics file is missing")
    args = ap.parse_args()

    if not os.path.exists(args.diagnostics):
        if args.allow_missing:
            print(f"Diagnostics JSON missing: {args.diagnostics}; skipping (allow-missing)")
            return 0
        err(f"Diagnostics JSON not found: {args.diagnostics}")

    try:
        with open(args.diagnostics, "r", encoding="utf-8") as f:
            diag = json.load(f)
    except Exception as e:
        err(f"Invalid JSON: {args.diagnostics}: {e}")

    required = [
        "published","dry_run_forced","webhook_present",
        "summary_path","comment_path","summary_bytes","comment_bytes","chunks"
    ]
    for k in required:
        if k not in diag:
            err(f"Missing required key: {k}")

    if diag["published"] not in ("true","false"):
        err("published must be 'true' or 'false'")
    if diag["dry_run_forced"] not in ("true","false"):
        err("dry_run_forced must be 'true' or 'false'")
    if diag["webhook_present"] not in ("true","false"):
        err("webhook_present must be 'true' or 'false'")
    for key in ("summary_bytes","comment_bytes"):
        v = diag[key]
        if not isinstance(v, int) or v < 0:
            err(f"{key} must be integer >= 0")

    # Optional: schema validation if jsonschema present and file exists
    if os.path.exists(args.schema):
        try:
            import jsonschema  # type: ignore
            with open(args.schema, "r", encoding="utf-8") as sf:
                schema = json.load(sf)
            jsonschema.validate(instance=diag, schema=schema)
        except ModuleNotFoundError:
            warn("jsonschema not installed; skipping schema validation")
            if args.strict:
                err("--strict requested but jsonschema not installed")
        except Exception as e:
            err(f"JSON Schema validation failed: {e}")
    else:
        if args.strict:
            err(f"Schema file missing: {args.schema}")
        else:
            warn("Schema file missing; minimal validation completed")

    print(f"Diagnostics validation OK: {args.diagnostics}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
