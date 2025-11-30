# Testing Checklist - RHACM Auto-Import Validation

**Purpose**: Validate that SNO clusters deploy with automatic RHACM import  
**Estimated Time**: 45-60 minutes for full test  
**Prerequisites**: Logged into RHACM hub cluster with valid AWS credentials

---

## ✅ Pre-Test Validation

**Before starting deployment, verify these prerequisites:**

### 1. Hub Cluster Access

```bash
# Verify you're logged into the hub cluster
oc whoami --show-server

# Expected output: https://api.cluster-d6zdt.dynamic.redhatworkshops.io:6443

# Verify RHACM is running
oc get multiclusterhub -n open-cluster-management

# Expected output:
# NAME              STATUS    AGE
# multiclusterhub   Running   Xd
```

**✅ PASS**: Hub cluster accessible and RHACM running  
**❌ FAIL**: Run `oc login <hub-api-url>` and retry

---

### 2. AWS Credentials

```bash
# Check secrets file exists
ls -lh ~/secrets-ec2.yml

# Verify AWS credentials work
aws sts get-caller-identity

# Expected output: Shows your AWS account info
```

**✅ PASS**: AWS credentials valid  
**❌ FAIL**: Run `./workshop-scripts/02-configure-aws-credentials.sh`

---

### 3. OpenShift Pull Secret

```bash
# Check pull secret exists
ls -lh ~/pull-secret.json

# Verify it's valid JSON
jq . ~/pull-secret.json | head -5

# Expected: Shows JSON with "auths" object
```

**⚠️ CRITICAL**: Pull secret must be fresh (less than 30 days old)

**❌ FAIL**: Get new pull secret:
1. Visit: https://console.redhat.com/openshift/install/pull-secret
2. Login with Red Hat account
3. Download pull secret
4. Save to `~/pull-secret.json`
5. Update `~/secrets-ec2.yml` with new pull secret

---

### 4. Clean Slate

```bash
# Check for existing test deployment
oc get managedcluster workshop-student1 2>&1

# Expected output: "Error from server (NotFound)" (good!)

# Check AWS for existing resources
aws ec2 describe-instances \
  --filters "Name=tag:guid,Values=test-student1" \
  --query 'Reservations[].Instances[].InstanceId' \
  --region us-east-2

# Expected output: [] (empty array)
```

**If resources exist**, clean them up:
```bash
./workshop-scripts/99-destroy-sno-complete.sh student1 rhpds
```

**Wait 5 minutes for full cleanup**, then verify again.

---

## 🧪 TEST 1: Single Student Deployment

**Objective**: Deploy one SNO cluster and verify RHACM auto-import works

### Step 1.1: Start Deployment

```bash
cd /home/lab-user/low-latency-performance-workshop

# Deploy for student1
./workshop-scripts/03-test-single-sno.sh student1 rhpds
```

**Expected output:**
```
============================================
 Test SNO Deployment
============================================

Student: student1
GUID: test-student1
Mode: rhpds

[1/5] Checking prerequisites...
✓ ansible-navigator available
✓ Secrets file exists
✓ AgnosticD repository found
✓ Logged into hub cluster: https://...
```

**Monitor deployment** (in another terminal):
```bash
# Watch log file
tail -f /tmp/test-student1.log
```

**⏱️ Estimated time**: 35-50 minutes

---

### Step 1.2: Monitor AWS Infrastructure (10-15 min)

```bash
# Check CloudFormation stack creation
watch -n 30 'aws cloudformation describe-stacks \
  --stack-name "$(aws cloudformation list-stacks \
  --query "StackSummaries[?contains(StackName, \"test-student1\")].StackName" \
  --output text 2>/dev/null | head -1)" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null'

# Expected progression:
# CREATE_IN_PROGRESS → CREATE_COMPLETE (10-15 min)
```

**✅ PASS**: Stack shows `CREATE_COMPLETE`  
**❌ FAIL**: Check `/tmp/test-student1.log` for errors

---

### Step 1.3: Monitor SNO Installation (20-30 min)

```bash
# Check for bastion instance
watch -n 30 'aws ec2 describe-instances \
  --filters "Name=tag:guid,Values=test-student1" \
            "Name=tag:Name,Values=bastion" \
  --query "Reservations[0].Instances[0].[PublicIpAddress,State.Name]" \
  --output table'

# Expected: Shows IP address and "running"
```

Once bastion is running, you can SSH to monitor OpenShift installation:

