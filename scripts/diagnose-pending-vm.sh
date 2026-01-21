#!/bin/bash
# Diagnostic script for VM stuck in Pending state on m5zn.metal instance
# This script checks common causes of VM scheduling failures

set -e

echo "=========================================="
echo "VM Pending State Diagnostic Tool"
echo "=========================================="
echo ""

# Check if connected to cluster
if ! oc whoami &>/dev/null; then
    echo "❌ ERROR: Not connected to OpenShift cluster"
    echo "   Please set KUBECONFIG or login to your cluster first"
    exit 1
fi

echo "✅ Connected to cluster: $(oc whoami)"
echo ""

# Get VM name and namespace from user or use defaults
NAMESPACE="${1:-default}"
VM_NAME="${2}"

if [ -z "$VM_NAME" ]; then
    echo "Checking all VMs in namespace: $NAMESPACE"
    echo ""
    echo "=== All VMs in $NAMESPACE ==="
    oc get vm -n "$NAMESPACE" 2>/dev/null || echo "No VMs found or namespace doesn't exist"
    echo ""
    echo "Usage: $0 <namespace> <vm-name>"
    echo "Example: $0 default my-vm"
    echo ""
    echo "Or run without VM name to see all VMs"
    exit 0
fi

echo "Diagnosing VM: $VM_NAME in namespace: $NAMESPACE"
echo ""

# 1. Check VM status
echo "=== 1. VM Status ==="
oc get vm "$VM_NAME" -n "$NAMESPACE" 2>/dev/null || {
    echo "❌ VM not found: $VM_NAME in namespace $NAMESPACE"
    exit 1
}
echo ""

# 2. Check VMI status
echo "=== 2. VMI (VirtualMachineInstance) Status ==="
VMI_STATUS=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")
if [ "$VMI_STATUS" = "NOT_FOUND" ]; then
    echo "⚠️  VMI not created yet (VM may not be started)"
    echo "   To start VM: oc patch vm $VM_NAME -n $NAMESPACE --type merge -p '{\"spec\":{\"running\":true}}'"
else
    oc get vmi "$VM_NAME" -n "$NAMESPACE"
    echo ""
    echo "VMI Phase: $VMI_STATUS"
    if [ "$VMI_STATUS" = "Pending" ]; then
        echo "⚠️  VMI is stuck in Pending state"
    fi
fi
echo ""

