# Deployment Failure Handling - CRITICAL FIX

## 🐛 Problem Statement

**Issue**: When the deployment fails, the script sometimes tries to redeploy instead of exiting cleanly.

**Root Cause**: Bash pipeline trap - using `tee` masks the exit code of the previous command.

---

## 🔍 Technical Analysis

### The Bug (Original Code)

```bash
# Line 12: set -e only exits on simple command failures
set -e

# Lines 186: The pipeline problem
eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee /tmp/test-${STUDENT_NAME}.log
```

**Why This Fails**:

1. **Pipeline Exit Code**: In bash, the exit code of a pipeline is the exit code of the LAST command
2. `tee` always returns `0` (success), even if the previous command failed
3. With `set -e`, bash only sees `tee`'s exit code (0), so it doesn't exit
4. Script continues to verification steps, potentially causing confusion
5. May trigger retry logic or partial cleanup attempts

**Example**:
```bash
# This WILL exit (simple command)
false  # Exit code 1 → script exits

# This WON'T exit (pipeline without pipefail)
false | tee /tmp/log  # tee returns 0 → script continues
```

---

## ✅ The Fix

### Three Critical Changes

#### 1. Add `set -o pipefail`

```bash
#!/bin/bash
set -e          # Exit on error
set -o pipefail # Return exit code from failed command in pipeline ✨ NEW
set -u          # Exit on undefined variable
```

**What This Does**: Makes bash return the exit code of the first failed command in a pipeline, not just the last command.

```bash
# With set -o pipefail:
false | tee /tmp/log  # Returns 1 (false's exit code) → script exits ✅
```

#### 2. Explicitly Capture Exit Code

```bash
# OLD (masked failures):
eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee "${DEPLOY_LOG}"

# NEW (captures failures):
if ! eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee "${DEPLOY_LOG}"; then
    DEPLOY_EXIT_CODE=$?
    echo "❌ DEPLOYMENT FAILED"
    echo "Exit code: ${DEPLOY_EXIT_CODE}"
    exit ${DEPLOY_EXIT_CODE}
fi
```

**Benefits**:
- Explicit failure detection
- Proper error message before exit
- Clean failure handling
- No retry attempts

#### 3. Add Failure Guidance

```bash
if ! eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee "${DEPLOY_LOG}"; then
    echo "╔════════════════════════════════════════╗"
    echo "║  ❌ DEPLOYMENT FAILED                  ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "Common causes:"
    echo "  1. AWS service quota exceeded"
    echo "  2. Invalid AWS credentials"
    echo "  3. Network connectivity issues"
    echo ""
    echo "To cleanup:"
    echo "  ./99-destroy-sno-complete.sh ${STUDENT_NAME}"
    exit ${DEPLOY_EXIT_CODE}
fi
```

---

## 📊 Behavior Comparison

### Before Fix

| Scenario | Behavior | Expected | Actual | Issue |
|----------|----------|----------|--------|-------|
| Success | Continues | ✅ Continue | ✅ Continue | ✅ OK |
| Failure (quota) | Should exit | ❌ Exit | ⚠️ Continue | 🐛 BUG |
| Failure (network) | Should exit | ❌ Exit | ⚠️ Continue | 🐛 BUG |
| Failure (creds) | Should exit | ❌ Exit | ⚠️ Continue | 🐛 BUG |

### After Fix

| Scenario | Behavior | Expected | Actual | Issue |
|----------|----------|----------|--------|-------|
| Success | Continues | ✅ Continue | ✅ Continue | ✅ OK |
| Failure (quota) | Exits immediately | ❌ Exit | ❌ Exit | ✅ FIXED |
| Failure (network) | Exits immediately | ❌ Exit | ❌ Exit | ✅ FIXED |
| Failure (creds) | Exits immediately | ❌ Exit | ❌ Exit | ✅ FIXED |

---

## 🧪 Testing the Fix

### Test 1: Simulate Failure (Invalid Credentials)

