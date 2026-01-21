# Troubleshooting: VM Stuck in Pending State on m5zn.metal

## Quick Diagnosis

Run the diagnostic script to identify the issue:

```bash
# Check all VMs
./scripts/diagnose-pending-vm.sh <namespace>

# Diagnose specific VM
./scripts/diagnose-pending-vm.sh <namespace> <vm-name>
```

## Common Causes and Solutions

### 1. **Wrong GitOps Overlay (Most Common for m5zn.metal)**

**Problem**: The ArgoCD application is configured to use the `sno` overlay, which enables software emulation. For bare-metal instances (m5zn.metal), you need the `standard` overlay that uses native KVM.

**Symptoms**:
- VM stuck in Pending state
- VMI cannot start
- Emulation is enabled when it shouldn't be

**Solution**:

1. **Check current configuration**:
```bash
# Check which overlay is being used
oc get application openshift-virtualization-instance -n openshift-gitops -o jsonpath='{.spec.source.path}'

# Check if emulation is enabled (should be false for bare-metal)
oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
```

2. **Fix the ArgoCD application**:
```bash
# Edit the ArgoCD application to use 'baremetal' overlay for bare-metal
oc patch application openshift-virtualization-instance -n openshift-gitops --type json -p '[
  {
    "op": "replace",
    "path": "/spec/source/path",
    "value": "gitops/openshift-virtualization/instance/overlays/baremetal"
  }
]'

# Sync the application
oc patch application openshift-virtualization-instance -n openshift-gitops --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}'
```

3. **Or manually update the file**:
```bash
# Edit: argocd-apps/openshift-virtualization-instance.yaml
# Change line 13 from:
#   path: gitops/openshift-virtualization/instance/overlays/virtualized
# To:
#   path: gitops/openshift-virtualization/instance/overlays/baremetal

# Then apply:
oc apply -f argocd-apps/openshift-virtualization-instance.yaml
```

4. **Verify emulation is disabled**:
```bash
# Wait a few minutes for sync, then check
oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
# Should return: false (or empty, which means disabled)
```

5. **Restart the VM**:
```bash
# Delete the stuck VMI
oc delete vmi <vm-name> -n <namespace> --force --grace-period=0

# Restart the VM
oc patch vm <vm-name> -n <namespace> --type merge -p '{"spec":{"running":true}}'
```

---

### 2. **DataVolume/PVC Pending**

**Problem**: The DataVolume is waiting for storage or image import.

**Symptoms**:
- DataVolume phase is `Pending` or `WaitForFirstConsumer`
- PVC is `Pending`
- VM cannot start because disk is not ready

**Solution**:

```bash
# Check DataVolume status
oc get dv -n <namespace>

# Check PVC status
oc get pvc -n <namespace>

# Check storage class
oc get storageclass

# Check PVC events for errors
oc describe pvc <pvc-name> -n <namespace>

# If PVC is pending due to storage class issues:
# 1. Check available storage classes
oc get storageclass

# 2. If using wrong storage class, delete and recreate with correct one
# Or patch the DataVolume to use correct storage class
```

**Common Issues**:
- **No default storage class**: Set a default storage class
- **Storage class not available**: Check node capabilities
- **Image import taking time**: Wait for import to complete (can take 5-15 minutes)

---

### 3. **Node Resource Constraints**

**Problem**: The node doesn't have enough CPU, memory, or other resources.

**Symptoms**:
- Pod is `Pending`
- Events show "Insufficient resources"
- Node conditions show resource pressure

**Solution**:

```bash
# Check node resources
oc describe node <node-name>

# Check allocatable resources
oc get node <node-name> -o jsonpath='{.status.allocatable}' | jq '.'

# Check current usage
oc adm top node <node-name>

# Check for resource pressure
oc describe node <node-name> | grep -A 10 "Conditions:"

# Check pod resource requests
oc get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}' | jq '.'

# If resources are constrained:
# 1. Reduce VM resource requests
# 2. Delete other workloads
# 3. Scale down other VMs
```

