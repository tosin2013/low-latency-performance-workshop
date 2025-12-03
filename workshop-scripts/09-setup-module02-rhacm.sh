#!/bin/bash
# Module-02 RHACM-ArgoCD Setup Automation
# Automates the setup steps from module-02-rhacm-setup.adoc
#
# Usage:
#   ./09-setup-module02-rhacm.sh [mode]
#
# Modes:
#   workshop   - Automated setup for workshop environment (default)
#   standalone - Guided setup with prompts for self-deployment
#
# Prerequisites:
#   - Logged into hub cluster with cluster-admin
#   - RHACM installed on hub cluster
#   - Target clusters imported as ManagedClusters
#
# Idempotent - safe to re-run

set -e

MODE=${1:-workshop}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MODULE-02: RHACM-ARGOCD SETUP AUTOMATION               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Mode selection if not specified
if [ -z "$1" ]; then
    echo "Select setup mode:"
    echo ""
    echo "  [1] Workshop environment (automated)"
    echo "      - Uses existing rhacm-argocd-integration resources"
    echo "      - Auto-labels all managed clusters"
    echo "      - Deploys ArgoCD applications"
    echo ""
    echo "  [2] Standalone deployment (guided)"
    echo "      - Step-by-step with prompts"
    echo "      - Manual cluster URL configuration"
    echo ""
    read -p "Enter choice (1 or 2): " CHOICE
    case $CHOICE in
        1) MODE="workshop" ;;
        2) MODE="standalone" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

echo "Mode: ${MODE}"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/5] Checking prerequisites..."

# Check oc CLI
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into OpenShift cluster"
    echo "Run: oc login <hub-api-url>"
    exit 1
fi
HUB_API=$(oc whoami --show-server)
echo "✓ Logged into hub: ${HUB_API}"

# Check RHACM
if ! oc get multiclusterhub -n open-cluster-management &> /dev/null; then
    echo "✗ RHACM not installed on this cluster"
    echo "Please install RHACM before running this script"
    exit 1
fi
echo "✓ RHACM installed"

# Check ArgoCD/GitOps
if ! oc get crd applications.argoproj.io &> /dev/null; then
    echo "✗ OpenShift GitOps (ArgoCD) not installed"
    echo "Please install OpenShift GitOps operator first"
    exit 1
fi
echo "✓ OpenShift GitOps installed"

# Check managed clusters
MANAGED_CLUSTERS=$(oc get managedclusters -o name 2>/dev/null | grep -v local-cluster | wc -l)
echo "✓ Managed clusters found: ${MANAGED_CLUSTERS}"

if [ ${MANAGED_CLUSTERS} -eq 0 ]; then
    echo ""
    echo "⚠ No managed clusters found (besides local-cluster)"
    echo "Module-02 setup will continue but ArgoCD apps won't have targets"
    echo ""
fi

# ============================================
# Step 1: Apply RHACM-ArgoCD Integration
# ============================================
echo ""
echo "[2/5] Applying RHACM-ArgoCD integration..."

cd ${WORKSHOP_DIR}

if [ -d "rhacm-argocd-integration" ]; then
    echo "  Found: rhacm-argocd-integration/"
    
    if [ "${MODE}" == "standalone" ]; then
        echo ""
        echo "  This will create:"
        echo "    - ManagedClusterSet: all-clusters"
        echo "    - ManagedClusterSetBinding: openshift-gitops namespace"
        echo "    - Placement: all-clusters"
        echo "    - GitOpsCluster: gitops-cluster"
        echo ""
        read -p "  Continue? (yes/no): " CONFIRM
        [ "${CONFIRM}" != "yes" ] && exit 0
    fi
    
    oc apply -k rhacm-argocd-integration/
    echo "✓ RHACM-ArgoCD integration applied"
else
    echo "✗ rhacm-argocd-integration directory not found"
    exit 1
fi

# ============================================
# Step 2: Label Managed Clusters
# ============================================
echo ""
echo "[3/5] Labeling managed clusters..."

# Get all managed clusters except local-cluster
CLUSTERS=$(oc get managedclusters -o name 2>/dev/null | grep -v local-cluster || true)

if [ -z "${CLUSTERS}" ]; then
    echo "  No managed clusters to label (besides local-cluster)"
else
    for cluster in ${CLUSTERS}; do
        CLUSTER_NAME=$(echo ${cluster} | cut -d'/' -f2)
        echo "  Labeling: ${CLUSTER_NAME}"
        oc label ${cluster} \
            cluster.open-cluster-management.io/clusterset=all-clusters \
            --overwrite
    done
    echo "✓ All managed clusters labeled"
fi

# ============================================
# Step 3: Update ArgoCD Application URLs
# ============================================
echo ""
echo "[4/5] Updating ArgoCD application destination URLs..."