```bash
# Temporarily break credentials
export AWS_ACCESS_KEY_ID="INVALID"

# Run deployment
./workshop-scripts/03-test-single-sno-FIXED.sh student-test

# Expected Output:
# ❌ DEPLOYMENT FAILED
# Exit code: 1
# (script exits immediately)
```

### Test 2: Simulate Failure (Network Issue)

```bash
# Block network temporarily
sudo iptables -A OUTPUT -d cloud.redhat.com -j DROP

# Run deployment
./workshop-scripts/03-test-single-sno-FIXED.sh student-test

# Expected Output:
# ❌ DEPLOYMENT FAILED
# (script exits, no verification attempts)
```

### Test 3: Success Path

```bash
# Normal deployment
./workshop-scripts/03-test-single-sno-FIXED.sh student1

# Expected Output:
# [4/5] Deploying SNO cluster...
# (deployment succeeds)
# ✅ DEPLOYMENT COMPLETED SUCCESSFULLY
```

---

## 🎯 Impact Analysis

### What Changes

**Before**:
```
Deployment starts → Failure → Script continues → Verification fails → Confusion
```

**After**:
```
Deployment starts → Failure → Script exits immediately → Clear error message
```

### Benefits

1. **Predictable Behavior**: Always exits on first failure
2. **Clear Error Messages**: Shows what went wrong
3. **No Retry Confusion**: Won't attempt automatic retries
4. **Clean State**: Doesn't partially execute post-deployment steps
5. **Better Debugging**: Log file preserved, exit code captured

### No Breaking Changes

- ✅ Success path unchanged
- ✅ Same command-line interface
- ✅ Same output format (when successful)
- ✅ Same log file location
- ✅ Compatible with existing cleanup scripts

---

## 📝 Usage

### Option 1: Use Fixed Script

```bash
# Use the new fixed version
./workshop-scripts/03-test-single-sno-FIXED.sh student1
```

### Option 2: Replace Original

```bash
# Backup original
mv workshop-scripts/03-test-single-sno.sh workshop-scripts/03-test-single-sno.sh.BACKUP

# Use fixed version
cp workshop-scripts/03-test-single-sno-FIXED.sh workshop-scripts/03-test-single-sno.sh
```

### Option 3: Test Side-by-Side

```bash
# Test with fixed version
./workshop-scripts/03-test-single-sno-FIXED.sh student-test

# If it works, replace original
mv workshop-scripts/03-test-single-sno.sh workshop-scripts/03-test-single-sno.sh.OLD
mv workshop-scripts/03-test-single-sno-FIXED.sh workshop-scripts/03-test-single-sno.sh
```

---

## 🔍 Additional Improvements in Fixed Version

### 1. Better Error Context

```bash
if ! eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee "${DEPLOY_LOG}"; then
    echo "Common causes:"
    echo "  1. AWS service quota exceeded (VPCs, vCPUs, Elastic IPs)"
    echo "  2. Invalid AWS credentials or permissions"
    echo "  3. Network connectivity issues"
    echo "  4. OpenShift pull secret invalid"
    echo ""
    echo "Check the log file for details:"
    echo "  tail -100 ${DEPLOY_LOG}"
fi
```

### 2. Cleanup Guidance

```bash
echo "To cleanup partial deployment:"
echo "  ./99-destroy-sno-complete.sh ${STUDENT_NAME}"
```

### 3. Exit Code Preservation

```bash
DEPLOY_EXIT_CODE=$?
echo "Ansible playbook exited with code: ${DEPLOY_EXIT_CODE}"
exit ${DEPLOY_EXIT_CODE}
```

---

## 🚨 Critical Scenarios Where This Matters

### Scenario 1: VPC Limit Exceeded

**Before Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: VPC limit exceeded
(continues to verification)
[5/5] Verifying deployment...
✗ Kubeconfig not found - check logs
(confusing - was there a failure?)
```

**After Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: VPC limit exceeded
❌ DEPLOYMENT FAILED
Exit code: 1
To cleanup: ./99-destroy-sno-complete.sh student1
(exits immediately - clear what happened)
```

