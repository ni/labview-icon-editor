# ADR 0009: JSON Logging and Retry Strategy

- Status: Accepted
- Date: 2025-09-02
- Deciders: x-cli maintainers
- Tags: logging, diagnostics

## Context
XCli logs every command invocation as a single-line JSON object. Logs always stream to `stderr` and may also append to a file when `XCLI_LOG_PATH` is set. Concurrent CI jobs and unreliable filesystems require a resilient, append-only strategy.

## Decision
- **File path control:** `XCLI_LOG_PATH` enables optional file logging. The logger creates parent directories and appends UTF-8 JSONL entries.
- **Retry and timeout:** `XCLI_LOG_TIMEOUT_MS` caps the total time spent acquiring locks and writing. `XCLI_LOG_MAX_ATTEMPTS` bounds individual lock and write retries. Both values fall back to sane defaults and are clamped when out of range.
- **Adaptive retries:** The logger spins and sleeps with increasing delays between attempts. Windows and Linux use file locking to serialize appends; unsuccessful attempts retry until the timeout or attempt limit is reached.
- **Debug diagnostics:** When `XCLI_DEBUG=true`, lock failures, timeouts, and other internal exceptions are echoed to `stderr` for analysis. Without debug mode, failures only surface once via a single warning line.

## Consequences
- **Append-only logs:** Concurrent appends avoid corruption but log files can grow without bound and cannot remove or rewrite entries.
- **Diagnostic clarity vs noise:** Debug mode aids troubleshooting but increases stderr chatter and may expose paths or internal exceptions.
- **Tunable reliability:** Environment variables let CI adjust durability versus speed, but misconfiguration (e.g., tiny timeouts) can drop log entries.
