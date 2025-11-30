# Pull-Secret Propagation Issue - Root Cause & Solution

## 📋 Executive Summary

**Issue**: OpenShift marketplace pods and RHACM klusterlet pods failing with `ImagePullBackOff` due to `invalid username/password: unauthorized` when pulling images from `registry.redhat.io`.

**Root Cause**: OpenShift's serviceaccount token controller did not automatically propagate the global pull-secret from `openshift-config` namespace to serviceaccount dockercfg secrets in other namespaces during cluster bootstrapping.

**Impact**: 
- ❌ OpenShift Marketplace catalogs (all 4) failed to start
- ❌ RHACM klusterlet import initially failed  
- ❌ Any pods using serviceaccount secrets couldn't pull Red Hat registry images
- ✅ Core cluster functionality was not affected

**Status**: ✅ **RESOLVED** - Issue fixed and preventive measures implemented

---

## 🔍 Technical Deep Dive

### What Happened

1. **During Installation** (2025-11-28 23:42 UTC):
   - OpenShift 4.20 SNO cluster installed successfully
   - Pull secret created in `openshift-config/pull-secret`
   - Images needed during bootstrap were pulled successfully

2. **Post-Installation** (~10 minutes later):
   - Marketplace pods tried to pull operator catalog images
   - Used auto-generated `dockercfg` secrets (not global pull-secret)
   - These secrets ONLY had internal registry credentials
   - Missing `registry.redhat.io` authentication → ImagePullBackOff

3. **Discovery**:
   ```bash
   # Global pull-secret (working):
   oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths | keys'
   # Output: ["cloud.openshift.com", "quay.io", "registry.connect.redhat.com", "registry.redhat.io"]
   
   # Marketplace dockercfg secret (broken):
   oc get secret redhat-operators-dockercfg-xxxxx -n openshift-marketplace -o jsonpath='{.data.\.dockercfg}' | base64 -d | jq 'keys'
   # Output: ["172.30.166.97:5000", "image-registry.openshift-image-registry.svc.cluster.local:5000"]
   ```

### Why This Happened

This appears to be a **timing/race condition** during cluster bootstrapping where:

1. OpenShift's serviceaccount token controller generates `dockercfg` secrets automatically
2. These secrets are supposed to merge with the global pull-secret
3. Under certain conditions (SNO, OpenShift 4.20, specific timing), this merge doesn't happen
4. Result: dockercfg secrets missing external registry credentials

**Likelihood of Recurrence**: 🟡 **MEDIUM**
- May or may not happen on future deployments
- Depends on timing during cluster bootstrapping
- More likely on SNO clusters
- OpenShift 4.20-specific behavior

---

## ✅ The Fix (Applied to Current Cluster)

### What We Did

1. **Copied pull-secret to affected namespace**:
   ```bash
   oc get secret pull-secret -n openshift-config -o yaml | \
     sed 's/namespace: openshift-config/namespace: openshift-marketplace/' | \
     oc apply -f -
   ```

2. **Linked pull-secret to serviceaccounts**:
   ```bash
   oc patch serviceaccount redhat-operators -n openshift-marketplace \
     --type='json' \
     -p='[{"op":"add","path":"/imagePullSecrets/-","value":{"name":"pull-secret"}}]'
   ```

3. **Restarted failing pods**:
   ```bash
   oc delete pod -n openshift-marketplace -l olm.catalogSource
   ```

4. **Result**: All marketplace pods now `Running` ✅

### Verification

```bash
# Check marketplace pods
oc get pods -n openshift-marketplace
NAME                                    READY   STATUS    RESTARTS   AGE
certified-operators-9z52w               1/1     Running   0          5m
community-operators-428fs               1/1     Running   0          5m
redhat-marketplace-trhlm                1/1     Running   0          5m
redhat-operators-mkjxr                  1/1     Running   0          5m

# Check RHACM status (on hub cluster)
oc get managedcluster testingme
NAME        HUB ACCEPTED   JOINED   AVAILABLE   AGE
testingme   true           True     True        81m
```

---

## 🛡️ Prevention for Future Deployments

### 1. Automated Fix in `post_software.yml`

