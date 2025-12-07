#!/usr/bin/env bash
# scripts/validate_notifications.sh
# Validates notification milestones (M0–M10) and emits JSONL for each check.
# Foundations for Milestone M0: structured telemetry + CI integration.
#
# Usage:
#   scripts/validate_notifications.sh [--milestone M<N>] [--jsonl-file <path>] [--help]
#
# Behavior:
# - Implements M0–M10 checks; filter with --milestone M0|M1|...|M10
# - Emits one JSON object per check: {timestamp, milestone, check, status, details}
# - Attempts all checks, then exits non-zero if any failed
# - Writes JSONL to console and to artifacts/notifications-validation.jsonl (default)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

[ -z "${NOTIFICATIONS_DRY_RUN:-}" ] && export NOTIFICATIONS_DRY_RUN=1

# Defaults (can be overridden via flag)
MILESTONE_FILTER=""
JSONL_FILE_DEFAULT="${REPO_ROOT}/artifacts/notifications-validation.jsonl"
JSONL_FILE="${JSONL_FILE_DEFAULT}"

print_usage() {
  cat <<'USAGE'
Notification Validation (M0 foundation)
Runs milestone validation checks and emits JSONL per check:
  Fields: timestamp, milestone, check, status, details

Environment variables:
  NOTIFICATIONS_DRY_RUN  Global dry-run toggle (defaults to 1 when unset)
  SLACK_WEBHOOK_URL      Slack notifier webhook URL
  DISCORD_WEBHOOK_URL    Discord notifier webhook URL
  ALERT_EMAIL            Comma-separated email recipients
  GITHUB_REPO            Repository in owner/name format
  GITHUB_ISSUE           Issue or pull request number
  ADMIN_TOKEN            Token for GitHub API (falls back to GITHUB_TOKEN)
See docs/notifications.md for detailed descriptions. For offline CI, set dummy values so
provider discovery proceeds without network access.

Options:
  --milestone M<N>   Run only a specific milestone (e.g. M0, M1, ... M10)
  --jsonl-file PATH  Override JSONL output file (default: artifacts/notifications-validation.jsonl)
  --help             Show this help

Examples:
  scripts/validate_notifications.sh
  scripts/validate_notifications.sh --milestone M0
  scripts/validate_notifications.sh --jsonl-file artifacts/my-validation.jsonl
USAGE
}

# Simple arg parsing
while [ $# -gt 0 ]; do
  case "$1" in
    --milestone)
      shift
      MILESTONE_FILTER="${1:-}"; shift || true
      ;;
    --jsonl-file)
      shift
      JSONL_FILE="${1:-}"; shift || true
      ;;
    --help|-h)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 2
      ;;
esac
done
FAILURE_COUNT=0

mark_fail() {
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

timestamp_iso() {
  # ISO8601 UTC, e.g., 2025-08-27T19:25:00Z
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

emit_json() {
  # emit_json "<milestone>" "<check>" "<status>" "<details>"
  # Uses python3 for proper JSON escaping.
  local milestone="$1"; shift
  local check="$1"; shift
  local status="$1"; shift
  local details="$1"; shift || true
  local ts
  ts="$(timestamp_iso)"

  python3 - "$ts" "$milestone" "$check" "$status" "$details" <<'PY'
import json, sys
timestamp, milestone, check, status, details = sys.argv[1:6]
obj = {
  "timestamp": timestamp,
  "milestone": milestone,
  "check": check,
  "status": status,
  "details": details,
}
print(json.dumps(obj, ensure_ascii=False))
PY
}

record_check() {
  local milestone="$1" check="$2" status="$3" details="$4"
  mkdir -p "$(dirname "$JSONL_FILE")"
  local line
  line="$(emit_json "$milestone" "$check" "$status" "$details")"
  echo "$line"
  printf '%s\n' "$line" >> "$JSONL_FILE"
  if [ "$status" = "fail" ]; then
    mark_fail
  fi
}

should_run() {
  local m="$1"
  [[ -z "$MILESTONE_FILTER" || "$MILESTONE_FILTER" = "$m" ]]
}

validate_filter() {
  if [ -n "$MILESTONE_FILTER" ]; then
    case "$MILESTONE_FILTER" in
      M0|M1|M2|M3|M4|M5|M6|M7|M8|M9|M10) ;;
      *)
        echo "Unknown milestone filter: ${MILESTONE_FILTER}" >&2
        exit 2
        ;;
    esac
  fi
}

# --- M0 basic checks (always pass) ---
check_m0_bootstrap() {
  record_check "M0" "M0.Bootstrap" "pass" "Validation script bootstrap OK"
}

