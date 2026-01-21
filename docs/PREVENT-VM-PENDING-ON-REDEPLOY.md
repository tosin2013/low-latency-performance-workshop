# Preventing VM Pending Issue on Redeploy

## Problem

When redeploying with a **bare-metal instance** (m5zn.metal), VMs can get stuck in Pending state because the ArgoCD application is configured to use the wrong GitOps overlay.

## Root Cause

The ArgoCD application (`argocd-apps/openshift-virtualization-instance.yaml`) was hardcoded to use the `virtualized` overlay, which:
- ✅ **Correct** for virtualized instances (m5.4xlarge) - enables emulation
- ❌ **Wrong** for bare-metal instances (m5zn.metal) - should use native KVM

## Solution

### ✅ **Automatic Fix (Recommended)**

The deployment script (`scripts/deploy-sno-dev.sh`) has been **updated** to automatically configure the correct overlay based on instance type:

```bash
# Deploy with bare-metal - script will automatically use 'baremetal' overlay
./scripts/deploy-sno-dev.sh dev1 sandbox3576 baremetal

# Deploy with virtualized - script will automatically use 'virtualized' overlay  
./scripts/deploy-sno-dev.sh dev1 sandbox3576 virtualized
```

The script now:
1. Detects the instance type (baremetal vs virtualized)
2. Updates the ArgoCD application to use the correct overlay
3. Configures emulation appropriately

### 🔧 **Manual Fix (If Needed)**

If you need to manually fix the ArgoCD application:

**For Bare-Metal (m5zn.metal):**
```bash
oc patch application openshift-virtualization-instance -n openshift-gitops --type json -p '[
  {
    "op": "replace",
    "path": "/spec/source/path",
    "value": "gitops/openshift-virtualization/instance/overlays/baremetal"
  }
]'
```

**For Virtualized (m5.4xlarge):**
```bash
oc patch application openshift-virtualization-instance -n openshift-gitops --type json -p '[
  {
    "op": "replace",
    "path": "/spec/source/path",
    "value": "gitops/openshift-virtualization/instance/overlays/virtualized"
  }
]'
```

### 📝 **Update Source File (Permanent Fix)**

To make the fix permanent in your Git repository:

1. **For bare-metal deployments**, edit `argocd-apps/openshift-virtualization-instance.yaml`:
```yaml
# Change line 13 from:
path: gitops/openshift-virtualization/instance/overlays/virtualized

# To:
path: gitops/openshift-virtualization/instance/overlays/baremetal
```

2. **Commit and push** the change

## Verification

After deployment or fix, verify the configuration:

```bash
# 1. Check ArgoCD application path
oc get application openshift-virtualization-instance -n openshift-gitops -o jsonpath='{.spec.source.path}'
# Should show: gitops/openshift-virtualization/instance/overlays/baremetal (for bare-metal)

# 2. Check if emulation is disabled (for bare-metal)
oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
# Should return: false or empty (not true)

# 3. Verify VMs can start
oc patch vm <vm-name> -n <namespace> --type merge -p '{"spec":{"running":true}}'
oc wait --for=condition=Ready vmi/<vm-name> -n <namespace> --timeout=300s
```

## Overlay Selection Reference

| Instance Type | Overlay | Emulation | Use Case |
|--------------|---------|-----------|----------|
| **m5.4xlarge** (virtualized) | `virtualized` | Enabled | Software emulation required |
| **m5zn.metal** (bare-metal) | `baremetal` | Disabled | Native KVM |
| **c5.metal** (bare-metal) | `baremetal` | Disabled | Native KVM |
| **Any .metal** (bare-metal) | `baremetal` | Disabled | Native KVM |

## Summary

✅ **Fixed**: Deployment script now automatically configures the correct overlay  
✅ **Prevention**: Script checks and updates ArgoCD application during deployment  
✅ **Verification**: Script provides clear feedback on configuration  

**Result**: The VM pending issue will **NOT occur again** when redeploying with the updated script.
