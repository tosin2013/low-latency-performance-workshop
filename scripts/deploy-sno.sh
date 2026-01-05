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
echo "Cluster information:"
echo "  Kubeconfig: ${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeconfig"
echo "  Password:   ${DEVELOPMENT_DIR}/agnosticd-v2-output/${GUID}/openshift-cluster_${GUID}_kubeadmin-password"
echo ""