check_m0_artifact_path() {
  record_check "M0" "M0.ArtifactPath" "pass" "JSONL file: ${JSONL_FILE}"
}

check_m0_fail_simulator() {
  if [ "${VALIDATION_FORCE_FAIL:-0}" = "1" ]; then
    record_check "M0" "M0.FailSimulator" "fail" "Forced failure for validation (VALIDATION_FORCE_FAIL=1)"
  else
    record_check "M0" "M0.FailSimulator" "skip" "Set VALIDATION_FORCE_FAIL=1 to simulate a failure"
  fi
}

run_m0() {
  check_m0_bootstrap
  check_m0_artifact_path
  check_m0_fail_simulator
}
# --- Milestone M1: interface + manager skeleton ---
validate_m1_step1() {
  if python3 - <<'PY'
import importlib, sys

try:
    importlib.import_module('notifications.channel')
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    record_check "M1" "M1.1.interface_exists" "pass" "notifications/channel.py loadable"
  else
    record_check "M1" "M1.1.interface_exists" "fail" "notifications/channel.py loadable"
  fi

  if python3 - <<'PY'
import importlib, sys

try:
    importlib.import_module('notifications.manager')
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    record_check "M1" "M1.1.manager_exists" "pass" "notifications/manager.py loadable"
  else
    record_check "M1" "M1.1.manager_exists" "fail" "notifications/manager.py loadable"
  fi

  if python3 - <<'PY'
from notifications.manager import NotificationManager
import sys

mgr = NotificationManager.from_env()
sys.exit(0 if len(getattr(mgr, '_providers', [])) == 0 else 1)
PY
  then
    record_check "M1" "M1.1.manager_empty" "pass" "from_env returns 0 providers"
  else
    record_check "M1" "M1.1.manager_empty" "fail" "from_env returns 0 providers"
  fi
}

validate_m1_step2() {
  # Check Slack notifier module presence
  if python3 - <<'PY'
import importlib, sys

try:
    importlib.import_module('notifications.slack_notifier')
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    record_check "M1" "M1.2.slack_module_present" "pass" "notifications/slack_notifier.py loadable"
  else
    record_check "M1" "M1.2.slack_module_present" "fail" "notifications/slack_notifier.py loadable"
  fi

  # Ensure NotificationManager discovers Slack when env var set
  if SLACK_WEBHOOK_URL='https://example.com/webhook' python3 - <<'PY'
from notifications.manager import NotificationManager
from notifications.slack_notifier import SlackNotifier
import sys

mgr = NotificationManager.from_env()
providers = getattr(mgr, '_providers', [])
sys.exit(0 if providers and isinstance(providers[0], SlackNotifier) else 1)
PY
  then
    record_check "M1" "M1.2.manager_discovers_slack" "pass" "from_env discovers SlackNotifier"
  else
    record_check "M1" "M1.2.manager_discovers_slack" "fail" "from_env discovers SlackNotifier"
  fi

  # Simulate Slack send to avoid real network
  # Ensure global dry-run flag doesn't suppress payload capture
  if env -u NOTIFICATIONS_DRY_RUN VALIDATION_DRY_RUN=1 python3 - <<'PY'
import json, sys, urllib.request

captured = {}

class DummyResponse:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def fake_urlopen(req, timeout=0):
    captured['data'] = req.data
    return DummyResponse()


urllib.request.urlopen = fake_urlopen

from notifications.slack_notifier import SlackNotifier

notifier = SlackNotifier(webhook_url="http://localhost:9")
ok = notifier.send_alert("hello")
expected = json.dumps({"text": "hello"}).encode()
sys.exit(0 if ok and captured.get('data') == expected else 1)
PY
  then
    record_check "M1" "M1.2.slack_send_simulated" "pass" "payload {'text': 'hello'} captured"
  else
    record_check "M1" "M1.2.slack_send_simulated" "fail" "payload {'text': 'hello'} captured"
  fi
}