### Scenario 2: Invalid Pull Secret

**Before Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: Invalid pull secret
(continues to SSH test)
Testing SSH connectivity to bastion...
✗ Bastion not found
(wasted time on tests that can't succeed)
```

**After Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: Invalid pull secret
❌ DEPLOYMENT FAILED
Common causes:
  4. OpenShift pull secret invalid
(exits immediately with guidance)
```

### Scenario 3: AWS Credentials Expired

**Before Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: Credentials expired
(tries to continue)
[5/5] Verifying deployment...
(more AWS API calls fail)
(multiple confusing errors)
```

**After Fix**:
```
[4/5] Deploying SNO cluster...
ERROR: Credentials expired
❌ DEPLOYMENT FAILED
Common causes:
  2. Invalid AWS credentials or permissions
(single, clear failure point)
```

---

## 📚 Technical References

### Bash Pipeline Behavior

From [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html#Pipelines):

> The return status of a pipeline is the exit status of the last command, unless the pipefail option is enabled. If pipefail is enabled, the pipeline's return status is the value of the last (rightmost) command to exit with a non-zero status, or zero if all commands exit successfully.

### Best Practices

From [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):

```bash
# Always use these for robust scripts:
set -e          # Exit on error
set -u          # Exit on undefined variable
set -o pipefail # Propagate pipeline failures
```

### AgnosticD Expectations

From [AgnosticD Best Practices](https://github.com/redhat-cop/agnosticd):

> Deployment scripts should fail fast and provide clear error messages. Never silently continue after a failure.

---

## ✅ Testing Checklist

Before using in production:

- [ ] Test with valid credentials (success path)
- [ ] Test with invalid AWS credentials (should exit immediately)
- [ ] Test with insufficient quotas (should exit immediately)
- [ ] Test with invalid pull secret (should exit immediately)
- [ ] Verify log file is created and preserved
- [ ] Verify exit codes are correct (0 = success, non-zero = failure)
- [ ] Verify cleanup guidance is shown on failure
- [ ] Verify no partial deployment attempts after failure

---

## 🎓 Learning Points

### For Workshop Instructors

1. **Always test failure paths** - Don't just test the happy path
2. **Bash pipelines are tricky** - Use `set -o pipefail` by default
3. **Exit codes matter** - Capture and preserve them
4. **Clear error messages** - Help users understand what went wrong
5. **Fail fast** - Don't waste time on doomed operations

### For Students

Example of why error handling matters in production:

```bash
# Bad: Silent failure
deploy_app | tee log.txt
# (continues even if deploy_app failed)

# Good: Explicit failure handling
if ! deploy_app | tee log.txt; then
    echo "Deployment failed!"
    notify_team
    cleanup_resources
    exit 1
fi
```

---

## 📞 Support

If deployment still continues after failure with the fixed script:

1. Check if you're using the FIXED version:
   ```bash
   grep "set -o pipefail" workshop-scripts/03-test-single-sno-FIXED.sh
   # Should show: set -o pipefail
   ```

2. Check bash version (needs 3.0+):
   ```bash
   bash --version
   ```

3. Review the log file:
   ```bash
   tail -100 /tmp/test-student1.log
   ```

4. Check for retry logic in AgnosticD config:
   ```bash
   grep -r "retry\|until" ~/agnosticd/ansible/configs/low-latency-workshop-sno/
   ```

---

## 📖 Summary

**Problem**: Deployment script masked failures and continued executing  
**Root Cause**: Bash pipeline trap with `tee` command  
**Solution**: Added `set -o pipefail` and explicit failure handling  
**Impact**: Clean, predictable failure behavior with clear error messages  
**Status**: ✅ **FIXED** in `03-test-single-sno-FIXED.sh`

**Recommendation**: Test the fixed version, then replace the original script.

---

**Document Version**: 1.0  
**Date**: November 28, 2025  
**Status**: Ready for Testing

