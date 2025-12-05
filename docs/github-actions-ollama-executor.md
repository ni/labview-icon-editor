# GitHub Actions for Ollama Executor

## Overview
Two GitHub Actions workflows provide automated testing and build capabilities for the Ollama Executor.

## Workflows

### 1. Smoke Test Hard Gate (`ollama-executor-smoke.yml`)

**Purpose**: Quality gate that blocks PR merges if critical tests fail

**Triggers**:
- Pull requests modifying:
  - `scripts/ollama-executor/**`
  - `.devcontainer/**`
  - `install-ollama.ps1`
- Pushes to `main` or `develop`

**Jobs**:

#### `smoke-test` (Multi-OS Matrix)
Runs critical tests on Linux, Windows, and macOS:
- Command vetting tests (26 cases)
- Simulation mode tests (4 scenarios)
- Security fuzzing (1,000+ attack vectors)
- Regression tests (2 tracked bugs)
- Fast test suite

**Artifacts**:
- Test results (JSON/XML)
- Test reports (HTML)

#### `security-gate` (Hard Gate)
**BLOCKS MERGE IF FAILS**
- Runs comprehensive security fuzzing
- Verifies no regressions in fixed bugs
- Exit code 1 = merge blocked

#### `performance-baseline`
- Runs performance benchmarks
- Uploads baseline for tracking
- Does not block merge (warning only)

#### `summary`
- Aggregates all results
- Posts summary comment to PR with:
  - ✅/❌ status for each gate
  - Test coverage breakdown
  - Link to detailed results

**Example PR Comment**:
```
## 🧪 Ollama Executor Smoke Test Results

| Test Category | Status |
|---------------|--------|
| Smoke Tests (Multi-OS) | ✅ success |
| Security Hard Gate | ✅ success |
| Performance Baseline | ✅ success |

### Test Coverage
- ✅ Command vetting (26 test cases)
- ✅ Simulation mode (4 scenarios)
- ✅ Security fuzzing (1000+ attack vectors)
- ✅ Regression tracking (all fixed bugs)
- ✅ Cross-platform (Linux, Windows, macOS)

🎉 **All gates passed!** This PR is ready to merge.
```

---

### 2. Build Automation (`ollama-executor-build.yml`)

**Purpose**: Automated builds using Ollama Executor

**Triggers**:
- `workflow_dispatch`: Manual execution with parameters
- Pull requests modifying:
  - `scripts/build-source-distribution/**`
  - `scripts/ppl-from-sd/**`
  - `scripts/ollama-executor/**`

**Inputs** (for workflow_dispatch):
- `goal`: Build goal description (e.g., "Build Source Distribution LV2025 64-bit")
- `max_turns`: Maximum conversation turns (default: 10)
- `simulation`: Use simulation mode (default: true)

**Jobs**:

#### `ollama-build-simulation`
**Runs on PRs and when simulation=true**
- Uses mock Ollama server
- Enables simulation mode (no real LabVIEW)
- Runs Drive-Ollama-Executor.ps1
- Creates stub artifacts
- Fast execution (<2 minutes)

**Environment**:
```yaml
OLLAMA_EXECUTOR_MODE: sim
OLLAMA_SIM_DELAY_MS: 50
OLLAMA_SIM_CREATE_ARTIFACTS: true
OLLAMA_HOST: http://localhost:11436
OLLAMA_MODEL_TAG: llama3-8b-local
```

#### `ollama-build-real`
**Runs when simulation=false (workflow_dispatch only)**
- Uses real Ollama service container
- Actual LLM execution
- Can create real build artifacts
- Requires LabVIEW installation for complete builds

**Service Container**:
```yaml
services:
  ollama:
    image: ghcr.io/${{ github.repository_owner }}/ollama-local:cpu-preloaded
    ports:
      - 11435:11435
```

#### `multi-platform-build` (Matrix)
**Runs on PRs**

Builds for all combinations:
- LabVIEW: 2021, 2025
- Bitness: 32-bit, 64-bit

Total: 4 parallel builds

Each build:
1. Uses simulation mode
2. Calls SimulationProvider.ps1 directly
3. Creates platform-specific artifacts
4. Uploads to separate artifact per platform

#### `comment-results`
Posts build summary to PR:
```
## 🤖 Ollama Executor Build Results

| Build Type | Status |
|------------|--------|
| Single Build (Simulation) | ✅ success |
| Multi-Platform Matrix | ✅ success |

### Simulated Platforms
- LabVIEW 2021 32-bit ✅
- LabVIEW 2021 64-bit ✅
- LabVIEW 2025 32-bit ✅
- LabVIEW 2025 64-bit ✅

🎉 **All builds completed successfully!**
```

---

## Usage Examples

### Run Smoke Tests (Automatic on PR)
1. Create PR with changes to Ollama executor
2. Smoke test workflow runs automatically
3. Wait for results (~5 minutes)
4. Check PR comment for summary
5. If fails, review detailed logs in Actions tab