validate_m1_step3() {
  # M1.3.no_direct_slack_posts
  local hits
  hits=$(rg "hooks\\.slack\\.com/services" -l "$REPO_ROOT" --glob '!notifications/**' || true)
  if [ -z "$hits" ]; then
    record_check "M1" "M1.3.no_direct_slack_posts" "pass" "no direct slack webhook posts outside notifications/"
  else
    record_check "M1" "M1.3.no_direct_slack_posts" "fail" "$hits"
  fi

  # M1.3.manager_used_in_call_sites
  if details=$(PYTHONPATH="$REPO_ROOT/scripts" python3 - <<'PY'
import inspect, importlib, sys
modules = ['render_telemetry_dashboard', 'render_qa_telemetry_dashboard']
missing = []
for name in modules:
    try:
        mod = importlib.import_module(name)
        src = inspect.getsource(mod)
        if 'NotificationManager' not in src:
            missing.append(f"{name} missing NotificationManager")
    except Exception as e:
        missing.append(f"{name} import failed: {e}")
if missing:
    print('; '.join(missing))
    sys.exit(1)
PY
  ); then
    record_check "M1" "M1.3.manager_used_in_call_sites" "pass" "NotificationManager referenced in call sites"
  else
    record_check "M1" "M1.3.manager_used_in_call_sites" "fail" "$details"
  fi

  # M1.3.behavior_parity_stub
  if SLACK_WEBHOOK_URL='https://example.com/webhook' VALIDATION_DRY_RUN=1 python3 - <<'PY'
import urllib.request
from notifications.manager import NotificationManager

class DummyResponse:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def fake_urlopen(req, timeout=0):
    return DummyResponse()


urllib.request.urlopen = fake_urlopen

mgr = NotificationManager.from_env()
mgr.notify_all("validation dry run")
PY
  then
    record_check "M1" "M1.3.behavior_parity_stub" "pass" "notify_all executed without error"
  else
    record_check "M1" "M1.3.behavior_parity_stub" "fail" "notify_all raised exception"
  fi
}

run_m1() { validate_m1_step1; validate_m1_step2; validate_m1_step3; }
validate_m2() {
  if [ -n "${ALERT_EMAIL:-}" ]; then
    record_check "M2" "M2.1.email_config_present" "pass" "ALERT_EMAIL set"
  else
    record_check "M2" "M2.1.email_config_present" "skip" "ALERT_EMAIL not set"
  fi

  if DASHBOARD_URL="https://example.com/dashboard" ALERT_EMAIL="dev@example.com" SMTP_SSL="false" SMTP_STARTTLS="false" NOTIFICATIONS_DRY_RUN="1" python3 - <<'PY'
from notifications.email_notifier import EmailNotifier
import os
notifier = EmailNotifier()
ok = notifier.send_alert("hello", {"dashboard_url": os.getenv("DASHBOARD_URL")})
mime = notifier._last_mime
assert ok and mime["Subject"] == "Telemetry Regression"
body = mime.get_payload(decode=True).decode()
assert "hello" in body and os.getenv("DASHBOARD_URL") in body
PY
  then
    record_check "M2" "M2.2.email_mime_compose" "pass" "subject/body composed"
  else
    record_check "M2" "M2.2.email_mime_compose" "fail" "MIME composition failed"
  fi

  if ALERT_EMAIL="dev@example.com" NOTIFICATIONS_DRY_RUN="1" SMTP_SSL="false" SMTP_STARTTLS="false" python3 - <<'PY'
import smtplib
class BoomSMTP:
    def __init__(self, *a, **k):
        raise AssertionError('SMTP should not be used in dry-run')
smtplib.SMTP = BoomSMTP
smtplib.SMTP_SSL = BoomSMTP
from notifications.email_notifier import EmailNotifier
assert EmailNotifier().send_alert('test')
PY
  then
    record_check "M2" "M2.3.email_dry_run_send" "pass" "dry-run"
  else
    record_check "M2" "M2.3.email_dry_run_send" "fail" "network attempted"
  fi

  if details=$(ALERT_EMAIL="dev@example.com" NOTIFICATIONS_DRY_RUN="0" SMTP_SSL="false" SMTP_STARTTLS="false" python3 - <<'PY'
from notifications.email_notifier import EmailNotifier
n = EmailNotifier()
if n.use_ssl and n.use_starttls:
    raise SystemExit('both TLS modes enabled')
print(f"host={n.host}:{n.port} starttls={n.use_starttls} ssl={n.use_ssl}")
PY
  ); then
    record_check "M2" "M2.4.email_real_send_preflight" "pass" "$details"
  else
    record_check "M2" "M2.4.email_real_send_preflight" "fail" "$details"
  fi

  if ALERT_EMAIL="dev@example.com" NOTIFICATIONS_DRY_RUN="0" SMTP_SSL="true" SMTP_STARTTLS="true" python3 - <<'PY'
from notifications.email_notifier import EmailNotifier
n = EmailNotifier()
assert n.send_alert('x') is False
PY
  then
    record_check "M2" "M2.5.email_misconfig_handling" "pass" "expected failure observed"
  else
    record_check "M2" "M2.5.email_misconfig_handling" "fail" "misconfig not detected"
  fi

  if ALERT_EMAIL="dev@example.com" NOTIFICATIONS_DRY_RUN="0" SMTP_USERNAME="user" SMTP_PASSWORD="pass" SMTP_SSL="false" SMTP_STARTTLS="false" python3 - <<'PY'
import smtplib
from notifications.email_notifier import EmailNotifier

class AuthFailSMTP:
    def __init__(self, host, port, timeout):
        pass
    def __enter__(self):
        return self
    def __exit__(self, exc_type, exc, tb):
        pass
    def login(self, *a, **k):
        raise smtplib.SMTPAuthenticationError(535, b'auth failed')
    def sendmail(self, *a, **k):
        pass

smtplib.SMTP = AuthFailSMTP
n = EmailNotifier()
assert n.send_alert('hi') is False
PY
  then
    record_check "M2" "M2.6.email_auth_failure_handling" "pass" "auth failure handled"
  else
    record_check "M2" "M2.6.email_auth_failure_handling" "fail" "auth failure not handled"
  fi

  if python3 - <<'PY'
import json, os, sys
from pathlib import Path

sys.path.insert(0, 'scripts')
import render_telemetry_dashboard as rtd
from notifications.email_notifier import EmailNotifier
from notifications.manager import NotificationManager

class StubEmail(EmailNotifier):
    def __init__(self):
        pass

    def send_alert(self, message, metadata=None):
        StubEmail.called = (message, metadata)
        return True

StubEmail.called = None

NotificationManager.from_env = classmethod(lambda cls: NotificationManager([StubEmail()]))

tmp = Path('artifacts/m2_7_history.jsonl')
tmp.parent.mkdir(parents=True, exist_ok=True)
tmp.write_text(
    json.dumps({'timestamp': '1', 'slow_test_count': 1, 'dependency_failures': {}}) + '\n'
    + json.dumps({'timestamp': '2', 'slow_test_count': 2, 'dependency_failures': {}}) + '\n',
    encoding='utf-8'
)
exit_code = rtd.main([str(tmp)])
expected = {'dashboard_url': tmp.with_name('telemetry-dashboard.html').name}
assert exit_code == 1 and StubEmail.called[1] == expected
PY
  then
    record_check "M2" "M2.7.telemetry_integration" "pass" "dispatcher invoked Email on regression (simulated)"
  else
    record_check "M2" "M2.7.telemetry_integration" "fail" "dispatcher failed to invoke Email"
  fi
}

