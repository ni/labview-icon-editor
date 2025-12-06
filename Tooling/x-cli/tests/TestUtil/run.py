"""Utilities for running subprocesses in tests.

This module provides thin wrappers around :func:`subprocess.run` and
``subprocess.check_output`` that enforce a timeout, enable ``check=True`` and
capture ``stdout``/``stderr`` for easier debugging. When a command fails the
captured output is printed so the failing test shows useful context.
"""

from __future__ import annotations

import subprocess
import sys
import time
import traceback
from typing import Mapping, Sequence

import os

from codex_rules.telemetry import append_telemetry_entry


SENSITIVE_ENV_KEYS = ("SECRET", "TOKEN", "PASSWORD")


def _snapshot_env(env: Mapping[str, str] | None) -> dict[str, str]:
    """Return a filtered copy of *env* for telemetry."""

    source = dict(env) if env is not None else dict(os.environ)
    snap: dict[str, str] = {}
    for key, value in source.items():
        if any(token in key.upper() for token in SENSITIVE_ENV_KEYS):
            continue
        snap[key] = str(value)
    return snap


def run(
    args: Sequence[str] | str,
    *,
    cwd: str | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float | None = None,
    hang_threshold: float | None = None,
    **kwargs,
) -> subprocess.CompletedProcess[str]:
    """Run *args* with ``subprocess.run``.

    Parameters mirror :func:`subprocess.run` with the difference that
    ``check=True``, ``text=True`` and ``capture_output=True`` are enforced by
    default. A default ``timeout`` of 30 seconds is applied unless explicitly
    overridden.

    Returns the :class:`~subprocess.CompletedProcess` instance. On failure the
    command's stdout and stderr are printed before the original exception is
    re-raised.
    """

    kwargs.setdefault("check", True)
    kwargs.setdefault("text", True)
    kwargs.setdefault("capture_output", True)
    if timeout is None:
        timeout = 30

    start = time.perf_counter()
    # Windows bash shim: map known bash scripts to pwsh equivalents when WSL bash is unavailable
    if os.name == "nt" and isinstance(args, (list, tuple)) and len(args) >= 2 and str(args[0]).lower() == "bash":
        script = str(args[1]).replace("\\", "/")
        # Avoid WSL relay when Git Bash is missing by invoking PowerShell equivalents
        if script.endswith("/scripts/validate-manifest.sh"):
            man = args[2] if len(args) >= 3 else "telemetry/manifest.json"
            pwsh_args = [
                "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive",
                "-File", os.path.join(os.path.dirname(script), "validate-manifest.ps1"),
                "-Manifest", man,
            ]
            args = pwsh_args
        elif script.endswith("/scripts/generate-manifest.sh"):
            pwsh_args = [
                "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive",
                "-File", os.path.join(os.path.dirname(script), "generate-manifest.ps1"),
            ]
            args = pwsh_args
    try:
        result = subprocess.run(args, cwd=cwd, env=env, timeout=timeout, **kwargs)
    except subprocess.TimeoutExpired as exc:
        duration = time.perf_counter() - start
        append_telemetry_entry(
            {
                "modules_inspected": [],
                "checks_skipped": [],
                "event": "command_timeout",
                "timeout": timeout,
                "duration": duration,
                "stack_trace": "".join(traceback.format_stack()),
                "env_snapshot": _snapshot_env(env),
            },
            command=args,
            exception_type=exc.__class__.__name__,
            exception_message=str(exc),
        )
        if exc.stdout:
            print(exc.stdout, file=sys.stdout)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        raise
    except subprocess.CalledProcessError as exc:
        append_telemetry_entry(
            {
                "modules_inspected": [],
                "checks_skipped": [],
                "event": "command_failed",
                "stack_trace": "".join(traceback.format_stack()),
                "env_snapshot": _snapshot_env(env),
            },
            command=args,
            exit_status=exc.returncode,
            exception_type=exc.__class__.__name__,
            exception_message=str(exc),
        )
        if exc.stdout:
            print(exc.stdout, file=sys.stdout)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        raise
    except Exception as exc:  # pragma: no cover - unexpected errors
        duration = time.perf_counter() - start
        append_telemetry_entry(
            {
                "modules_inspected": [],
                "checks_skipped": [],
                "event": "command_error",
                "duration": duration,
                "stack_trace": "".join(traceback.format_stack()),
                "env_snapshot": _snapshot_env(env),
            },
            command=args,
            exception_type=exc.__class__.__name__,
            exception_message=str(exc),
        )
        raise

    duration = time.perf_counter() - start
    if hang_threshold is not None and duration > hang_threshold:
        append_telemetry_entry(
            {
                "modules_inspected": [],
                "checks_skipped": [],
                "event": "command_slow",
                "duration": duration,
                "threshold": hang_threshold,
                "stack_trace": "".join(traceback.format_stack()),
                "env_snapshot": _snapshot_env(env),
            },
            command=args,
            exit_status=result.returncode,
        )
    return result


def check_output(
    args: Sequence[str] | str,
    *,
    cwd: str | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float | None = None,
    **kwargs,
) -> str:
    """Return ``stdout`` from running *args*.

    This is a convenience wrapper around :func:`run` that mirrors
    :func:`subprocess.check_output`.
    """

    result = run(args, cwd=cwd, env=env, timeout=timeout, **kwargs)
    return result.stdout


__all__ = ["run", "check_output"]
