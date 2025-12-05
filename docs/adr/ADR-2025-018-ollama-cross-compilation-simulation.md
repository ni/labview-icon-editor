# ADR: Ollama Executor Cross-Compilation Simulation Mode

- **ID**: ADR-2025-018  
- **Status**: Proposed  
- **Date**: 2025-12-03

## Context
The Ollama executor (`Drive-Ollama-Executor.ps1`) currently executes PowerShell commands that invoke real LabVIEW build tools (g-cli, VIPM, and similar tools) for building VIPs, source distributions, and PPLs across different LabVIEW versions (2021, 2025) and bitnesses (32-bit, 64-bit). This creates several challenges:

1. **Platform Dependency**: Building for all target platforms requires all LabVIEW versions and bitnesses to be installed on the machine
2. **Resource Intensive**: Running real builds consumes significant time and system resources
3. **Limited CI/CD**: CI environments cannot easily test cross-compilation scenarios without full LabVIEW installations
4. **Testing Difficulty**: Testing Ollama executor logic requires actual build environments

## Decision
Implement a **cross-compilation simulation mode** for the Ollama executor that allows simulated builds for different LabVIEW versions and bitnesses without requiring those platforms to be installed. This follows the existing simulation pattern established in ADR-0004 (XCLI_PROVIDER=sim).

### Design Overview

1. **Environment Variable**: `OLLAMA_EXECUTOR_MODE=sim` enables simulation mode
2. **Platform Simulation**: Simulated builds can target any LabVIEW version/bitness combination
3. **Deterministic Behavior**: Simulation results are predictable and controllable via environment variables
4. **No Real Execution**: No actual LabVIEW tools are invoked; file artifacts are mocked/stubbed
5. **Compatible Interface**: Simulation mode produces output compatible with real execution (exit codes, stdout/stderr, file artifacts)

### Environment Variables

- `OLLAMA_EXECUTOR_MODE=sim` - Enables simulation mode (default: real execution)
- `OLLAMA_SIM_FAIL=true` - Forces simulated commands to fail
- `OLLAMA_SIM_EXIT=<code>` - Sets exit code for simulated commands (default: 0)
- `OLLAMA_SIM_DELAY_MS=<ms>` - Adds artificial delay to simulate build time (default: 100)
- `OLLAMA_SIM_CREATE_ARTIFACTS=true` - Creates stub artifact files (VIP, source dist zip, and other build outputs)
- `OLLAMA_SIM_PLATFORMS=2021-32,2021-64,2025-64` - Comma-separated list of simulated available platforms

### Implementation Components

1. **Simulation Provider** (`scripts/ollama-executor/SimulationProvider.ps1`):
   - Detects simulation mode via environment variables
   - Provides simulated execution for build scripts
   - Creates stub artifacts if requested
   - Returns realistic stdout/stderr output

2. **Command Interceptor** in `Drive-Ollama-Executor.ps1`:
   - Checks `OLLAMA_EXECUTOR_MODE` before executing commands
   - Routes to `SimulationProvider.ps1` when in sim mode
   - Maintains same interface (exit code, stdout, stderr)

3. **Artifact Generator** (`scripts/ollama-executor/GenerateStubArtifacts.ps1`):
   - Creates minimal valid VIP files (zip with metadata)
   - Creates source distribution placeholders
   - Generates build logs and manifests

### Simulated Command Behaviors

For `Build_Source_Distribution.ps1`:
- Simulated duration: 1-5 seconds (configurable via OLLAMA_SIM_DELAY_MS)
- Exit code: 0 (success) or from OLLAMA_SIM_EXIT
- Stdout: Build log indicating LabVIEW version, bitness, and artifact path
- Artifacts (if OLLAMA_SIM_CREATE_ARTIFACTS=true): Creates `.zip` file with manifest

For `Build_Ppl_From_SourceDistribution.ps1`:
- Similar pattern with PPL-specific outputs

For package build scripts:
- Creates stub VIP files with minimal structure

### Cross-Platform Simulation

The simulation mode can represent any platform combination:

```powershell
# Simulate LabVIEW 2021 32-bit build
$env:OLLAMA_EXECUTOR_MODE = "sim"
$env:OLLAMA_SIM_PLATFORMS = "2021-32"
# Ollama executor shall "build" for 2021 32-bit without having it installed

# Simulate multi-platform build
$env:OLLAMA_SIM_PLATFORMS = "2021-32,2021-64,2025-32,2025-64"
# Ollama executor can "build" for all platforms in sequence
```

### Use Cases

1. **CI/CD Testing**: Test Ollama executor logic without LabVIEW installations
2. **Development**: Rapidly iterate on executor scripts without waiting for real builds
3. **Documentation**: Generate example outputs for documentation
4. **Training**: Allow developers to experiment with Ollama executor safely
5. **Cross-Platform Validation**: Verify build scripts work across all target platforms

## Consequences

### Positive
- **Faster Development**: Test Ollama executor workflows in seconds instead of minutes
- **Platform Independence**: Develop and test on machines without all LabVIEW versions
- **Reproducible Testing**: Deterministic simulation results for automated tests
- **Lower Resource Usage**: No CPU/memory overhead from real LabVIEW builds
- **Consistent Pattern**: Follows existing XCLI_PROVIDER=sim pattern from ADR-0004

### Negative
- **Maintenance**: Simulation logic should be kept in sync with real build script signatures
- **Not a Replacement**: Simulation cannot catch real LabVIEW/VIPM errors
- **Artifact Validity**: Stub artifacts are not functionally equivalent to real builds

### Mitigations
- Use simulation for executor testing; use real builds for artifact validation
- Document clearly that simulation is for executor logic testing only
- Provide validation scripts to verify simulated artifacts match real structure
- Include simulation mode indicator in all outputs

## Alternatives Considered

### A: Mock LabVIEW Tools Directly
- Create mock g-cli, VIPM executables that return success
- **Rejected**: Too invasive; requires PATH manipulation; harder to maintain

### B: Docker Containers with Pre-built Artifacts  
- Use containers with cached build outputs
- **Rejected**: Still requires building at least once; doesn't help with missing platforms

### C: No Simulation - Require Real Builds
- Keep current behavior; require all platforms installed
- **Rejected**: Too restrictive for development and CI/CD workflows

## Implementation Plan

1. Create `SimulationProvider.ps1` with core simulation logic
2. Modify `Drive-Ollama-Executor.ps1` to check OLLAMA_EXECUTOR_MODE
3. Implement `GenerateStubArtifacts.ps1` for creating minimal valid artifacts
4. Add environment variable documentation
5. Create test scripts demonstrating simulation mode
6. Update README with simulation mode usage examples

## Follow-ups
- [ ] Document environment variables in main README
- [ ] Create integration tests using simulation mode
- [ ] Add VS Code task for running Ollama executor in simulation mode
- [ ] Consider adding simulation summary report (which platforms were simulated)

> Traceability: Ollama executor scripts under `scripts/ollama-executor/`; follows ADR-0004 simulation pattern.
