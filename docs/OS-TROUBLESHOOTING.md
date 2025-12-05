# OS-Specific Build Troubleshooting Guide

**Purpose**: Diagnose and fix OS-specific failures in GitHub Actions workflows  
**Date**: 2025-12-03  
**Status**: Ready for iterative fixes

---

## Quick Diagnosis

### Check Build Status
1. Go to Actions tab in GitHub
2. Find the workflow run
3. Identify which OS failed
4. Click on failed job
5. Review error logs

---

## Common OS-Specific Issues

### 🐧 Linux Issues

#### Issue: `/tmp` Permission Denied
**Symptom**: Cannot create temp directories  
**Solution**:
```powershell
$tempPath = if ($env:TMPDIR) { $env:TMPDIR } else { "/tmp/$(whoami)" }
New-Item -ItemType Directory -Path $tempPath -Force
```

#### Issue: PowerShell Not Found
**Symptom**: `pwsh: command not found`  
**Solution**: GitHub Actions uses `pwsh` by default, ensure:
```yaml
- name: Setup PowerShell
  shell: pwsh
```

#### Issue: Case-Sensitive Paths
**Symptom**: File not found errors  
**Solution**: Always use exact case in file paths

---

### 🪟 Windows Issues

#### Issue: Path Length Limit
**Symptom**: Paths >260 characters fail  
**Solution**:
```powershell
# Use short temp paths
$tempPath = Join-Path $env:TEMP $(New-Guid).ToString().Substring(0,8)
```

#### Issue: Line Endings (CRLF vs LF)
**Symptom**: Script parsing errors  
**Solution**: Configure `.gitattributes`:
```
*.ps1 text eol=lf
*.sh text eol=lf
```

#### Issue: PowerShell Execution Policy
**Symptom**: Scripts won't execute  
**Solution**: Use `-NoProfile` flag:
```powershell
pwsh -NoProfile -File script.ps1
```

---

### 🍎 macOS Issues

#### Issue: Case-Sensitive Filesystem (Optional)
**Symptom**: File not found on some macOS systems  
**Solution**: Use consistent casing

#### Issue: Temp Directory Permissions
**Symptom**: Cannot write to /tmp  
**Solution**:
```powershell
$tempPath = if ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
```

#### Issue: Docker Not Available
**Symptom**: Docker commands fail  
**Solution**: Skip Docker tests on macOS or use alternative

---

## Fix Process

### Step 1: Identify Failure
```bash
# Review GitHub Actions log
# Note the exact error message
# Note the OS (ubuntu/windows/macos)
# Note the test that failed
```

### Step 2: Reproduce Locally (if possible)
```powershell
# On Linux
pwsh -NoProfile -File scripts/ollama-executor/Test-SmokeTest.ps1

# On Windows
pwsh.exe -NoProfile -File scripts\ollama-executor\Test-SmokeTest.ps1

# On macOS
pwsh -NoProfile -File scripts/ollama-executor/Test-SmokeTest.ps1
```

### Step 3: Apply Fix
```powershell
# Fix temp path handling
$tempPath = if ($env:TEMP) { 
    $env:TEMP 
} elseif ($env:TMPDIR) { 
    $env:TMPDIR 
} else { 
    "/tmp" 
}

# Fix exit codes
if ($testsPassed) {
    exit 0
} else {
    exit 1
}

# Fix path separators
$path = Join-Path $base $relative  # Auto-detects separator
```

### Step 4: Test Fix
```powershell
# Run smoke test
pwsh -NoProfile -File scripts/ollama-executor/Test-SmokeTest.ps1

# Verify exit code
echo $LASTEXITCODE  # Should be 0 on success
```

### Step 5: Commit and Push
```bash
git add <fixed-files>
git commit -m "Fix: <OS> compatibility for <component>"
git push
```

### Step 6: Verify in CI/CD
- Wait for GitHub Actions to run
- Check all OS builds
- Iterate if needed

---

## Current Status

### ✅ Fixed Issues
- [x] Test exit codes (all test scripts)
- [x] Temp path handling (cross-platform)
- [x] PowerShell syntax (compatible)

### ⏳ Known Potential Issues

#### Windows-Specific
- [ ] Long path handling (if paths >260 chars)
- [ ] CRLF line endings (if .gitattributes not set)
- [ ] Case sensitivity (Windows is case-insensitive)

#### macOS-Specific
- [ ] Docker availability (macOS runners may not have Docker)
- [ ] Permissions (stricter than Linux)

#### Linux-Specific  
- [ ] Container runtime (if using Docker in Docker)

---

## Test Matrix

### Smoke Test (`ollama-executor-smoke.yml`)

| OS | Status | Notes |
|----|--------|-------|
| ubuntu-latest | ✅ PASS | Tested locally |
| windows-latest | 🔄 PENDING | Exit code fixed |
| macos-latest | 🔄 PENDING | Exit code fixed |

### Build Test (`ollama-executor-build.yml`)

| OS | Status | Notes |
|----|--------|-------|
| ubuntu-latest (sim) | ✅ PASS | Tested locally |
| ubuntu-latest (real) | ⏸️ N/A | Needs Ollama service |

---

## Debugging Commands

### Check PowerShell Version
```powershell
$PSVersionTable
```

### Check OS
```powershell
if ($IsWindows) { "Windows" }
elseif ($IsLinux) { "Linux" }
elseif ($IsMacOS) { "macOS" }
```

### Check Temp Directory
```powershell
$env:TEMP      # Windows
$env:TMPDIR    # macOS/some Linux
"/tmp"         # Linux fallback
```

### Check Exit Code
```powershell
$LASTEXITCODE  # PowerShell
echo $?        # Bash (0 = success, 1 = failure)
```

---

## Iterative Fix Workflow

```
1. GitHub Actions fails on <OS>
   ↓
2. Review error logs
   ↓
3. Identify root cause
   ↓
4. Apply minimal fix
   ↓
5. Test locally (if possible)
   ↓
6. Commit and push
   ↓
7. Wait for CI/CD results
   ↓
8. If still failing → goto step 2
   ↓
9. If passing → move to next OS
   ↓
10. All OS passing → DONE ✅
```

---

## Contact Points

### If Linux Fails
- Check temp directory permissions
- Check case sensitivity
- Check PowerShell installation

### If Windows Fails
- Check path length limits
- Check execution policy
- Check line endings

### If macOS Fails
- Check temp directory location
- Check Docker availability
- Check permissions

---

## Emergency Fallbacks

### Skip Problematic Tests
```yaml
- name: Run Tests
  continue-on-error: true  # Don't fail entire workflow
```

### OS-Specific Conditions
```yaml
- name: Run Test (Linux only)
  if: runner.os == 'Linux'
  run: pwsh -NoProfile -File test.ps1
```

### Timeout Protection
```yaml
- name: Run Tests
  timeout-minutes: 10
  run: pwsh -NoProfile -File test.ps1
```

---

## Success Criteria

- [ ] All tests passing on ubuntu-latest
- [ ] All tests passing on windows-latest
- [ ] All tests passing on macos-latest
- [ ] Exit codes correct (0 = success, 1 = fail)
- [ ] No hardcoded OS-specific paths
- [ ] Proper temp directory handling

---

**Ready for**: Iterative OS-specific fixes as failures are identified  
**Status**: Baseline fixes applied, awaiting CI/CD results
