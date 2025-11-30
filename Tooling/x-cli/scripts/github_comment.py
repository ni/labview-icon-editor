import argparse
import json
import os
import urllib.request
def post_github_comment(
    repo: str,
    issue: int,
    message: str,
    token: str | None = None,
    timeout: float = 5,
) -> None:
    """Post a comment to a GitHub issue or pull request."""
    tok = token or os.environ.get("ADMIN_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not tok:
        raise ValueError("GitHub token required")
    url = f"https://api.github.com/repos/{repo}/issues/{issue}/comments"
    data = json.dumps({"body": message}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"token {tok}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "x-cli-notifier",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        if resp.getcode() != 201:
            raise RuntimeError(f"GitHub API returned {resp.getcode()}")
        resp.read()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Post a comment to a GitHub issue or pull request",
    )
    parser.add_argument("repo", help="Repository in owner/name format")
    parser.add_argument("issue", type=int, help="Issue or pull request number")
    parser.add_argument("message", help="Comment body")
    parser.add_argument(
        "--token",
        help="GitHub token (default: env ADMIN_TOKEN or GITHUB_TOKEN)",
    )
    args = parser.parse_args(argv)
    post_github_comment(args.repo, args.issue, args.message, args.token)
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    raise SystemExit(main())

