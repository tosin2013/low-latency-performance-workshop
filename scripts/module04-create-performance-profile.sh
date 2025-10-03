#!/bin/bash
#
# Module 4: Performance Profile Creator
# Creates a Performance Profile with validated CPU allocation
#
# This script creates a PerformanceProfile resource with:
# - Validated CPU allocation (reserved and isolated)
# - HugePages configuration
# - Real-Time kernel enablement
# - NUMA topology policy
# - Additional kernel arguments
#
# Usage:
#   ./module04-create-performance-profile.sh [OPTIONS]
#
# Options:
#   --auto-yes          Automatically confirm (skip confirmation prompt)
#   --help              Show this help message
#

set -euo pipefail

# Parse command-line arguments
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-yes)
            AUTO_YES=true
            shift
            ;;
        --help)
            echo "Module 4: Performance Profile Creator"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto-yes          Automatically confirm (skip confirmation prompt)"
            echo "  --help              Show this help message"
            echo ""
            echo "This script:"
            echo "  - Loads CPU allocation from /tmp/cluster-config"
            echo "  - If config doesn't exist, runs CPU allocation calculator first"
            echo "  - Validates CPU ranges to prevent errors"
            echo "  - Creates PerformanceProfile with proper configuration"
            echo "  - Shows configuration before applying (unless --auto-yes)"
            echo ""
            echo "The script automatically detects cluster changes and will"
            echo "regenerate configuration if you switch clusters."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="${CONFIG_FILE:-/tmp/cluster-config}"

# Functions
error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Detect current cluster context
CURRENT_CLUSTER=$(oc config current-context 2>/dev/null || echo "unknown")
CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "unknown")

info "Current cluster: $CURRENT_CLUSTER"
echo ""

# Check if config exists and matches current cluster
NEED_RECALCULATE=false

if [ ! -f "$CONFIG_FILE" ]; then
    warning "Configuration file not found at $CONFIG_FILE"
    NEED_RECALCULATE=true
else
    # Load existing config
    source "$CONFIG_FILE"

    # Check if cluster matches
    if [ "${SAVED_CLUSTER:-}" != "$CURRENT_CLUSTER" ]; then
        warning "Cluster changed: '${SAVED_CLUSTER:-none}' → '$CURRENT_CLUSTER'"
        NEED_RECALCULATE=true
    elif [ "${SAVED_SERVER:-}" != "$CURRENT_SERVER" ]; then
        warning "Server changed: '${SAVED_SERVER:-none}' → '$CURRENT_SERVER'"
        NEED_RECALCULATE=true
    fi
fi

# Run CPU allocation calculator if needed
if [ "$NEED_RECALCULATE" = true ]; then
    warning "CPU allocation needs to be calculated for current cluster"
    echo ""

    # Find the calculator script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CALCULATOR_SCRIPT="$SCRIPT_DIR/module04-calculate-cpu-allocation.sh"

    if [ ! -f "$CALCULATOR_SCRIPT" ]; then
        error "CPU allocation calculator not found at $CALCULATOR_SCRIPT"
    fi

    info "Running CPU allocation calculator..."
    echo ""

    if ! bash "$CALCULATOR_SCRIPT"; then
        error "CPU allocation calculation failed"
    fi

    echo ""
    info "CPU allocation complete, continuing with Performance Profile creation..."
    echo ""

    # Reload config
    source "$CONFIG_FILE"
fi

