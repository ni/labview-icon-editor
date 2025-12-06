# ADR 0010: Environment Helper Caching and Process Name

- Status: Accepted
- Date: 2025-09-04
- Deciders: x-cli maintainers
- Tags: environment, caching

## Context
The `Env` helper centralizes access to environment variables for x-cli. It caches a case-insensitive snapshot of process variables to avoid repeated lookups and provides utilities for typed retrieval and process name resolution.

## Decision
- **Cache mechanics:** environment variables are loaded once into a case-insensitive dictionary. `Env.Refresh` rebuilds the cache so subsequent reads reflect in-process changes.
- **Case-insensitive lookups:** `Env.Get` and related helpers treat keys case-insensitively, returning `null` when a variable is absent.
- **Process name resolution:** `Env.GetProcessName` prefers `/proc/self/cmdline` on Linux and falls back to `Environment.GetCommandLineArgs`.
- **Prefix filtering:** `Env.GetWithPrefix` returns variables whose names start with a given prefix (default `XCLI_`), matching keys without regard to case and preserving their original casing in the result.

## Consequences
- Tests that modify environment variables must call `Env.ResetCacheForTests` or `Env.Refresh` to avoid cross-test contamination.
- Long-running processes that update environment variables during execution must invoke `Env.Refresh` to observe new values.
