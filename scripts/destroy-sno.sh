#!/bin/bash
# -------------------------------------------------------------------
# Destroy SNO Cluster
#
# Destroys a Single Node OpenShift cluster deployed with AgnosticD V2
#
# Usage:
#   ./destroy-sno.sh [GUID] [ACCOUNT]
#
# Examples:
#   ./destroy-sno.sh student1 sandbox1234
#   ./destroy-sno.sh student1              # Uses default account
#   ./destroy-sno.sh                        # Uses defaults: student1, sandbox28ptm
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
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================================"
echo "Destroying SNO Cluster"
echo "============================================================"
echo ""
echo "GUID:     $GUID"
echo "Config:   $CONFIG_NAME"
echo "Account:  $ACCOUNT"
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
  echo "Error: agnosticd-v2 not found at $AGNOSTICD_DIR"
  exit 1
fi

# Check if agd script exists
if [[ ! -f "${AGNOSTICD_DIR}/bin/agd" ]]; then
  echo "Error: agd script not found"
  exit 1
fi

# Destroy
cd "$AGNOSTICD_DIR"
echo -e "${YELLOW}→${NC} Starting destruction..."
echo ""

./bin/agd destroy \
  --guid "$GUID" \
  --config "$CONFIG_NAME" \
  --account "$ACCOUNT"

echo ""
echo -e "${RED}✓${NC} Cluster destroyed!"
echo ""