if [ -d "argocd-apps" ]; then
    echo "  Found: argocd-apps/"
    
    # Determine target cluster URL
    if [ ${MANAGED_CLUSTERS} -gt 0 ]; then
        # Get first non-local managed cluster URL
        TARGET_CLUSTER=$(oc get managedclusters -o name 2>/dev/null | grep -v local-cluster | head -1)
        if [ -n "${TARGET_CLUSTER}" ]; then
            TARGET_NAME=$(echo ${TARGET_CLUSTER} | cut -d'/' -f2)
            TARGET_URL=$(oc get managedcluster ${TARGET_NAME} -o jsonpath='{.spec.managedClusterClientConfigs[0].url}' 2>/dev/null || echo "")
            
            if [ -z "${TARGET_URL}" ]; then
                # Try to construct URL from cluster info
                SUBDOMAIN_SUFFIX=$(echo ${HUB_API} | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
                TARGET_URL="https://api.${TARGET_NAME}${SUBDOMAIN_SUFFIX}:6443"
            fi
        fi
    fi
    
    if [ -z "${TARGET_URL}" ]; then
        # Default to hub cluster for local deployment
        TARGET_URL="${HUB_API}"
        echo "  ⚠ No managed clusters found, using hub cluster: ${TARGET_URL}"
    else
        echo "  Target cluster: ${TARGET_URL}"
    fi
    
    if [ "${MODE}" == "standalone" ]; then
        echo ""
        read -p "  Use this URL? (yes/no/custom): " URL_CHOICE
        if [ "${URL_CHOICE}" == "custom" ]; then
            read -p "  Enter target cluster API URL: " TARGET_URL
        elif [ "${URL_CHOICE}" != "yes" ]; then
            exit 0
        fi
    fi
    
    # Update ArgoCD application files
    if command -v yq &> /dev/null; then
        echo "  Using yq to update destination URLs..."
        for file in argocd-apps/*.yaml; do
            if [[ "${file}" != *"kustomization.yaml" ]]; then
                yq eval ".spec.destination.server = \"${TARGET_URL}\"" -i "${file}"
                echo "    Updated: $(basename ${file})"
            fi
        done
    else
        echo "  yq not found, using sed..."
        for file in argocd-apps/*.yaml; do
            if [[ "${file}" != *"kustomization.yaml" ]]; then
                sed -i "s|server:.*|server: ${TARGET_URL}|g" "${file}"
                echo "    Updated: $(basename ${file})"
            fi
        done
    fi
    
    echo "✓ ArgoCD application URLs updated"
else
    echo "  ⚠ argocd-apps directory not found"
fi

# ============================================
# Step 4: Apply ArgoCD Applications
# ============================================
echo ""
echo "[5/5] Deploying ArgoCD applications..."

if [ -d "argocd-apps" ]; then
    if [ "${MODE}" == "standalone" ]; then
        echo ""
        echo "  This will deploy:"
        cat argocd-apps/kustomization.yaml | grep "^  - " | sed 's/^  - /    - /'
        echo ""
        read -p "  Continue? (yes/no): " CONFIRM
        [ "${CONFIRM}" != "yes" ] && exit 0
    fi
    
    oc apply -k argocd-apps/
    echo "✓ ArgoCD applications deployed"
    
    # Wait for applications to sync
    echo ""
    echo "  Waiting for applications to sync..."
    sleep 10
    
    # Show application status
    echo ""
    echo "  Application Status:"
    oc get applications.argoproj.io -n openshift-gitops -o custom-columns=NAME:.metadata.name,STATUS:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || echo "  (waiting for apps to appear)"
else
    echo "  ⚠ argocd-apps directory not found - skipping"
fi

# ============================================
# Verification
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MODULE-02 SETUP VERIFICATION                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "ManagedClusterSet:"
oc get managedclusterset all-clusters 2>/dev/null || echo "  Not found"
echo ""

echo "ManagedClusterSetBinding:"
oc get managedclustersetbinding -n openshift-gitops 2>/dev/null || echo "  Not found"
echo ""

echo "PlacementDecision:"
oc get placementdecision -n openshift-gitops 2>/dev/null || echo "  Not found"
echo ""

echo "GitOpsCluster:"
oc get gitopscluster -n openshift-gitops 2>/dev/null || echo "  Not found"
echo ""

echo "ArgoCD Applications:"
oc get applications.argoproj.io -n openshift-gitops 2>/dev/null || echo "  None deployed"
echo ""

echo "Managed Clusters in ClusterSet:"
oc get managedclusters -l cluster.open-cluster-management.io/clusterset=all-clusters 2>/dev/null || echo "  None labeled"
echo ""

# ============================================
# Summary
# ============================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MODULE-02 SETUP COMPLETE                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  ✓ RHACM-ArgoCD integration applied"
echo "  ✓ Managed clusters labeled for ClusterSet"
echo "  ✓ ArgoCD applications configured"
echo ""
echo "Verification Commands:"
echo "  # Check cluster secrets in ArgoCD"
echo "  oc get secrets -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster"
echo ""
echo "  # Check application sync status"
echo "  oc get applications.argoproj.io -n openshift-gitops -o wide"
echo ""
echo "  # Check placement decisions"
echo "  oc get placementdecision -n openshift-gitops -o yaml"
echo ""
echo "Next Steps:"
echo "  1. Verify ArgoCD applications sync to 'Healthy'"
echo "  2. Check operators installed on target cluster:"
echo "     oc --kubeconfig=<target-kubeconfig> get csv -A"
echo "  3. Continue to Module 03 for baseline testing"
echo ""