run_m2() { validate_m2; }
# --- Milestone M3: GitHub notifier ---
validate_m3() {
  if python3 - <<'PY'
import importlib, sys
try:
    importlib.import_module('notifications.github_notifier')
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    record_check "M3" "M3.1.github_module_present" "pass" "notifications/github_notifier.py loadable"
  else
    record_check "M3" "M3.1.github_module_present" "fail" "notifications/github_notifier.py loadable"
  fi

  if GITHUB_REPO="octo/repo" GITHUB_ISSUE="5" ADMIN_TOKEN="fake" python3 - <<'PY'
from notifications.manager import NotificationManager
from notifications.github_notifier import GitHubNotifier
import sys
mgr = NotificationManager.from_env()
providers = getattr(mgr, '_providers', [])
ok = any(isinstance(p, GitHubNotifier) and p.repo == "octo/repo" and p.issue == 5 for p in providers)
sys.exit(0 if ok else 1)
PY
  then
    record_check "M3" "M3.2.manager_discovers_github" "pass" "GitHubNotifier discovered"
  else
    record_check "M3" "M3.2.manager_discovers_github" "fail" "GitHubNotifier not discovered"
  fi

  # Force real send to exercise GitHub notifier even when global dry-run is set
  if NOTIFICATIONS_DRY_RUN=0 ADMIN_TOKEN="fake" python3 - <<'PY'
import json, urllib.request, sys
from notifications.github_notifier import GitHubNotifier

captured = {}
class DummyResponse:
    def __enter__(self): return self
    def __exit__(self, *exc): return False
    def read(self): return b""
    def getcode(self): return 201

def fake_urlopen(req, timeout=0):
    captured["url"] = req.full_url
    captured["headers"] = dict(req.headers)
    captured["data"] = req.data
    captured["timeout"] = timeout
    return DummyResponse()

urllib.request.urlopen = fake_urlopen

n = GitHubNotifier(repo="octo/repo", issue=5)
ok = n.send_alert("hello")
expected_url = "https://api.github.com/repos/octo/repo/issues/5/comments"
payload_ok = json.loads(captured.get("data", b"{}" ).decode()) == {"body": "hello"}
auth_ok = captured.get("headers", {}).get("Authorization") == "token fake"
url_ok = captured.get("url") == expected_url
timeout_ok = captured.get("timeout") == 5
sys.exit(0 if ok and payload_ok and auth_ok and url_ok and timeout_ok else 1)
PY
  then
    record_check "M3" "M3.3.github_send_simulated" "pass" "payload posted successfully"
  else
    record_check "M3" "M3.3.github_send_simulated" "fail" "payload post failed"
  fi
}