---

### 4. **Scheduling Issues (Taints/Tolerations)**

**Problem**: Node has taints that prevent pod scheduling.

**Symptoms**:
- Pod events show "No nodes available"
- Node has taints but pod lacks tolerations

**Solution**:

```bash
# Check node taints
oc get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Check pod tolerations
oc get pod <pod-name> -n <namespace> -o jsonpath='{.spec.tolerations}' | jq '.'

# If node has taints, add tolerations to VM spec:
# In VM YAML, add to template.spec:
# tolerations:
#   - key: <taint-key>
#     operator: Equal
#     value: <taint-value>
#     effect: NoSchedule
```

---

### 5. **VM Not Started**

**Problem**: The VM object exists but `running: false`.

**Symptoms**:
- VM status shows `Stopped`
- No VMI created

**Solution**:

```bash
# Check VM status
oc get vm <vm-name> -n <namespace>

# Start the VM
oc patch vm <vm-name> -n <namespace> --type merge -p '{"spec":{"running":true}}'

# Or set running: true in VM YAML
```

---

## Step-by-Step Troubleshooting

1. **Run diagnostic script**:
```bash
./scripts/diagnose-pending-vm.sh <namespace> <vm-name>
```

2. **Check VM and VMI status**:
```bash
oc get vm <vm-name> -n <namespace>
oc get vmi <vm-name> -n <namespace>
oc describe vm <vm-name> -n <namespace>
oc describe vmi <vm-name> -n <namespace>
```

3. **Check pod status**:
```bash
oc get pods -n <namespace> -l kubevirt.io/created-by=<vm-name>
oc describe pod <pod-name> -n <namespace>
oc logs <pod-name> -n <namespace>
```

4. **Check events**:
```bash
oc get events -n <namespace> --field-selector involvedObject.name=<vm-name> --sort-by='.lastTimestamp'
```

5. **Check OpenShift Virtualization configuration**:
```bash
# For m5zn.metal, emulation should be DISABLED
oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'

# Check HyperConverged status
oc get hyperconverged -n openshift-cnv
oc describe hyperconverged kubevirt-hyperconverged -n openshift-cnv
```

6. **Check node status**:
```bash
NODE_NAME=$(oc get nodes -o jsonpath='{.items[0].metadata.name}')
oc describe node $NODE_NAME
oc get node $NODE_NAME -o yaml | grep -A 20 "allocatable"
```

---

## Verification After Fix

After applying fixes, verify the VM can start:

```bash
# 1. Ensure emulation is disabled (for bare-metal)
oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}'
# Should be: false or empty

# 2. Start the VM
oc patch vm <vm-name> -n <namespace> --type merge -p '{"spec":{"running":true}}'

# 3. Watch VMI status
watch -n 2 'oc get vmi <vm-name> -n <namespace>'

# 4. Check VMI reaches Running state
oc wait --for=condition=Ready vmi/<vm-name> -n <namespace> --timeout=300s

# 5. Verify VM is accessible
oc get vmi <vm-name> -n <namespace> -o jsonpath='{.status.phase}'
# Should be: Running
```

---

## Quick Reference: Overlay Selection

| Instance Type | Overlay | Emulation | Use Case |
|--------------|---------|-----------|----------|
| **m5.4xlarge** (virtualized) | `sno` | Enabled | Software emulation |
| **m5zn.metal** (bare-metal) | `standard` | Disabled | Native KVM |
| **c5.metal** (bare-metal) | `standard` | Disabled | Native KVM |
| **Any .metal** (bare-metal) | `standard` | Disabled | Native KVM |

---

## Additional Resources

- [OpenShift Virtualization Documentation](https://docs.openshift.com/container-platform/latest/virt/)
- [KubeVirt Troubleshooting Guide](https://kubevirt.io/user-guide/operations/troubleshooting/)
- Workshop Module 5: `content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc`
