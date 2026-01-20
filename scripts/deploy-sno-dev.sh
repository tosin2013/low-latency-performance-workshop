#!/bin/bash
# -------------------------------------------------------------------
# Deploy Development/Test SNO Cluster
#
# Deploys a Single Node OpenShift cluster using AgnosticD V2 with
# development configuration. Includes automated post-deployment
# validation to verify all workshop features work correctly.
#
# Usage:
#   ./deploy-sno-dev.sh [GUID] [ACCOUNT] [INSTANCE_TYPE]
#
# Instance Types:
#   virtualized  - m5.4xlarge (default, uses KVM emulation)
#   baremetal    - m5zn.metal (native KVM, no emulation)
#
# Examples:
#   ./deploy-sno-dev.sh dev1 sandbox3576 virtualized
#   ./deploy-sno-dev.sh dev1 sandbox3576 baremetal
#   ./deploy-sno-dev.sh dev1 sandbox3576              # Uses virtualized (default)
# -------------------------------------------------------------------

set -euo pipefail

# Default values
GUID="${1:-dev1}"
ACCOUNT="${2:-sandbox3576}"
INSTANCE_TYPE="${3:-virtualized}"

# Validate instance type
if [[ "$INSTANCE_TYPE" != "virtualized" && "$INSTANCE_TYPE" != "baremetal" ]]; then
  echo "Error: Invalid instance type '$INSTANCE_TYPE'"
  echo "Valid options: virtualized, baremetal"
  exit 1
fi

# Paths
DEVELOPMENT_DIR="${HOME}/Development"
AGNOSTICD_DIR="${DEVELOPMENT_DIR}/agnosticd-v2"
CONFIG_NAME="low-latency-sno-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo "============================================================"
echo "Deploying Development/Test SNO Cluster"
echo "============================================================"
echo ""
echo "GUID:          $GUID"
echo "Config:       $CONFIG_NAME"
echo "Account:      $ACCOUNT"
echo "Instance:     $INSTANCE_TYPE"
if [ "$INSTANCE_TYPE" = "virtualized" ]; then
  echo "              → m5.4xlarge (KVM emulation required)"
else
  echo "              → m5zn.metal (native KVM)"
fi
echo ""

# Check if agnosticd-v2 exists
if [[ ! -d "$AGNOSTICD_DIR" ]]; then
  echo -e "${RED}Error: agnosticd-v2 not found at $AGNOSTICD_DIR${NC}"
  echo "Run: ./scripts/workshop-setup.sh first"
  exit 1
fi

# Check if agd script exists
if [[ ! -f "${AGNOSTICD_DIR}/bin/agd" ]]; then
  echo -e "${RED}Error: agd script not found${NC}"
  exit 1
fi

# Check if dev config exists
if [[ ! -f "${WORKSHOP_DIR}/agnosticd-v2-vars/${CONFIG_NAME}.yml" ]]; then
  echo -e "${RED}Error: Dev config not found at ${WORKSHOP_DIR}/agnosticd-v2-vars/${CONFIG_NAME}.yml${NC}"
  exit 1
fi

# Set instance type based on parameter and update config file
CONFIG_FILE="${WORKSHOP_DIR}/agnosticd-v2-vars/${CONFIG_NAME}.yml"
if [ "$INSTANCE_TYPE" = "baremetal" ]; then
  INSTANCE_TYPE_VALUE="m5zn.metal"
  echo -e "${CYAN}Configuring for bare-metal instance (m5zn.metal)...${NC}"
  
  # Comment out m5.4xlarge and uncomment m5zn.metal
  sed -i 's/^control_plane_instance_type: m5\.4xlarge$/# control_plane_instance_type: m5.4xlarge/' "$CONFIG_FILE"
  sed -i 's/^# control_plane_instance_type: m5zn\.metal$/control_plane_instance_type: m5zn.metal/' "$CONFIG_FILE"
  
  echo -e "${GREEN}✓${NC} Config file updated: m5.4xlarge commented, m5zn.metal uncommented"
else
  INSTANCE_TYPE_VALUE="m5.4xlarge"
  echo -e "${CYAN}Configuring for virtualized instance (m5.4xlarge)...${NC}"
  
  # Uncomment m5.4xlarge and comment out m5zn.metal
  sed -i 's/^# control_plane_instance_type: m5\.4xlarge$/control_plane_instance_type: m5.4xlarge/' "$CONFIG_FILE"
  sed -i 's/^control_plane_instance_type: m5zn\.metal$/# control_plane_instance_type: m5zn.metal/' "$CONFIG_FILE"
  
  echo -e "${GREEN}✓${NC} Config file updated: m5.4xlarge uncommented, m5zn.metal commented"
fi
echo ""

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
PASSWORD_PATH="${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeadmin-password"

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo -e "${YELLOW}⚠${NC}  Kubeconfig not found at expected location"
  echo "   Please check deployment output for actual location"
  exit 0
fi

echo "Cluster information:"
echo "  Kubeconfig: $KUBECONFIG_PATH"
echo "  Password:   $PASSWORD_PATH"
echo ""

# Wait a bit for cluster to stabilize
echo -e "${CYAN}Waiting for cluster to stabilize (30 seconds)...${NC}"
sleep 30

# Apply KVM emulation patch for virtualized instances
if [[ "$INSTANCE_TYPE" == "virtualized" ]]; then
  echo ""
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}Applying KVM Emulation Configuration${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo ""
  
  export KUBECONFIG="$KUBECONFIG_PATH"
  
  # Wait for API to be available
  echo -e "${CYAN}Waiting for cluster API to be available...${NC}"
  for i in {1..30}; do
    if oc get nodes &>/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  
  # Wait for HyperConverged CR to exist
  echo -e "${CYAN}Waiting for HyperConverged CR to be ready...${NC}"
  for i in {1..30}; do
    if oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv &>/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  
  # Apply the patch
  echo -e "${YELLOW}→${NC} Applying KVM emulation patch..."
  if oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type merge -p \
    '{"metadata":{"annotations":{"kubevirt.kubevirt.io/jsonpatch":"[{\"op\":\"add\",\"path\":\"/spec/configuration/developerConfiguration/useEmulation\",\"value\":true}]"}}}' 2>/dev/null; then
    echo -e "${GREEN}✓${NC} KVM emulation patch applied successfully"
    echo "  Waiting for virt-handler to restart and detect emulation..."
    sleep 30
  else
    echo -e "${RED}✗${NC} Failed to apply emulation patch"
    echo "   Check if HyperConverged CR exists:"
    echo "   oc get hyperconverged -n openshift-cnv"
  fi
else
  echo ""
  echo -e "${CYAN}ℹ${NC}  Bare-metal instance - emulation not needed"
fi

# Run validation
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}Running Post-Deployment Validation${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

if [[ -f "${WORKSHOP_DIR}/scripts/validate-sno-dev.sh" ]]; then
  export KUBECONFIG="$KUBECONFIG_PATH"
  "${WORKSHOP_DIR}/scripts/validate-sno-dev.sh" "$GUID" "$INSTANCE_TYPE"
else
  echo -e "${YELLOW}⚠${NC}  Validation script not found"
  echo "   You can run validation manually:"
  echo "   export KUBECONFIG=$KUBECONFIG_PATH"
  echo "   oc apply -f ${WORKSHOP_DIR}/gitops/validation-workload/validation-job.yaml"
  echo ""
  echo "   Check results:"
  echo "   oc get configmap sno-validation-results -n default -o yaml"
fi

echo ""
echo -e "${GREEN}✓${NC} Deployment and validation complete!"
echo ""