run_m3() { validate_m3; }
validate_m4() {
  if NOTIFICATIONS_DRY_RUN=1 python3 - <<'PY'
from notifications.slack_notifier import SlackNotifier
n = SlackNotifier(webhook_url="http://localhost")
ok = n.send_alert("test")
assert ok and getattr(n, "_last_payload", None) == {"text": "test"}
PY
  then
    record_check "M4" "M4.1.slack_dry_run" "pass" "payload captured"
  else
    record_check "M4" "M4.1.slack_dry_run" "fail" "dry-run failed"
  fi

    if ALERT_EMAIL="dev@example.com" ENABLE_EMAIL_LIVE="1" NOTIFICATIONS_DRY_RUN="1" SMTP_SSL="false" SMTP_STARTTLS="false" python3 - <<'PY'
import smtplib
from notifications.email_notifier import EmailNotifier

called = {}

class RecorderSMTP:
    def __init__(self, *a, **k):
        called["yes"] = True
    def __enter__(self):
        return self
    def __exit__(self, *a):
        pass
    def sendmail(self, *a, **k):
        pass

smtplib.SMTP = RecorderSMTP
n = EmailNotifier()
ok = n.send_alert("override")
assert ok and called.get("yes")
PY
    then
      record_check "M4" "M4.2.email_live_override" "pass" "override allowed"
    else
      record_check "M4" "M4.2.email_live_override" "fail" "override blocked"
    fi

  if NOTIFICATIONS_DRY_RUN=1 python3 - <<'PY'
from notifications.github_notifier import GitHubNotifier
n = GitHubNotifier(repo="org/repo", issue=1, token="t0k")
ok = n.send_alert("hello")
assert ok and getattr(n, "_last_payload", None) == {"body": "hello"}
PY
  then
    record_check "M4" "M4.3.github_dry_run" "pass" "payload captured"
  else
    record_check "M4" "M4.3.github_dry_run" "fail" "dry-run failed"
  fi
}

run_m4() { validate_m4; }

validate_m5() {
  local out
  if out=$(python3 - <<'PY' 2>&1
import time
from notifications.manager import NotificationManager

class DummyA:
    def send_alert(self, message, metadata=None):
        time.sleep(1)
        return True

class DummyB:
    def send_alert(self, message, metadata=None):
        time.sleep(1)
        return True

start = time.perf_counter()
mgr = NotificationManager([DummyA(), DummyB()])
results = mgr.notify_all("test")
elapsed = time.perf_counter() - start
assert results == {"DummyA": True, "DummyB": True}, results
assert elapsed < 1.5, f"elapsed {elapsed:.2f}s"
print(f"{elapsed:.2f}")
PY
  ); then
    record_check "M5" "M5.1.concurrent_dispatch" "pass" "elapsed ${out}s"
  else
    record_check "M5" "M5.1.concurrent_dispatch" "fail" "$out"
  fi
}

run_m5() { validate_m5; }
# --- Milestone M6: retry logic for network notifiers ---
validate_m6() {
  local out
  # Disable dry-run so retry paths execute network logic
  if out=$(NOTIFICATIONS_DRY_RUN=0 python3 - <<'PY' 2>&1
import urllib.request, time
from notifications.slack_notifier import SlackNotifier

calls = {"count": 0}

class DummyResponse:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

def fake_urlopen(req, timeout=0):
    calls["count"] += 1
    if calls["count"] == 1:
        raise OSError("boom")
    return DummyResponse()

urllib.request.urlopen = fake_urlopen
time.sleep = lambda s: None
n = SlackNotifier(webhook_url="http://localhost")
ok = n.send_alert("x")
assert ok and calls["count"] == 2, (ok, calls["count"])
PY
  ); then
    record_check "M6" "M6.1.slack_retry_success" "pass" "urlopen called twice"
  else
    record_check "M6" "M6.1.slack_retry_success" "fail" "$out"
  fi

  # Dry-run would swallow errors; clear it to verify error logging
  if out=$(NOTIFICATIONS_DRY_RUN=0 python3 - <<'PY' 2>&1
import urllib.request, time
from notifications.github_notifier import GitHubNotifier

calls = {"count": 0}

class DummyResponse:
    def __init__(self, code):
        self.code = code

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return b""

    def getcode(self):
        return self.code

def fake_urlopen(req, timeout=0):
    calls["count"] += 1
    if calls["count"] == 1:
        return DummyResponse(500)
    return DummyResponse(201)

urllib.request.urlopen = fake_urlopen
time.sleep = lambda s: None
n = GitHubNotifier(repo="foo/bar", issue=1, token="t")
ok = n.send_alert("retry")
assert ok and calls["count"] == 2, (ok, calls["count"])
PY
  ); then
    record_check "M6" "M6.2.github_retry_success" "pass" "urlopen called twice"
  else
    record_check "M6" "M6.2.github_retry_success" "fail" "$out"
  fi
}

