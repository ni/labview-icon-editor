# VI History Suite Overview

## Purpose

The VI History Suite provides automated testing and comparison of LabVIEW VI (Virtual Instrument) metadata across versions. It helps ensure API compatibility, track breaking changes, and maintain backward compatibility during development.

## What It Does

The suite consists of Pester-based tests that:

1. **Simulate VI metadata** - Create lightweight VI fixtures with controlled metadata
2. **Compare VI changes** - Detect differences in connector panes, dependencies, and deprecated APIs
3. **Generate reports** - Produce HTML and JSON reports documenting compatibility impacts
4. **Validate expectations** - Assert that comparison logic correctly identifies breaking vs. non-breaking changes

## Components

### Scripts

Located in `scripts/vi-history-suite/`:

- **`Test-VIComparison.ps1`** - Main Pester test suite
- **`Compare-VIHistory.ps1`** - VI comparison engine
- **`Generate-VIHistoryReport.ps1`** - Report generator (HTML/JSON)
- **`Analyze-VICompatibility.ps1`** - Compatibility analyzer
- **`SimulateVIMetadata.ps1`** - Test fixture helper
- **`Test-VIMetadata.ps1`** - Metadata validation tests

### Configuration Files

- **`api-deprecations.json`** - Known deprecated LabVIEW APIs
- **`vi-compatibility-matrix.json`** - Version compatibility rules
- **`templates/`** - HTML report templates

## CI Integration

The suite runs in **three modes** during CI:

### 1. Simulation Mode (Linux)

**Job**: `vi-history-sim-linux`
- **Platform**: `ubuntu-latest`
- **LabVIEW**: Not required (uses simulated VIs)
- **Purpose**: Fast validation of comparison logic
- **Duration**: ~2-3 seconds

```yaml
steps:
  - Install PowerShell
  - Ensure Pester 5 is available
  - Run VI History comparison Pester suite (Linux)
  - Upload artifacts
```

**Artifacts**:
- `temp/vi-history-report.html` (if generated)
- `temp/vi-history-report.json` (if generated)

### 2. Simulation Mode (Windows)

**Job**: `vi-history-sim-windows`
- **Platform**: `windows-latest`
- **LabVIEW**: Not required (uses simulated VIs)
- **Purpose**: Verify cross-platform compatibility
- **Duration**: ~3-4 seconds

Same steps as Linux simulation mode.

### 3. Real Execution Mode (Windows + LabVIEW)

**Job**: `vi-history-real`
- **Platform**: `self-hosted-windows-lv` (LabVIEW installed)
- **LabVIEW**: Required (analyzes actual VIs)
- **Purpose**: Full VI analysis on real icon editor source
- **Duration**: ~30-60 seconds (depends on VI count)

**Workflow**:
1. Prepare VI History output directories
2. Run VI History suite in dry-run mode
3. Generate VI History comparison report
4. Upload real execution artifacts

**Artifacts**:
- `reports/vi-history/vi-history-report.html`
- `reports/vi-history/vi-history-comparison.json`
- Analysis logs and metadata

## How It Works

### Simulated VI Creation

Tests create minimal VI files with controlled metadata:

```powershell
# Create simulated VI with specific format version
New-SimulatedVi -Path "Example.vi" -FormatVersion 0x0F000000

# Add metadata override (connector, dependencies, etc.)
$metadata = @{
    connector_pane = @{
        input_count = 2
        output_count = 1
        terminals = @(...)
    }
    dependencies = @(...)
    deprecated_apis = @(...)
}
Write-MetadataOverride -ViPath "Example.vi" -Metadata $metadata
```

### Comparison Flow

1. **Load Base VI**: Parse metadata from baseline version
2. **Load Compare VI**: Parse metadata from updated version
3. **Diff Analysis**:
   - Connector pane changes (terminals added/removed/reordered)
   - Dependency changes (VIs added/removed, version changes)
   - Deprecated API usage
   - Format version changes (LabVIEW version compatibility)
4. **Classify Impact**:
   - **Breaking**: Connector changes, removed dependencies
   - **Non-breaking**: Added dependencies, format upgrades
   - **Warning**: Deprecated API usage
5. **Generate Report**: HTML and JSON outputs

### Report Contents

**HTML Report**:
- Summary statistics (VI count, changes detected)
- Connector pane diff table
- Dependency changes (added/removed/updated)
- Deprecated API warnings
- LabVIEW version compatibility matrix

**JSON Report**:
```json
{
  "analysis_timestamp": "2025-12-06T23:00:00Z",
  "labview_version": "2021.0.0",
  "base_path": "...",
  "compare_path": "...",
  "summary": {
    "total_vis": 42,
    "breaking_changes": 2,
    "non_breaking_changes": 5,
    "warnings": 3
  },
  "changes": [...]
}
```

## Running Locally

### Simulation Mode (No LabVIEW Required)

```powershell
# From repository root
cd scripts/vi-history-suite

# Run Pester tests
Invoke-Pester -Path Test-VIComparison.ps1 -Output Detailed
```

