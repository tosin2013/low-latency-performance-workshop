#!/bin/bash
# -------------------------------------------------------------------
# Destroy Development/Test SNO Cluster
#
# Destroys a Single Node OpenShift cluster deployed with AgnosticD V2
# using the development configuration. This will delete the cluster
# and all associated AWS resources including the VPC.
#
# Usage:
#   ./destroy-sno-dev.sh [GUID] [ACCOUNT]
#
# Examples:
#   ./destroy-sno-dev.sh dev1 sandbox3576
#   ./destroy-sno-dev.sh dev1              # Uses default account
#   ./destroy-sno-dev.sh                    # Uses defaults: dev1, sandbox3576
# -------------------------------------------------------------------

set -euo pipefail

# Default values
GUID="${1:-dev1}"
ACCOUNT="${2:-sandbox3576}"

# Paths
DEVELOPMENT_DIR="${HOME}/Development"
AGNOSTICD_DIR="${DEVELOPMENT_DIR}/agnosticd-v2"
CONFIG_NAME="low-latency-sno-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "============================================================"
echo "Destroying Development/Test SNO Cluster"
echo "============================================================"
echo ""
echo "GUID:     $GUID"
echo "Config:   $CONFIG_NAME"
echo "Account:  $ACCOUNT"
echo ""
echo -e "${RED}⚠️  WARNING: This will destroy the cluster and ALL associated resources${NC}"
echo -e "${RED}   including the VPC, instances, and all data.${NC}"
echo ""

# Confirmation
read -p "Are you sure you want to destroy cluster '$GUID'? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Cancelled."
  exit 0
fi

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

# Destroy using AgnosticD
cd "$AGNOSTICD_DIR"
echo -e "${YELLOW}→${NC} Starting cluster destruction..."
echo ""

./bin/agd destroy \
  --guid "$GUID" \
  --config "$CONFIG_NAME" \
  --account "$ACCOUNT"

echo ""
echo -e "${RED}✓${NC} Cluster destroyed!"
echo ""

# Optional: If AgnosticD didn't clean up the VPC, provide instructions
echo -e "${CYAN}ℹ${NC}  If the VPC still exists after destruction, you can delete it manually:"
echo "   ./scripts/delete-vpc.sh <vpc-id>"
echo ""