# Validate required variables
required_vars=(
    "CLUSTER_TYPE"
    "TARGET_NODE"
    "RESERVED_CPUS"
    "ISOLATED_CPUS"
    "CPU_COUNT"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    error "Missing required variables: ${missing_vars[*]}. Configuration may be corrupted."
fi

echo -e "${BLUE}=== Creating Performance Profile ===${NC}"
echo "Cluster type: $CLUSTER_TYPE"
echo "Target node: $TARGET_NODE"
echo "Total CPUs: $CPU_COUNT"
echo "Reserved CPUs: $RESERVED_CPUS"
echo "Isolated CPUs: $ISOLATED_CPUS"
echo ""

# Validate CPU ranges
validate_cpu_range() {
    local range=$1
    local name=$2
    
    # Check for valid format (e.g., "0-3" or "4-7")
    if ! [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
        error "Invalid $name CPU range format: $range (expected format: N-M)"
    fi
    
    # Extract start and end
    local start=$(echo "$range" | cut -d'-' -f1)
    local end=$(echo "$range" | cut -d'-' -f2)
    
    # Validate start < end
    if [ "$start" -ge "$end" ]; then
        error "Invalid $name CPU range: $range (start must be less than end)"
    fi
    
    # Validate within CPU count
    if [ "$end" -ge "$CPU_COUNT" ]; then
        error "Invalid $name CPU range: $range (end $end >= total CPUs $CPU_COUNT)"
    fi
}

info "Validating CPU allocation..."
validate_cpu_range "$RESERVED_CPUS" "reserved"
validate_cpu_range "$ISOLATED_CPUS" "isolated"
success "CPU allocation validated"
echo ""

# Determine HugePages allocation and node selector based on cluster type
case "$CLUSTER_TYPE" in
    SNO)
        HUGEPAGES_COUNT=1
        NODE_SELECTOR='node-role.kubernetes.io/master: ""'
        PROFILE_NAME="sno-low-latency-profile"
        info "SNO: Using conservative HugePages (1GB) and master node selector"
        ;;
    MULTI_NODE)
        HUGEPAGES_COUNT=2
        NODE_SELECTOR='node-role.kubernetes.io/worker-rt: ""'
        PROFILE_NAME="worker-low-latency-profile"
        info "Multi-Node: Using standard HugePages (2GB) and worker-rt selector"
        ;;
    MULTI_MASTER)
        HUGEPAGES_COUNT=1
        NODE_SELECTOR='node-role.kubernetes.io/master-rt: ""'
        PROFILE_NAME="master-low-latency-profile"
        info "Multi-Master: Using conservative HugePages (1GB) and master-rt selector"
        ;;
    *)
        error "Unknown cluster type: $CLUSTER_TYPE"
        ;;
esac

echo ""
echo -e "${YELLOW}🚀 Creating Performance Profile: $PROFILE_NAME${NC}"
echo ""

# Create temporary file for the Performance Profile
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Generate Performance Profile YAML
cat > "$TEMP_FILE" << EOF
apiVersion: performance.openshift.io/v2
kind: PerformanceProfile
metadata:
  name: $PROFILE_NAME
  labels:
    cluster-type: "$CLUSTER_TYPE"
spec:
  cpu:
    isolated: "$ISOLATED_CPUS"
    reserved: "$RESERVED_CPUS"
  hugepages:
    defaultHugepagesSize: 1G
    pages:
    - count: $HUGEPAGES_COUNT
      size: 1G
  nodeSelector:
    $NODE_SELECTOR
  numa:
    topologyPolicy: "single-numa-node"
  realTimeKernel:
    enabled: true
  additionalKernelArgs:
  - "nosmt"
  - "nohz_full=$ISOLATED_CPUS"
  - "rcu_nocbs=$ISOLATED_CPUS"
EOF

# Display the Performance Profile
echo -e "${CYAN}Performance Profile Configuration:${NC}"
echo "---"
cat "$TEMP_FILE"
echo "---"
echo ""

# Ask for confirmation (unless --auto-yes)
if [ "$AUTO_YES" = false ]; then
    read -p "Apply this Performance Profile? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        warning "Performance Profile creation cancelled"
        exit 0
    fi
else
    info "Auto-confirming (--auto-yes flag set)"
fi

# Apply the Performance Profile
info "Applying Performance Profile..."
if oc apply -f "$TEMP_FILE"; then
    success "Performance Profile '$PROFILE_NAME' created successfully!"
else
    error "Failed to create Performance Profile"
fi

# Save profile name for later use
echo "PROFILE_NAME=$PROFILE_NAME" >> "$CONFIG_FILE"
echo "HUGEPAGES_COUNT=$HUGEPAGES_COUNT" >> "$CONFIG_FILE"

echo ""
echo -e "${GREEN}📊 Performance Profile Summary:${NC}"
echo "   Name: $PROFILE_NAME"
echo "   Reserved CPUs: $RESERVED_CPUS"
echo "   Isolated CPUs: $ISOLATED_CPUS"
echo "   HugePages: ${HUGEPAGES_COUNT}GB"
echo "   Real-Time Kernel: Enabled"
echo "   Node Selector: $NODE_SELECTOR"
echo ""

info "Monitoring Machine Config Pool status..."
echo "Run: oc get mcp -w"
echo ""
info "Check Performance Profile status..."
echo "Run: oc get performanceprofile $PROFILE_NAME -o yaml"
echo ""

success "Performance Profile configuration complete!"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Wait for Machine Config Pool to update (may take 10-15 minutes)"
echo "  2. Verify nodes are ready: oc get nodes"
echo "  3. Validate configuration: python3 ~/low-latency-performance-workshop/scripts/module04-tuning-validator.py"