**Expected output**:
- All tests pass (green checkmarks)
- Temporary fixtures created in `$env:TEMP/vi-history-suite-test/`
- Comparison reports generated for test scenarios

### Real Analysis Mode (Requires LabVIEW)

```powershell
# Set environment variable (required for process spawning)
$env:XCLI_ALLOW_PROCESS_START = "1"

# Run via x-cli wrapper
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- `
  vi-compare-run `
  --request configs/vi-compare-run-request.sample.json

# Direct script invocation
pwsh scripts/vi-history-suite/Compare-VIHistory.ps1 `
  -BaseViPath "path/to/base/Example.vi" `
  -CompareViPath "path/to/compare/Example.vi" `
  -OutputPath "reports/comparison.json"

# Generate HTML report
pwsh scripts/vi-history-suite/Generate-VIHistoryReport.ps1 `
  -ComparisonPath "reports/comparison.json" `
  -OutputPath "reports/vi-history-report.html"
```

## Test Coverage

The Pester suite validates:

### ✅ Connector Pane Detection
- Added terminals (breaking)
- Removed terminals (breaking)
- Reordered terminals (breaking)
- Error terminal detection

### ✅ Dependency Tracking
- New dependencies (non-breaking)
- Removed dependencies (breaking)
- Version changes (warning)
- Shared dependency preservation

### ✅ Deprecated API Detection
- New deprecated API usage (warning)
- Removed deprecated APIs (improvement)
- API version tracking

### ✅ Format Version Compatibility
- LabVIEW version upgrades
- Backward compatibility warnings
- Forward compatibility blockers

### ✅ Report Generation
- HTML structure validation
- JSON schema compliance
- Metadata accuracy
- LV 2025.3 compatibility tags

## Troubleshooting

### "Pester not found"

**Symptom**: CI or local run fails with "Module 'Pester' not found"

**Solution**:
```powershell
Install-Module -Name Pester -MinimumVersion 5.3.3 -Scope CurrentUser -Force -SkipPublisherCheck
```

CI automatically installs Pester 5+ if missing.

### "No VI files found"

**Symptom**: Real analysis mode reports 0 VIs analyzed

**Cause**: Source path doesn't contain `.vi` files or path is incorrect

**Solution**:
- Verify source path in comparison request JSON
- Ensure dev-mode is bound (if using project VIs)
- Check LabVIEW version compatibility

### "IsolationGuard blocked process start"

**Symptom**: x-cli refuses to spawn LabVIEW process

**Solution**: Set environment variable before running:
```powershell
$env:XCLI_ALLOW_PROCESS_START = "1"
```

### "Simulated VI format invalid"

**Symptom**: Tests fail with format parsing errors

**Cause**: Simulated VI structure doesn't match expected LabVIEW RSRC format

**Solution**:
- Check `New-SimulatedVi` function creates valid magic bytes (`RSRC`)
- Verify format version is 32-bit little-endian at offset 8
- Review test fixtures for correct structure

## Future Enhancements

Planned improvements:

- [ ] Automated connector pane evolution rules
- [ ] Git-based VI version tracking
- [ ] Integration with VI Analyzer results
- [ ] Historical trend analysis (breaking changes over time)
- [ ] API deprecation timeline planning
- [ ] Automated migration guide generation

## Related Documentation

- **x-cli**: `docs/x-cli-overview.md` - x-cli overview and usage
- **x-cli Playbook**: `docs/x-cli-playbook.md` - VI History workflows
- **VS Code Tasks**: `docs/vscode-tasks.md` - Task 09 (x-cli: VI History)
- **CI Workflows**: `docs/ci-workflows.md` - CI pipeline documentation
- **VI History Spec**: `docs/VI-HISTORY-SUITE-SPECIFICATION.md` - Detailed specification

## FAQ

### Why simulate VIs instead of using real files?

**Speed**: Simulated VIs allow rapid test iteration without LabVIEW runtime overhead.

**Isolation**: Tests can control exact metadata scenarios without external dependencies.

**Cross-platform**: Simulation mode works on Linux CI runners without LabVIEW.

**Real mode still runs** on Windows CI with LabVIEW for full integration validation.

### When should VI History analysis run?

**Recommended triggers**:
- Pull requests that modify `.vi` files
- Before merging breaking changes
- Release candidate validation
- Post-merge verification

**Not needed for**:
- Documentation-only changes
- Script/tool changes
- Configuration updates

### How accurate is the comparison?

**Metadata-based**: Comparison relies on LabVIEW metadata extraction, which may not capture:
- Block diagram logic changes
- UI element positioning
- Custom probe configurations

**Use VI Analyzer** (Task 08) for comprehensive VI quality checks.

### Can I extend the deprecated API list?

**Yes**. Edit `scripts/vi-history-suite/api-deprecations.json`:

```json
{
  "deprecated_apis": [
    {
      "name": "LegacyFunction.vi",
      "deprecated_in": "LabVIEW 2020",
      "replacement": "ModernFunction.vi",
      "removal_planned": "LabVIEW 2025"
    }
  ]
}
```

Then regenerate reports to include new deprecation warnings.

