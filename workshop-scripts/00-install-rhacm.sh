#!/bin/bash
# Install Red Hat Advanced Cluster Management (RHACM) on the hub cluster
# This script is idempotent - safe to re-run
#
# Usage:
#   ./00-install-rhacm.sh [--skip-wait]
#
# Options:
#   --skip-wait    Don't wait for RHACM to be fully ready (useful for CI)
#
# Prerequisites:
#   - Logged into OpenShift cluster with cluster-admin

set -e

WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
SKIP_WAIT=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-wait)
            SKIP_WAIT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-wait]"
            echo ""
            echo "Install RHACM on the hub cluster."
            echo ""
            echo "Options:"
            echo "  --skip-wait    Don't wait for RHACM to be fully ready"
            exit 0
            ;;
    esac
done

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     RHACM INSTALLATION                                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/4] Checking prerequisites..."

# Check oc CLI
if ! command -v oc &> /dev/null; then
    echo "✗ oc CLI not found"
    exit 1
fi
echo "✓ oc CLI available"

# Check cluster access
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into OpenShift cluster"
    echo "Run: oc login <cluster-api-url>"
    exit 1
fi
CLUSTER_API=$(oc whoami --show-server)
CLUSTER_USER=$(oc whoami)
echo "✓ Logged into cluster: ${CLUSTER_API}"
echo "  User: ${CLUSTER_USER}"

# Check cluster-admin access
if ! oc auth can-i create namespace &> /dev/null; then
    echo "✗ Insufficient permissions (need cluster-admin)"
    exit 1
fi
echo "✓ Cluster-admin access confirmed"

# ============================================
# Check if RHACM already installed
# ============================================
echo ""
echo "[2/4] Checking existing RHACM installation..."

if oc get multiclusterhub multiclusterhub -n open-cluster-management &> /dev/null; then
    MCH_STATUS=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "✓ RHACM already installed (Status: ${MCH_STATUS})"
    
    if [ "${MCH_STATUS}" == "Running" ]; then
        echo ""
        echo "RHACM is fully operational. No action needed."
        echo ""
        RHACM_CONSOLE=$(oc get route multicloud-console -n open-cluster-management -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "${RHACM_CONSOLE}" ]; then
            echo "RHACM Console: https://${RHACM_CONSOLE}"
        fi
        exit 0
    else
        echo "⚠ RHACM installed but not fully ready. Waiting..."
    fi
else
    echo "  RHACM not installed. Proceeding with installation..."
fi

# ============================================
# Install RHACM Operator
# ============================================
echo ""
echo "[3/4] Installing RHACM Operator..."

# Apply operator resources using kustomize
if [ -d "${WORKSHOP_DIR}/gitops/rhacm-operator" ]; then
    echo "  Using GitOps resources from ${WORKSHOP_DIR}/gitops/rhacm-operator"
    oc apply -k ${WORKSHOP_DIR}/gitops/rhacm-operator
else
    echo "  Creating RHACM operator resources..."
    
    # Create namespace
    cat << EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: open-cluster-management
  labels:
    openshift.io/cluster-monitoring: "true"
EOF

    # Create OperatorGroup
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: open-cluster-management
  namespace: open-cluster-management
spec:
  targetNamespaces:
    - open-cluster-management
EOF

    # Create Subscription
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: advanced-cluster-management
  namespace: open-cluster-management
spec:
  channel: release-2.12
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
fi

echo "✓ RHACM Operator subscription created"

# Wait for operator to be ready
echo "  Waiting for RHACM operator to install..."
for i in {1..60}; do
    CSV_NAME=$(oc get csv -n open-cluster-management -o name 2>/dev/null | grep advanced-cluster-management || echo "")
    if [ -n "${CSV_NAME}" ]; then
        CSV_STATUS=$(oc get ${CSV_NAME} -n open-cluster-management -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [ "${CSV_STATUS}" == "Succeeded" ]; then
            echo "✓ RHACM Operator installed successfully"
            break
        fi
    fi
    if [ $i -eq 60 ]; then
        echo "⚠ Operator installation taking longer than expected"
        echo "  Check: oc get csv -n open-cluster-management"
        if [ "${SKIP_WAIT}" == "true" ]; then
            echo "  Continuing anyway (--skip-wait specified)"
        else
            exit 1
        fi
    fi
    sleep 10
done

# ============================================
# Create MultiClusterHub Instance
# ============================================
echo ""
echo "[4/4] Creating MultiClusterHub instance..."

# Wait for CRD
echo "  Waiting for MultiClusterHub CRD..."
for i in {1..30}; do
    if oc get crd multiclusterhubs.operator.open-cluster-management.io &>/dev/null; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ MultiClusterHub CRD not available after 5 minutes"
        exit 1
    fi
    sleep 10
done

# Apply MCH instance
if [ -d "${WORKSHOP_DIR}/gitops/rhacm-instance" ]; then
    echo "  Using GitOps resources from ${WORKSHOP_DIR}/gitops/rhacm-instance"
    oc apply -k ${WORKSHOP_DIR}/gitops/rhacm-instance
else
    cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec:
  availabilityConfig: Basic
  enableClusterBackup: false
EOF
fi

echo "✓ MultiClusterHub instance created"

# Wait for MCH to be ready
if [ "${SKIP_WAIT}" == "false" ]; then
    echo ""
    echo "Waiting for RHACM to be fully ready (this may take 10-15 minutes)..."
    for i in {1..90}; do
        MCH_STATUS=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [ "${MCH_STATUS}" == "Running" ]; then
            echo "✓ RHACM is fully operational!"
            break
        fi
        if [ $((i % 6)) -eq 0 ]; then
            echo "  Status: ${MCH_STATUS} (${i}0 seconds elapsed)"
        fi
        if [ $i -eq 90 ]; then
            echo "⚠ RHACM taking longer than expected"
            echo "  Current status: ${MCH_STATUS}"
            echo "  Check: oc get multiclusterhub -n open-cluster-management"
        fi
        sleep 10
    done
fi

# ============================================
# Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     RHACM INSTALLATION COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

RHACM_CONSOLE=$(oc get route multicloud-console -n open-cluster-management -o jsonpath='{.spec.host}' 2>/dev/null || echo "pending...")
MCH_STATUS=$(oc get multiclusterhub multiclusterhub -n open-cluster-management -o jsonpath='{.status.phase}' 2>/dev/null || echo "Installing")

echo "Status: ${MCH_STATUS}"
echo "RHACM Console: https://${RHACM_CONSOLE}"
echo ""
echo "Next Steps:"
echo "  1. Access RHACM console"
echo "  2. Setup hub users: ./05-setup-hub-users.sh"
echo "  3. Deploy SNO clusters: ./06-provision-user-snos.sh"
echo ""

