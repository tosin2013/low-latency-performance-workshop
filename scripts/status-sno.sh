#!/bin/bash
# -------------------------------------------------------------------
# Check SNO Cluster Status
#
# Checks the status of a Single Node OpenShift cluster
#
# Usage:
#   ./status-sno.sh [GUID] [ACCOUNT]
#
# Examples:
#   ./status-sno.sh student1 sandbox1234
#   ./status-sno.sh student1              # Uses default account
#   ./status-sno.sh                       # Uses defaults: student1, sandbox28ptm
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
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================================"
echo "SNO Cluster Status"
echo "============================================================"
echo ""
echo "GUID:     $GUID"
echo "Config:   $CONFIG_NAME"
echo "Account:  $ACCOUNT"
echo ""

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

# Get status
cd "$AGNOSTICD_DIR"
echo -e "${YELLOW}→${NC} Checking status..."
echo ""

./bin/agd status \
  --guid "$GUID" \
  --config "$CONFIG_NAME" \
  --account "$ACCOUNT"

echo ""

