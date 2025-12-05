# VI History Suite - README

## Overview

The VI History Suite provides automated VI analysis, comparison, and compatibility tracking across LabVIEW versions (2021-2025) and platforms (32-bit/64-bit). This leverages the **VI History Suite and VI Comparison report features introduced in LabVIEW 2025.3**.

## Components

### 1. SimulateVIMetadata.ps1
Extracts VI metadata including version, dependencies, and connector pane information.

**Usage:**
```powershell
pwsh -NoProfile -File SimulateVIMetadata.ps1 -VIPath "MyVI.vi"
pwsh -NoProfile -File SimulateVIMetadata.ps1 -VIPath "MyVI.vi" -OutputFormat json
```

### 2. Compare-VIHistory.ps1
Compares two VI versions and identifies breaking changes, deprecated APIs, and compatibility impacts.

**Usage:**
```powershell
pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi"
pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi" -OutputFormat lv2025 -OutputPath "comparison.json"
pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi" -OutputFormat html -OutputPath "report.html"  # renders LV 2025.3 HTML via the generator
```

### 3. Analyze-VICompatibility.ps1
Analyzes VI compatibility across all supported LabVIEW versions and platforms.

**Usage:**
```powershell
pwsh -NoProfile -File Analyze-VICompatibility.ps1 -VIPath "MyVI.vi"
pwsh -NoProfile -File Analyze-VICompatibility.ps1 -VIPath "MyVI.vi" -OutputFormat matrix
```

## Data Files

### vi-compatibility-matrix.json
Database of LabVIEW version features, deprecated APIs, and platform capabilities.

### api-deprecations.json
Comprehensive database of deprecated APIs with migration guides and severity ratings.

## Testing

Run the test suite:
```powershell
pwsh -NoProfile -File Test-VIMetadata.ps1
pwsh -NoProfile -File Test-VIComparison.ps1
```

## Implementation Status

### Phase 1: Foundation (Weeks 1-2) ✅ COMPLETE
- [x] SimulateVIMetadata.ps1
- [x] vi-compatibility-matrix.json
- [x] api-deprecations.json
- [x] Test-VIMetadata.ps1

### Phase 2: Comparison (Weeks 3-4) ✅ IN PROGRESS
- [x] Compare-VIHistory.ps1
- [x] Test-VIComparison.ps1
- [x] Full connector pane diff implementation
- [x] Dependency tracking

### Phase 3: Compatibility (Weeks 5-6) ✅ IN PROGRESS
- [x] Analyze-VICompatibility.ps1
- [ ] platform-features.json
- [ ] Test-Compatibility.ps1

### Phase 4: History (Weeks 7-8) 📋 PLANNED
- [ ] Track-VIHistory.ps1
- [ ] Git integration
- [ ] Test-HistoryTracking.ps1
- [ ] GitHub Actions workflow

### Phase 5: Reporting (Weeks 9-10) 📋 PLANNED
- [x] Generate-VIHistoryReport.ps1
- [x] LV 2025.3 compatible HTML templates
- [ ] Test-ReportGeneration.ps1
- [ ] Complete documentation

## Requirements

- PowerShell 7+
- Git (for history tracking features)
- LabVIEW 2025.3 (optional, for native API access)

## Integration with LabVIEW 2025.3

When LabVIEW 2025.3 is installed, the suite can leverage:
- Native VI History Suite API for metadata extraction
- VI Comparison report format for output compatibility
- Enhanced accuracy for VI file parsing

## License

Part of the LabVIEW Icon Editor project.

## See Also

- Complete specification: `docs/VI-HISTORY-SUITE-SPECIFICATION.md`
- Milestone plan: `docs/milestones/MILESTONE-1-VI-History-Suite.md`
