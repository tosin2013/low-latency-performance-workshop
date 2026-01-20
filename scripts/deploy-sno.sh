#!/bin/bash
# -------------------------------------------------------------------
# Deploy SNO Cluster
#
# Deploys a Single Node OpenShift cluster using AgnosticD V2
#
# Usage:
#   ./deploy-sno.sh [GUID] [ACCOUNT]
#
# Examples:
#   ./deploy-sno.sh student1 sandbox1234
#   ./deploy-sno.sh student1              # Uses default account
#   ./deploy-sno.sh                       # Uses defaults: student1, sandbox28ptm
# -------------------------------------------------------------------

set -euo pipefail

# Default values
GUID="${1:-student1}"
ACCOUNT="${2:-sandbox28ptm}"

# Paths
DEVELOPMENT_DIR="${HOME}/Development"
AGNOSTICD_DIR="${DEVELOPMENT_DIR}/agnosticd-v2"
CONFIG_NAME="low-latency-sno-aws"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================================"
echo "Deploying SNO Cluster"
echo "============================================================"
echo ""
echo "GUID:     $GUID"
echo "Config:   $CONFIG_NAME"
echo "Account:  $ACCOUNT"
echo ""

# Check if agnosticd-v2 exists
if [[ ! -d "$AGNOSTICD_DIR" ]]; then
  echo "Error: agnosticd-v2 not found at $AGNOSTICD_DIR"
  echo "Run: ./scripts/workshop-setup.sh first"
  exit 1
fi

# Check if agd script exists
if [[ ! -f "${AGNOSTICD_DIR}/bin/agd" ]]; then
  echo "Error: agd script not found"
  exit 1
fi

# Deploy
cd "$AGNOSTICD_DIR"
echo -e "${YELLOW}→${NC} Starting deployment..."
echo ""

./bin/agd provision \
  --guid "$GUID" \
  --config "$CONFIG_NAME" \
  --account "$ACCOUNT"

echo ""
echo -e "${GREEN}✓${NC} Deployment completed!"
echo ""

# Get kubeconfig path
KUBECONFIG_PATH="${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeconfig"

# Apply KVM emulation patch for virtualized instances (m5.4xlarge)
if [[ -f "$KUBECONFIG_PATH" ]]; then
  export KUBECONFIG="$KUBECONFIG_PATH"
  
  # Wait for API to be available
  echo -e "${YELLOW}→${NC} Waiting for cluster API to be available..."
  for i in {1..30}; do
    if oc get nodes &>/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  
  # Check if this is a virtualized instance (not bare-metal)
  INSTANCE_TYPE=$(oc get nodes -o jsonpath='{.items[0].metadata.labels.node\.kubernetes\.io/instance-type}' 2>/dev/null || echo "unknown")
  
  if [[ "$INSTANCE_TYPE" != *"metal"* ]]; then
    echo -e "${YELLOW}→${NC} Applying KVM emulation patch for virtualized instance ($INSTANCE_TYPE)..."
    
    # Wait for HyperConverged CR to exist
    for i in {1..30}; do
      if oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv &>/dev/null 2>&1; then
        break
      fi
      sleep 2
    done
    
    # Apply the patch
    if oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type merge -p \
      '{"metadata":{"annotations":{"kubevirt.kubevirt.io/jsonpatch":"[{\"op\":\"add\",\"path\":\"/spec/configuration/developerConfiguration/useEmulation\",\"value\":true}]"}}}' 2>/dev/null; then
      echo -e "${GREEN}✓${NC} KVM emulation patch applied successfully"
      echo "  Waiting for virt-handler to restart and detect emulation..."
      sleep 30
    else
      echo -e "${YELLOW}⚠${NC}  Could not apply emulation patch (HyperConverged may not be ready yet)"
      echo "   You may need to apply it manually after the cluster stabilizes"
    fi
  else
    echo -e "${CYAN}ℹ${NC}  Bare-metal instance detected ($INSTANCE_TYPE) - emulation not needed"
  fi
else
  echo -e "${YELLOW}⚠${NC}  Kubeconfig not found - skipping emulation patch"
fi

echo ""
echo "Cluster information:"
echo "  Kubeconfig: ${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeconfig"
echo "  Password:   ${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeadmin-password"
echo ""