### Simulate a Build (Manual)
1. Go to Actions → "Ollama Executor Build Automation"
2. Click "Run workflow"
3. Enter parameters:
   - Goal: "Build Source Distribution LV2025 64-bit"
   - Max turns: 10
   - Simulation: true (checked)
4. Click "Run workflow"
5. Wait for completion (~2 minutes)
6. Download artifacts from workflow summary

### Real Build with Ollama (Manual)
1. Go to Actions → "Ollama Executor Build Automation"
2. Click "Run workflow"
3. Enter parameters:
   - Goal: "Build Source Distribution LV2025 64-bit"
   - Max turns: 20
   - Simulation: false (unchecked)
4. Click "Run workflow"
5. Wait for completion (~10-30 minutes depending on goal)
6. Download real build artifacts

---

## Artifacts

### Smoke Test Artifacts
- `test-results-{os}`: JSON/XML test results
- `test-reports-{os}`: HTML test reports
- `performance-baseline`: Performance benchmark data

### Build Artifacts
- `ollama-build-artifacts-simulation`: Simulated build outputs
- `ollama-build-artifacts-real`: Real build outputs
- `build-lv{version}-{bitness}bit`: Platform-specific artifacts
- `ollama-executor-logs`: Execution logs

**Retention**:
- Test results: 30 days
- Performance baselines: 90 days
- Build artifacts: 7-30 days

---

## Integration with Existing Workflows

### Compatibility
- Works alongside existing CI workflows
- Does not interfere with LabVIEW build actions
- Uses separate ports (11435-11436) to avoid conflicts

### When to Use

**Use Smoke Test for**:
- All PRs touching Ollama executor
- Validating security fixes
- Ensuring no regressions

**Use Build Automation for**:
- Testing build script changes
- Validating cross-platform builds
- Demonstrating Ollama executor capabilities
- Creating test artifacts

**Do NOT use for**:
- Production LabVIEW builds (use existing workflows)
- Release artifacts (use real LabVIEW tools)
- Critical builds requiring validation

---

## Failure Scenarios

### Smoke Test Failures

**Security Gate Fails**:
- **Cause**: Security vulnerability detected
- **Action**: Review fuzzing results, fix vulnerability
- **Impact**: PR blocked from merge

**Regression Gate Fails**:
- **Cause**: Previously-fixed bug has reappeared
- **Action**: Review regression test results, restore fix
- **Impact**: PR blocked from merge

**Smoke Test Fails**:
- **Cause**: Basic functionality broken
- **Action**: Review test logs, fix breaking change
- **Impact**: PR blocked from merge

### Build Automation Failures

**Simulation Build Fails**:
- **Cause**: Script syntax error or logic issue
- **Action**: Review executor logs, fix script
- **Impact**: Warning only, PR not blocked

**Real Build Fails**:
- **Cause**: Ollama service issue or build error
- **Action**: Check Ollama logs, verify service health
- **Impact**: Build artifacts not created

**Multi-Platform Build Fails**:
- **Cause**: Platform-specific script issue
- **Action**: Review failing platform logs
- **Impact**: Some platform artifacts missing

---

## Monitoring and Debugging

### View Detailed Logs
1. Go to Actions tab
2. Click on workflow run
3. Expand failed job
4. Review step outputs

### Download Artifacts
1. Go to workflow run summary
2. Scroll to "Artifacts" section
3. Click artifact name to download

### Re-run Failed Jobs
1. Go to failed workflow run
2. Click "Re-run failed jobs"
3. Or "Re-run all jobs" for clean slate

---

## Performance

**Smoke Test**:
- Multi-OS: ~5 minutes total
- Security gate: ~2 minutes
- Performance baseline: ~1 minute

**Build Automation**:
- Simulation: ~2 minutes
- Real: ~10-30 minutes (depends on goal)
- Multi-platform: ~2 minutes (parallel)

---

## Future Enhancements

### Planned
- [ ] Code coverage reporting
- [ ] Performance regression detection
- [ ] Notification on failures
- [ ] Integration with status checks
- [ ] Custom Ollama models per workflow

### Possible
- [ ] Scheduled nightly builds
- [ ] Cross-repo build triggers
- [ ] Build artifact caching
- [ ] Parallel real builds

---

## Troubleshooting

### "Ollama service unhealthy"
- Check Ollama image is available
- Verify GHCR credentials
- Check service container logs

### "Mock server failed to start"
- Review MockOllamaServer.ps1 syntax
- Check port availability (11436)
- Verify scenario file exists

### "Simulation artifacts not created"
- Check OLLAMA_SIM_CREATE_ARTIFACTS=true
- Verify SimulationProvider.ps1 working
- Review working directory path

### "Security gate always fails"
- Run locally: `pwsh scripts/ollama-executor/Test-SecurityFuzzing.ps1`
- Check for new vulnerabilities
- Review command vetting logic

---

## Status: Production Ready ✅

Both workflows are tested and operational:
- ✅ Smoke test validates all PRs
- ✅ Build automation demonstrates executor
- ✅ Multi-platform matrix working
- ✅ Artifacts properly uploaded
- ✅ PR comments functional
