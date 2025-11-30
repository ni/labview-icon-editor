#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict

import requests

AUTH_DEVICE_URL = "https://github.com/login/device/code"
AUTH_TOKEN_URL = "https://github.com/login/oauth/access_token"


def post(url: str, data: Dict[str, Any]) -> Dict[str, Any]:
    r = requests.post(url, headers={"Accept": "application/json"}, data=data, timeout=20)
    r.raise_for_status()
    return r.json()


def device_flow(client_id: str, scope: str, interval: int | None = None, timeout_sec: int = 600) -> str:
    js = post(AUTH_DEVICE_URL, {"client_id": client_id, "scope": scope})
    device_code = js["device_code"]
    user_code = js["user_code"]
    verification_uri = js["verification_uri"]
    interval = interval or int(js.get("interval", 5))
    print(f"1) Open: {verification_uri}")
    print(f"2) Enter code: {user_code}")
    print("Waiting for authorization...")
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        time.sleep(interval)
        resp = post(
            AUTH_TOKEN_URL,
            {
                "client_id": client_id,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            },
        )
        if "access_token" in resp:
            return resp["access_token"]
        err = resp.get("error")
        if err in ("authorization_pending", "slow_down"):
            if err == "slow_down":
                interval += 2
            continue
        raise SystemExit(f"Authorization error: {err} ({resp.get('error_description','')})")
    raise SystemExit("Authorization timed out.")


def write_token(token: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # If writing under .secrets, ensure .gitignore exists to avoid accidental commits
    try:
        secrets_dir = path.parent
        if secrets_dir.name == ".secrets":
            gi = secrets_dir / ".gitignore"
            if not gi.exists():
                gi.write_text("*\n!.gitignore\n!README.md\n", encoding="utf-8")
    except Exception:
        pass
    path.write_text(token.strip() + "\n", encoding="utf-8")
    try:
        # best-effort: restrict perms on POSIX
        os.chmod(path, 0o600)
    except Exception:
        pass


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="GitHub OAuth Device Flow - get a personal user token for the assistant.")
    ap.add_argument("--client-id", required=True, help="GitHub App (user OAuth) Client ID or OAuth App Client ID")
    ap.add_argument(
        "--scope",
        default="repo",
        help="OAuth scopes (default: repo). Add 'workflow' if you want to dispatch workflows.",
    )
    ap.add_argument(
        "--out",
        default=str(Path(".secrets/github_user_token.txt")),
        help="Path to write the user token (default: .secrets/github_user_token.txt)",
    )
    ap.add_argument(
        "--no-keyring",
        action="store_true",
        help="Do not attempt to store the token in the OS keyring; write only to file",
    )
    args = ap.parse_args(argv)

    token = device_flow(args.client_id, args.scope)
    out = Path(args.out)
    # Store in keyring if available (best-effort), then file
    keyring_ok = False
    if not args.no_keyring:
        try:
            import keyring  # type: ignore

            keyring.set_password("x-cli", "github_user_token", token)
            keyring_ok = True
        except Exception:
            keyring_ok = False
    write_token(token, out)
    print(json.dumps({"ok": True, "token_file": str(out), "keyring": keyring_ok}))
    print("Tip: tools prefer GITHUB_USER_TOKEN, OS keyring, then .secrets/github_user_token.txt.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
