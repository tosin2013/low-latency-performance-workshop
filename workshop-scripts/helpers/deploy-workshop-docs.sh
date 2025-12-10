#!/bin/bash
# Deploy workshop documentation for users using Kustomize
#
# Usage:
#   ./deploy-workshop-docs.sh [num_users] [user_prefix]
#
# Examples:
#   ./deploy-workshop-docs.sh 5         # Deploy docs for user1-user5
#   ./deploy-workshop-docs.sh 10 user   # Deploy docs for user1-user10

set -e

NUM_USERS=${1:-5}
USER_PREFIX=${2:-user}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
GITOPS_DIR="${WORKSHOP_DIR}/gitops/workshop-docs"
OVERLAYS_DIR="${GITOPS_DIR}/overlays"
TEMPLATE_DIR="${OVERLAYS_DIR}/user-template"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     DEPLOY WORKSHOP DOCUMENTATION (Kustomize)              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Users: ${USER_PREFIX}1 - ${USER_PREFIX}${NUM_USERS}"
echo "  GitOps Dir: ${GITOPS_DIR}"
echo ""

# Get cluster info
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
SUBDOMAIN_SUFFIX=$(oc whoami --show-server | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||' | sed 's|^\.||')

echo "Cluster Domain: ${CLUSTER_DOMAIN}"
echo "Subdomain Suffix: ${SUBDOMAIN_SUFFIX}"
echo ""

# ============================================
# Generate user-specific overlays
# ============================================
echo "[1/3] Generating user overlays..."

for i in $(seq 1 ${NUM_USERS}); do
    USER="${USER_PREFIX}${i}"
    USER_OVERLAY="${OVERLAYS_DIR}/${USER}"
    
    echo "  → Creating overlay for ${USER}..."
    
    # Create user overlay directory
    mkdir -p "${USER_OVERLAY}/patches"
    
    # Generate kustomization.yaml
    cat > "${USER_OVERLAY}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: workshop-${USER}

resources:
  - ../../base

commonLabels:
  user: ${USER}

patches:
  - path: patches/buildconfig-patch.yaml
  - path: patches/route-patch.yaml
EOF

    # Generate buildconfig patch
    cat > "${USER_OVERLAY}/patches/buildconfig-patch.yaml" << EOF
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: workshop-docs
spec:
  strategy:
    dockerStrategy:
      buildArgs:
        - name: USER_NAME
          value: "${USER}"
        - name: SNO_GUID
          value: "workshop-${USER}"
        - name: SNO_API_URL
          value: "https://api.workshop-${USER}.${SUBDOMAIN_SUFFIX}:6443"
        - name: SNO_CONSOLE_URL
          value: "https://console-openshift-console.apps.workshop-${USER}.${SUBDOMAIN_SUFFIX}"
        - name: BASTION_HOST
          value: "bastion.workshop-${USER}.${SUBDOMAIN_SUFFIX}"
        - name: SUBDOMAIN_SUFFIX
          value: ".${SUBDOMAIN_SUFFIX}"
EOF

    # Generate route patch
    cat > "${USER_OVERLAY}/patches/route-patch.yaml" << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: workshop-docs
spec:
  host: docs-${USER}.${CLUSTER_DOMAIN}
EOF
done

echo "  ✓ Generated ${NUM_USERS} user overlays"
echo ""

# ============================================
# Create namespaces
# ============================================
echo "[2/3] Creating namespaces..."

for i in $(seq 1 ${NUM_USERS}); do
    USER="${USER_PREFIX}${i}"
    NS="workshop-${USER}"
    
    if ! oc get namespace ${NS} &>/dev/null; then
        oc create namespace ${NS}
        echo "  → Created namespace: ${NS}"
    else
        echo "  → Namespace exists: ${NS}"
    fi
    
    # Label namespace
    oc label namespace ${NS} workshop=low-latency user=${USER} --overwrite 2>/dev/null || true
done

echo ""

# ============================================
# Deploy with Kustomize
# ============================================
echo "[3/3] Deploying with Kustomize..."

DEPLOYED=0
FAILED=0

for i in $(seq 1 ${NUM_USERS}); do
    USER="${USER_PREFIX}${i}"
    USER_OVERLAY="${OVERLAYS_DIR}/${USER}"
    
    echo "  → Deploying ${USER}..."
    
    if oc apply -k "${USER_OVERLAY}" 2>&1 | grep -v "unchanged"; then
        ((DEPLOYED++)) || true
    else
        ((FAILED++)) || true
    fi
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     DEPLOYMENT COMPLETE                                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Results:"
echo "  ✓ Deployed: ${DEPLOYED}"
echo "  ✗ Failed: ${FAILED}"
echo ""
echo "Starting builds (using local files)..."

for i in $(seq 1 ${NUM_USERS}); do
    USER="${USER_PREFIX}${i}"
    oc start-build workshop-docs -n workshop-${USER} --from-dir=${WORKSHOP_DIR} --follow=false 2>/dev/null && echo "  → Build started: ${USER}" || echo "  ⚠ Build may be running: ${USER}"
done

echo ""
echo "Documentation URLs:"
for i in $(seq 1 ${NUM_USERS}); do
    USER="${USER_PREFIX}${i}"
    echo "  ${USER}: https://docs-${USER}.${CLUSTER_DOMAIN}"
done

echo ""
echo "Monitor builds:"
echo "  oc get builds -l workshop=low-latency --all-namespaces -w"
echo ""