# 3. Check DataVolume status (if VM uses DataVolumes)
echo "=== 3. DataVolume Status ==="
DV_LIST=$(oc get dv -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$DV_LIST" ]; then
    for dv in $DV_LIST; do
        if echo "$dv" | grep -q "$VM_NAME"; then
            echo "Found DataVolume: $dv"
            oc get dv "$dv" -n "$NAMESPACE"
            DV_PHASE=$(oc get dv "$dv" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            echo "  Phase: $DV_PHASE"
            if [ "$DV_PHASE" = "Pending" ] || [ "$DV_PHASE" = "WaitForFirstConsumer" ]; then
                echo "  ⚠️  DataVolume is pending - this may block VM startup"
                echo "  Checking PVC status..."
                PVC_NAME=$(oc get dv "$dv" -n "$NAMESPACE" -o jsonpath='{.status.pvc}' 2>/dev/null || echo "")
                if [ -n "$PVC_NAME" ]; then
                    oc get pvc "$PVC_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  PVC not found"
                fi
            fi
            echo ""
        fi
    done
else
    echo "No DataVolumes found (VM may use containerDisk)"
fi
echo ""

# 4. Check PVC status
echo "=== 4. PVC (PersistentVolumeClaim) Status ==="
PVC_LIST=$(oc get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PVC_LIST" ]; then
    for pvc in $PVC_LIST; do
        if echo "$pvc" | grep -q "$VM_NAME"; then
            echo "Found PVC: $pvc"
            oc get pvc "$pvc" -n "$NAMESPACE"
            PVC_STATUS=$(oc get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            echo "  Phase: $PVC_STATUS"
            if [ "$PVC_STATUS" = "Pending" ]; then
                echo "  ⚠️  PVC is pending - checking events..."
                oc get events -n "$NAMESPACE" --field-selector involvedObject.name="$pvc" --sort-by='.lastTimestamp' | tail -5
            fi
            echo ""
        fi
    done
else
    echo "No PVCs found for this VM"
fi
echo ""

# 5. Check virt-launcher pod status
echo "=== 5. virt-launcher Pod Status ==="
POD_LIST=$(oc get pods -n "$NAMESPACE" -l kubevirt.io/created-by="$VM_NAME" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_LIST" ]; then
    for pod in $POD_LIST; do
        echo "Found pod: $pod"
        oc get pod "$pod" -n "$NAMESPACE"
        POD_PHASE=$(oc get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "  Phase: $POD_PHASE"
        if [ "$POD_PHASE" = "Pending" ]; then
            echo "  ⚠️  Pod is pending - checking why..."
            echo ""
            echo "  Pod Events:"
            oc describe pod "$pod" -n "$NAMESPACE" | grep -A 10 "Events:" || echo "  No events found"
            echo ""
            echo "  Pod Conditions:"
            oc get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[*].type}{"\t"}{.status.conditions[*].status}{"\n"}' | column -t || true
        fi
        echo ""
    done
else
    echo "No virt-launcher pod found (VMI may not be created yet)"
fi
echo ""

# 6. Check node resources
echo "=== 6. Node Resources ==="
NODE_NAME=$(oc get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$NODE_NAME" ]; then
    echo "Node: $NODE_NAME"
    echo ""
    echo "Node Conditions:"
    oc describe node "$NODE_NAME" | grep -A 5 "Conditions:" || true
    echo ""
    echo "Allocatable Resources:"
    oc get node "$NODE_NAME" -o jsonpath='{.status.allocatable}' | jq '.' 2>/dev/null || oc get node "$NODE_NAME" -o jsonpath='{.status.allocatable}'
    echo ""
    echo "Current Resource Usage:"
    oc adm top node "$NODE_NAME" 2>/dev/null || echo "  Metrics not available (may need metrics-server)"
fi
echo ""

# 7. Check HyperConverged/KubeVirt configuration (for bare-metal instances)
echo "=== 7. OpenShift Virtualization Configuration ==="
echo "Checking if emulation is enabled (should be FALSE for m5zn.metal bare-metal instance)..."
echo ""

# Check KubeVirt CR
KUBEVIRT_EMULATION=$(oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}' 2>/dev/null || echo "NOT_FOUND")
if [ "$KUBEVIRT_EMULATION" = "NOT_FOUND" ]; then
    echo "⚠️  KubeVirt CR not found or not accessible"
elif [ "$KUBEVIRT_EMULATION" = "true" ]; then
    echo "❌ PROBLEM FOUND: Emulation is ENABLED"
    echo "   For m5zn.metal (bare-metal), emulation should be DISABLED"
    echo "   This can cause VMs to fail to start or perform poorly"
    echo ""
    echo "   To fix: Ensure GitOps uses 'standard' overlay (not 'sno' overlay)"
    echo "   Check: gitops/openshift-virtualization/instance/overlays/"
elif [ "$KUBEVIRT_EMULATION" = "false" ] || [ -z "$KUBEVIRT_EMULATION" ]; then
    echo "✅ Emulation is disabled (correct for bare-metal)"
else
    echo "   Emulation setting: $KUBEVIRT_EMULATION"
fi
echo ""

# Check HyperConverged status
echo "HyperConverged Operator Status:"
oc get hyperconverged -n openshift-cnv 2>/dev/null || echo "  HyperConverged CR not found"
echo ""

# 8. Check recent events
echo "=== 8. Recent Events for VM ==="
echo "Events related to $VM_NAME:"
oc get events -n "$NAMESPACE" --field-selector involvedObject.name="$VM_NAME" --sort-by='.lastTimestamp' | tail -10 || echo "  No events found"
echo ""

# 9. Summary and recommendations
echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""

# Collect key statuses
VMI_PHASE=$(oc get vmi "$VM_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")
POD_PHASE=$(oc get pods -n "$NAMESPACE" -l kubevirt.io/created-by="$VM_NAME" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NOT_FOUND")

echo "Key Statuses:"
echo "  VMI Phase: $VMI_PHASE"
echo "  Pod Phase: $POD_PHASE"
echo "  Emulation: $KUBEVIRT_EMULATION"
echo ""

echo "Common Issues and Solutions:"
echo ""
echo "1. DataVolume/PVC Pending:"
echo "   - Check storage class: oc get storageclass"
echo "   - Check PVC events: oc describe pvc <pvc-name> -n $NAMESPACE"
echo "   - May need to wait for image import to complete"
echo ""
echo "2. Pod Cannot Schedule:"
echo "   - Check node resources: oc describe node <node-name>"
echo "   - Check taints/tolerations: oc get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints"
echo "   - Check resource requests vs available"
echo ""
echo "3. Emulation Enabled on Bare-Metal:"
echo "   - For m5zn.metal, ensure GitOps uses 'standard' overlay"
echo "   - Check: gitops/openshift-virtualization/instance/overlays/baremetal/"
echo "   - Emulation should be disabled for native KVM"
echo ""
echo "4. VM Not Started:"
echo "   - Start VM: oc patch vm $VM_NAME -n $NAMESPACE --type merge -p '{\"spec\":{\"running\":true}}'"
echo ""
echo "For detailed VM description:"
echo "  oc describe vm $VM_NAME -n $NAMESPACE"
echo "  oc describe vmi $VM_NAME -n $NAMESPACE"
echo ""