```bash
# Get bastion IP
BASTION_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:guid,Values=test-student1" \
            "Name=tag:Name,Values=bastion" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

# Get SSH key
SSH_KEY=~/agnosticd-output/test-student1/ssh_provision_test-student1

# SSH to bastion (if key exists)
ssh -i ${SSH_KEY} ec2-user@${BASTION_IP}

# On bastion, monitor install
tail -f ~/test-student1/.openshift_install.log
```

**OpenShift install phases:**
1. Bootstrap starts (5 min)
2. Bootstrap complete (15-20 min)
3. Cluster operators available (5-10 min)

**✅ PASS**: "Install complete!" message appears  
**❌ FAIL**: Check logs for specific error

---

### Step 1.4: Verify SNO Cluster (Expected: 40-45 min mark)

```bash
# Check if kubeconfig was created
ls -lh ~/agnosticd-output/test-student1/kubeconfig

# Access SNO cluster
export KUBECONFIG=~/agnosticd-output/test-student1/low-latency-workshop-sno_test-student1_kubeconfig

# Check node status
oc get nodes

# Expected output:
# NAME                      STATUS   ROLES                  AGE   VERSION
# ip-10-0-x-x...            Ready    control-plane,master   5m    v1.33.x

# Check cluster operators
oc get co

# Expected: All operators showing AVAILABLE=True
```

**✅ PASS**: All 34 cluster operators available  
**❌ FAIL**: Investigate operators not available:
```bash
oc get co | grep -v "True.*False.*False"
oc describe co <operator-name>
```

---

### Step 1.5: Verify RHACM Auto-Import (Expected: 45-50 min mark)

**Switch back to hub cluster:**
```bash
unset KUBECONFIG
oc whoami --show-server
# Should show hub cluster URL
```

**Check ManagedCluster creation:**
```bash
# Check if ManagedCluster exists
oc get managedcluster workshop-student1

# Expected output:
# NAME                HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE
# workshop-student1   true           https://api.test...    True     True
```

**Detailed status check:**
```bash
# Get detailed status
oc get managedcluster workshop-student1 -o yaml | grep -A 10 "conditions:"

# Look for:
# - type: ManagedClusterImportSucceeded
#   status: "True"
# - type: ManagedClusterConditionAvailable
#   status: "True"
```

**Check klusterlet on SNO:**
```bash
# Back to SNO cluster
export KUBECONFIG=~/agnosticd-output/test-student1/low-latency-workshop-sno_test-student1_kubeconfig

# Check klusterlet pods
oc get pods -n open-cluster-management-agent

# Expected: 3-4 pods all Running
```

---

### Step 1.6: Test Results

**Mark your test results:**

| Check | Status | Notes |
|-------|--------|-------|
| CloudFormation stack created | ⬜ | |
| Bastion instance running | ⬜ | |
| SNO node Ready | ⬜ | |
| All cluster operators Available | ⬜ | |
| ManagedCluster created on hub | ⬜ | |
| ManagedCluster shows Available=True | ⬜ | |
| Klusterlet pods Running on SNO | ⬜ | |

**✅ ALL PASSED**: RHACM auto-import is working! Proceed to TEST 2  
**❌ ANY FAILED**: See troubleshooting section below

---

## 🧪 TEST 2: Manual Import (If Auto-Import Failed)

**If Step 1.5 failed**, check if manual import script was generated:

```bash
# Check for manual import script
ls -lh /tmp/manual-import-workshop-student1.sh

# If exists, run it
/tmp/manual-import-workshop-student1.sh
```

**Expected output:**
```
╔════════════════════════════════════════════════════════════╗
║  TEST RHACM IMPORT - student1                              ║
╚════════════════════════════════════════════════════════════╝

[1/5] Verifying prerequisites...
✓ Logged into hub: ...
✓ SNO kubeconfig exists
✓ RHACM available

[2/5] Getting SNO cluster details...
✓ SNO API URL: ...
✓ SNO cluster accessible

[3/5] Extracting SNO service account token...
✓ Token extracted

[4/5] Creating RHACM resources on hub...
✓ All resources created

[5/5] Waiting for cluster import to complete...
.....
✓ Cluster import successful!
```

**If manual import succeeds**, auto-import has a bug that needs investigation.

---

## 🧪 TEST 3: Cleanup Validation

**After successful deployment**, test cleanup:

```bash
# Run cleanup
./workshop-scripts/99-destroy-sno-complete.sh student1 rhpds
```

**Monitor cleanup:**
```bash
# Watch ManagedCluster deletion
watch -n 10 'oc get managedcluster workshop-student1 2>&1'

# Expected: "Error from server (NotFound)" after 1-2 minutes
```

