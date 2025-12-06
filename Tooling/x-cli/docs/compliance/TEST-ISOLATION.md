# Test Isolation (Why & How)

**Problem.** Tests interfere via global state and shared files (e.g., module-level REPO_ROOT, manual importlib.reload, writes under repo root), causing order-dependent flakes and banning parallelism. This is documented in the incident analysis. See the central fixtures added in `tests/conftest.py`. 

**What we enforce now.**
- Each test shall run in a unique temp **cwd** (autouse fixture).
- The repository root shall be provided via env `FAKEG_REPO_ROOT`.
- Stateful modules shall be reset via the `reset_modules` fixture until they are refactored to be stateless.
- CI shall fail if tests leave the git worktree dirty (guard against writing into the repo).

**Author guidance.**
- Tests shall not compute “repo root” at **import time**; they shall read `FAKEG_REPO_ROOT` or accept a parameter.
- Tests shall write files only under `tmp_path`/`tmpdir`.
- Authors shall prefer pure functions over cached globals.

## Fixture-first patterns (standard)

**Autouse isolation (`isolated_cwd`)**
- Each test shall run in a unique temp CWD.
- The repository `docs/` tree shall be copied into that temp directory so tests can read/write sandboxed documentation (`<tmp>/docs/**`) without touching the real repo.
- The fixture shall export `FAKEG_REPO_ROOT` pointing to the temp directory; subprocesses inherit it.

**State reset (`reset_modules`)**
- Tests that touch stateful modules (e.g., CLI, memory) shall use `reset_modules` as a parameter or with `@pytest.mark.usefixtures("reset_modules")` to ensure a fresh import state before and after the test.

### Do
- Tests shall use `tmp_path` and the temp `docs/` copy provided by the isolation fixture.
- Tests may read real repo files as **read-only** (derive repo root via `Path(__file__).resolve().parents[1]`) and shall not write there.
- Authors shall prefer fixtures over ad-hoc `TemporaryDirectory`, manual `os.chdir`, or scattered `importlib.reload`.

### Don’t
- Tests shall not write files under the real repository `docs/` (including `docs/srs/**`).
- Tests shall not rely on the current working directory being the repo root.
- Tests shall not manually reload modules; they shall use `reset_modules`.

### Notes
- A CI job (`Tests — Parallel Probe`) runs `pytest -n 2` to surface any residual shared-state issues under parallelism. We will make this gating once green is consistent.