run_m6() { validate_m6; }
# --- Stubs for future milestones: emit 'skip' line so telemetry is structured from day one ---
validate_m7() {
  local out
  if out=$(python3 - <<'PY' 2>&1
import os
from notifications.slack_notifier import SlackNotifier

os.environ["NOTIFICATIONS_DRY_RUN"] = "true"
n = SlackNotifier(webhook_url="http://localhost")
n.send_alert("Build failed", {"dashboard_url": "http://example.com/dash"})
text = n._last_payload.get("text", "")
assert "Build failed" in text and "Dashboard: http://example.com/dash" in text, text
PY
  ); then
    record_check "M7" "M7.1.slack_includes_link" "pass" "payload includes link"
  else
    record_check "M7" "M7.1.slack_includes_link" "fail" "$out"
  fi

  if out=$(python3 - <<'PY' 2>&1
import os
from notifications.github_notifier import GitHubNotifier

os.environ["NOTIFICATIONS_DRY_RUN"] = "true"
n = GitHubNotifier(repo="x/y", issue=1, token="t")
n.send_alert("Alert", {"dashboard_url": "http://example.com/dash"})
body = n._last_payload.get("body", "")
assert "Alert" in body and "Dashboard: http://example.com/dash" in body, body
PY
  ); then
    record_check "M7" "M7.2.github_includes_link" "pass" "payload includes link"
  else
    record_check "M7" "M7.2.github_includes_link" "fail" "$out"
  fi
}

run_m7() { validate_m7; }

validate_m8() {
  local out
  if out=$(python3 - <<'PY' 2>&1
from notifications.manager import NotificationManager

class Good:
    def send_alert(self, message, metadata=None):
        return True

class Bad:
    def send_alert(self, message, metadata=None):
        raise RuntimeError("boom")

mgr = NotificationManager([Good(), Bad()])
res = mgr.notify_all("hi")
assert res == {"Good": True, "Bad": False}, res
PY
  ); then
    record_check "M8" "M8.failure_isolated" "pass" "failure isolated per provider"
  else
    record_check "M8" "M8.failure_isolated" "fail" "$out"
  fi
}

run_m8() { validate_m8; }

validate_m9() {
  local out
  # Dry-run would skip network errors; disable it to verify logging
  if out=$(NOTIFICATIONS_DRY_RUN=0 python3 - <<'PY' 2>&1
import io, sys, urllib.request
from contextlib import redirect_stderr
from notifications.slack_notifier import SlackNotifier

def boom(req, timeout=0):
    raise Exception("Boom")

urllib.request.urlopen = boom
buf = io.StringIO()
with redirect_stderr(buf):
    ok = SlackNotifier(webhook_url="http://localhost").send_alert("X")
err = buf.getvalue()
assert ok is False and "SlackNotifier:" in err and "Boom" in err, (ok, err)
PY
  ); then
    record_check "M9" "M9.1.slack_error_logged" "pass" "error logged"
  else
    record_check "M9" "M9.1.slack_error_logged" "fail" "$out"
  fi

  if out=$(NOTIFICATIONS_DRY_RUN=0 python3 - <<'PY' 2>&1
import io, sys, urllib.request, urllib.error
from contextlib import redirect_stderr
from notifications.github_notifier import GitHubNotifier

def boom(req, timeout=0):
    raise urllib.error.HTTPError(req.full_url, 500, "Boom", {}, None)

urllib.request.urlopen = boom
buf = io.StringIO()
with redirect_stderr(buf):
    ok = GitHubNotifier(repo="foo/bar", issue=99, token="t").send_alert("Y")
err = buf.getvalue()
assert ok is False and "GitHubNotifier" in err and "500" in err, (ok, err)
PY
  ); then
    record_check "M9" "M9.2.github_error_logged" "pass" "error logged"
  else
    record_check "M9" "M9.2.github_error_logged" "fail" "$out"
  fi
}