**Verify AWS cleanup:**
```bash
# Check CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE DELETE_IN_PROGRESS \
  --query 'StackSummaries[?contains(StackName, `test-student1`)].StackName'

# Expected: Empty array after 5-10 minutes

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:guid,Values=test-student1" \
  --query 'Reservations[].Instances[].InstanceId'

# Expected: Empty array

# Check Route53 records
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`test-student1.sandbox862.opentlc.com.`].Id'

# Expected: Empty array
```

**✅ PASS**: All resources deleted  
**❌ FAIL**: Run cleanup again or manually verify in AWS Console

---

## 🧪 TEST 4: Multi-Student Deployment (Optional)

**If TEST 1 passed**, validate batch deployment:

```bash
# Deploy 5 students in batch of 5
./workshop-scripts/04-provision-student-clusters.sh 5 5
```

**Monitor:**
```bash
# Watch ManagedClusters appear
watch -n 30 'oc get managedcluster -l workshop=low-latency'

# Expected: 5 clusters showing Available=True (after 45 min)
```

**Cleanup:**
```bash
# Delete all 5
./workshop-scripts/99-destroy-all-students.sh 1 5 rhpds
```

---

## 🔧 Troubleshooting Guide

### Issue: ManagedCluster Created but Not Available

**Check import status:**
```bash
oc get managedcluster workshop-student1 -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterImportSucceeded")].message}'
```

**Common causes:**

1. **"AutoImportSecretInvalid"**: Kubeconfig is malformed
   ```bash
   # Verify kubeconfig
   oc get secret auto-import-secret -n workshop-student1 -o jsonpath='{.data.kubeconfig}' | base64 -d | head -5
   ```

2. **"ImagePullBackOff"**: SNO can't pull RHACM images
   ```bash
   # Check pull secret on SNO
   export KUBECONFIG=~/agnosticd-output/test-student1/low-latency-workshop-sno_test-student1_kubeconfig
   oc get secret pull-secret -n openshift-config
   ```
   
   **Fix**: Get fresh pull secret from console.redhat.com

3. **"NetworkError"**: SNO can't reach registry.redhat.io
   ```bash
   # Test from SNO node
   ssh -i ~/agnosticd-output/test-student1/ssh_provision_* ec2-user@<bastion-ip>
   ssh core@<sno-node-ip>
   curl -I https://registry.redhat.io
   ```

---

### Issue: Deployment Hangs at Bootstrap

**Check bootstrap logs:**
```bash
# SSH to bastion
ssh -i ~/agnosticd-output/test-student1/ssh_provision_* ec2-user@<bastion-ip>

# View install log
tail -f ~/test-student1/.openshift_install.log

# Check for common errors:
# - "waiting for bootstrap to complete"
# - "bootstrap service not ready"
```

**Common fixes:**
- Check AWS quotas (vCPU limits)
- Verify pull secret is valid
- Check AWS service status

---

### Issue: Cleanup Fails

**Check what's stuck:**
```bash
# Check CloudFormation stack
aws cloudformation describe-stacks \
  --stack-name <stack-name> \
  --query 'Stacks[0].StackStatus'

# If DELETE_FAILED, check events
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`]'
```

**Manual cleanup if needed:**
```bash
# Force delete VPC dependencies
aws ec2 describe-vpcs \
  --filters "Name=tag:guid,Values=test-student1" \
  --query 'Vpcs[0].VpcId'

# Use AWS Console to manually delete VPC and dependencies
```

---

## 📝 Test Results Summary

**Date**: ___________  
**Tester**: ___________

### Test 1: Single Deployment
- [ ] Infrastructure created (10-15 min)
- [ ] SNO installed (30-40 min)
- [ ] Auto-import succeeded (45-50 min)
- [ ] All cluster operators available
- [ ] ManagedCluster shows Available=True

### Test 2: Manual Import (if needed)
- [ ] Manual import script generated
- [ ] Manual import succeeded
- [ ] Root cause identified

### Test 3: Cleanup
- [ ] ManagedCluster deleted from hub
- [ ] AWS resources fully cleaned up
- [ ] No orphaned resources

### Test 4: Multi-Student (optional)
- [ ] 5 clusters deployed successfully
- [ ] All show Available=True
- [ ] Bulk cleanup succeeded

---

## ✅ Sign-Off

**Production Ready**: YES / NO  
**Issues Found**: ___________  
**Notes**: ___________

---

*Last Updated: November 28, 2025*