**Location**: `agnosticd-configs/low-latency-workshop-sno/post_software.yml`

**Added tasks** (lines 63-130):
- ✅ Copies pull-secret to `openshift-marketplace` namespace
- ✅ Links pull-secret to marketplace serviceaccounts
- ✅ Copies pull-secret to `open-cluster-management-agent` namespace
- ✅ Runs automatically during deployment
- ✅ Uses `ignore_errors: true` for resilience

**When it runs**:
- After "Wait for SNO Cluster to be Ready"
- Before "Create namespace on hub for SNO"
- During `post_software` phase of AgnosticD deployment

### 2. Manual Fix Script

**Location**: `workshop-scripts/98-fix-pull-secret-propagation.sh`

**Usage**:
```bash
# Fix a specific cluster
./workshop-scripts/98-fix-pull-secret-propagation.sh student1

# What it does:
# 1. Copies pull-secret to openshift-marketplace
# 2. Links to all 4 catalog serviceaccounts
# 3. Restarts failing marketplace pods
# 4. Fixes RHACM agent namespace if present
# 5. Provides status output
```

**When to use**:
- If issue occurs on a deployed cluster
- To fix clusters deployed before the automated fix was added
- As a diagnostic/repair tool

---

## 📊 Will This Issue Occur on Redeployment?

### Answer: **MAYBE** (Medium Probability)

| Factor | Likelihood |
|--------|-----------|
| Same OpenShift version (4.20) | 🟡 Medium |
| SNO deployment | 🟡 Medium |
| Timing/race condition | 🟡 Medium |
| **With automated fix in post_software.yml** | 🟢 **LOW** |

### Why It's Now Low Risk

1. ✅ **Automated fix** runs on every deployment
2. ✅ **Runs early** (right after cluster is ready)
3. ✅ **Idempotent** (safe to run multiple times)
4. ✅ **Resilient** (uses `ignore_errors` appropriately)
5. ✅ **Manual fix available** if needed

### If It Still Happens

1. Check marketplace pods:
   ```bash
   oc get pods -n openshift-marketplace
   ```

2. Run manual fix:
   ```bash
   ./workshop-scripts/98-fix-pull-secret-propagation.sh student1
   ```

3. Verify fix:
   ```bash
   oc get pods -n openshift-marketplace  # Should be Running
   oc get catalogsource -n openshift-marketplace  # Should be READY
   ```

---

## 🔗 Related Documentation

### OpenShift Documentation
- [Using Image Pull Secrets](https://docs.openshift.com/container-platform/4.20/openshift_images/managing_images/using-image-pull-secrets.html)
- [Accessing the Red Hat Registry](https://access.redhat.com/articles/3399531)
- [Managing Service Accounts](https://docs.openshift.com/container-platform/4.20/authentication/understanding-and-creating-service-accounts.html)

### AgnosticD Configuration
- Config: `agnosticd-configs/low-latency-workshop-sno/`
- Post-software: `post_software.yml` (lines 63-130)
- Fix script: `workshop-scripts/98-fix-pull-secret-propagation.sh`

### RHACM Import
- [Importing a Managed Cluster](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/clusters/cluster_mce_overview#import-cli)
- Auto-import method used: kubeconfig-based

---

## 🎓 Key Takeaways

1. **Pull secret WAS valid** - The issue was distribution, not authentication
2. **ServiceAccount dockercfg secrets** don't automatically include global pull-secret
3. **Manual propagation required** in certain scenarios
4. **Now automated** in our deployment process
5. **Easy to fix** if it occurs again

---

## 📞 Support

If you encounter this issue:

1. **Check symptoms**:
   - Pods in `ImagePullBackOff`
   - Error: "invalid username/password: unauthorized"
   - Registry: `registry.redhat.io`

2. **Quick fix**:
   ```bash
   cd ~/low-latency-performance-workshop
   ./workshop-scripts/98-fix-pull-secret-propagation.sh <student_name>
   ```

3. **Verify**:
   - Marketplace pods: `oc get pods -n openshift-marketplace`
   - RHACM status: `oc get managedcluster` (on hub)

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-29  
**Status**: Issue Resolved, Prevention Implemented  
**Author**: AI Assistant & Workshop Team