run_m9() { validate_m9; }

validate_m10() {
  if python3 - <<'PY'
import importlib, sys
try:
    importlib.import_module('notifications.discord_notifier')
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
  then
    record_check "M10" "M10.1.module_present" "pass" "notifications/discord_notifier.py loadable"
  else
    record_check "M10" "M10.1.module_present" "fail" "notifications/discord_notifier.py loadable"
  fi

  if NOTIFICATIONS_DRY_RUN=1 DISCORD_WEBHOOK_URL=dummy python3 - <<'PY'
from notifications.discord_notifier import DiscordNotifier
n = DiscordNotifier()
ok = n.send_alert("hello", {"dashboard_url": "http://x"})
payload = getattr(n, '_last_payload', {})
content = payload.get('content', '') if payload else ''
import sys
sys.exit(0 if ok and "hello" in content and "Dashboard: http://x" in content else 1)
PY
  then
    record_check "M10" "M10.2.dry_run_payload" "pass" "payload content includes message and dashboard"
  else
    record_check "M10" "M10.2.dry_run_payload" "fail" "payload content missing data"
  fi

  if out=$(DISCORD_WEBHOOK_URL=dummy python3 - <<'PY' 2>&1
from notifications.manager import NotificationManager
from notifications.discord_notifier import DiscordNotifier
mgr = NotificationManager.from_env()
providers = mgr._providers
import sys
sys.exit(0 if any(isinstance(p, DiscordNotifier) for p in providers) else 1)
PY
  ); then
    record_check "M10" "M10.3.manager_discovers" "pass" "DiscordNotifier discovered"
  else
    record_check "M10" "M10.3.manager_discovers" "fail" "$out"
  fi

  if out=$(ENABLE_DISCORD_LIVE=1 DISCORD_WEBHOOK_URL=https://example.com/webhook python3 - <<'PY' 2>&1
import json, urllib.request
from notifications.discord_notifier import DiscordNotifier

captured = {}
class DummyResponse:
    def __enter__(self):
        return self
    def __exit__(self, exc_type, exc, tb):
        return False

def fake_urlopen(req, timeout=0):
    captured["url"] = req.full_url
    captured["data"] = req.data
    captured["headers"] = {k.lower(): v for k, v in req.headers.items()}
    captured["timeout"] = timeout
    return DummyResponse()

urllib.request.urlopen = fake_urlopen
ok = DiscordNotifier().send_alert("hello")
assert ok is True
assert captured["url"] == "https://example.com/webhook"
assert json.loads(captured["data"].decode()) == {"content": "hello"}
assert captured["headers"]["content-type"] == "application/json"
assert captured["timeout"] == 5
PY
  ); then
    record_check "M10" "M10.4.post_shapes_payload" "pass" "payload sent"
  else
    record_check "M10" "M10.4.post_shapes_payload" "fail" "$out"
  fi

  if NOTIFICATIONS_DRY_RUN=1 DISCORD_WEBHOOK_URL=dummy python3 - <<'PY'
from notifications.discord_notifier import DiscordNotifier
n = DiscordNotifier()
n.send_alert("hi", {"dashboard_url": "http://x"})
payload = getattr(n, '_last_payload', {})
content = payload.get('content', '') if payload else ''
import sys
sys.exit(0 if "Dashboard: http://" in content else 1)
PY
  then
    record_check "M10" "M10.5.includes_dashboard_link" "pass" "dashboard link appended"
  else
    record_check "M10" "M10.5.includes_dashboard_link" "fail" "dashboard link missing"
  fi

  if out=$(ENABLE_DISCORD_LIVE=1 DISCORD_WEBHOOK_URL=https://example.com/webhook python3 - <<'PY' 2>&1
import urllib.request
from notifications.discord_notifier import DiscordNotifier

attempts = {"count": 0}

class DummyResponse:
    def __enter__(self):
        return self
    def __exit__(self, exc_type, exc, tb):
        return False

def fake_urlopen(req, timeout=0):
    attempts["count"] += 1
    if attempts["count"] == 1:
        raise RuntimeError("boom")
    return DummyResponse()

urllib.request.urlopen = fake_urlopen
ok = DiscordNotifier().send_alert("hi")
import sys
sys.exit(0 if ok and attempts["count"] == 2 else 1)
PY
  ); then
    record_check "M10" "M10.6.retry_success" "pass" "retry succeeded"
  else
    record_check "M10" "M10.6.retry_success" "fail" "$out"
  fi

  if out=$(ENABLE_DISCORD_LIVE=1 DISCORD_WEBHOOK_URL=https://example.com/webhook python3 - <<'PY' 2>&1
import io, urllib.request
from contextlib import redirect_stderr
from notifications.discord_notifier import DiscordNotifier

def fake_urlopen(req, timeout=0):
    raise RuntimeError("boom")

urllib.request.urlopen = fake_urlopen

buf = io.StringIO()
with redirect_stderr(buf):
    ok = DiscordNotifier().send_alert("hi")
stderr = buf.getvalue()
import sys
sys.exit(0 if (not ok) and ("DiscordNotifier:" in stderr) else 1)
PY
  ); then
    record_check "M10" "M10.7.error_logged" "pass" "error logged"
  else
    record_check "M10" "M10.7.error_logged" "fail" "$out"
  fi

  if out=$(python3 - <<'PY' 2>&1
import json, os, runpy, tempfile
from notifications.manager import NotificationManager
from notifications.discord_notifier import DiscordNotifier

with tempfile.NamedTemporaryFile('w+', delete=False) as f:
    f.write('{"timestamp":"t1","slow_test_count":0,"dependency_failures":{}}\n')
    f.write('{"timestamp":"t2","slow_test_count":1,"dependency_failures":{}}\n')
    path = f.name

os.environ.pop("DISCORD_WEBHOOK_URL", None)
os.environ["NOTIFICATIONS_DRY_RUN"] = "1"
sys_argv = ["render_telemetry_dashboard.py", path, "--discord-webhook", "dummy"]
import sys
sys.argv = sys_argv
ret = 0
try:
    runpy.run_path("scripts/render_telemetry_dashboard.py", run_name="__main__")
except SystemExit as e:
    ret = int(e.code or 0)
mgr = NotificationManager.from_env()
providers = mgr._providers
sys.exit(0 if ret == 1 and os.getenv("DISCORD_WEBHOOK_URL") == "dummy" and any(isinstance(p, DiscordNotifier) for p in providers) else 1)
PY
  ); then
    record_check "M10" "M10.8.cli_sets_env" "pass" "CLI flag wires env"
  else
    record_check "M10" "M10.8.cli_sets_env" "fail" "$out"
  fi
  if out=$(SLACK_WEBHOOK_URL=dummy DISCORD_WEBHOOK_URL=dummy ALERT_EMAIL=test@example.com GITHUB_REPO=octo/repo GITHUB_ISSUE=1 ADMIN_TOKEN=tok NOTIFICATIONS_DRY_RUN=1 python3 - <<'PY' 2>&1
from notifications.manager import NotificationManager
from notifications.slack_notifier import SlackNotifier
from notifications.discord_notifier import DiscordNotifier
from notifications.email_notifier import EmailNotifier
from notifications.github_notifier import GitHubNotifier
from notifications.utils import provider_name

mgr = NotificationManager.from_env()
providers = {provider_name(p) for p in mgr._providers}
expected = {'slack','discord','email','github'}
import sys
sys.exit(0 if expected.issubset(providers) else 1)
PY
  ); then
    record_check "M10" "M10.9.coexistence" "pass" "all providers discovered"
  else
    record_check "M10" "M10.9.coexistence" "fail" "$out"
  fi

  if out=$(NOTIFICATIONS_DRY_RUN=1 DISCORD_WEBHOOK_URL=dummy python3 - <<'PY' 2>&1
from notifications.manager import NotificationManager
from notifications.utils import provider_name

mgr = NotificationManager.from_env()
providers = {provider_name(p) for p in mgr._providers}
results = mgr.notify_all("Simulated regression", {"dashboard_url": "http://example"})
import sys
sys.exit(0 if ("discord" in providers and results.get("discord")) else 1)
PY
  ); then
    record_check "M10" "M10.11.e2e_dry_run" "pass" "dry-run e2e dispatched to Discord"
  else
    record_check "M10" "M10.11.e2e_dry_run" "fail" "$out"
  fi
}

run_m10() {
  validate_m10
}

main() {
  validate_filter
  should_run M0 && run_m0
  should_run M1 && run_m1
  should_run M2 && run_m2
  should_run M3 && run_m3
  should_run M4 && run_m4
  should_run M5 && run_m5
  should_run M6 && run_m6
  should_run M7 && run_m7
  should_run M8 && run_m8
  should_run M9 && run_m9
  should_run M10 && run_m10
  if [ "$FAILURE_COUNT" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

# entry
main "$@"
