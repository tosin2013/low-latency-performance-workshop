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
#   --enable-rt-kernel   Enable Real-Time kernel (requires bare-metal instance)
#   --help              Show this help message
#
# Environment Variables:
#   ENABLE_RT_KERNEL    Set to 'true' to enable RT kernel (default: false)
#                       Note: RT kernel requires bare-metal EC2 instances (*.metal)
#

set -euo pipefail

# RT Kernel configuration (default: disabled)
ENABLE_RT_KERNEL="${ENABLE_RT_KERNEL:-false}"

# Parse command-line arguments
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-yes)
            AUTO_YES=true
            shift
            ;;
        --enable-rt-kernel)
            ENABLE_RT_KERNEL=true
            shift
            ;;
        --help)
            echo "Module 4: Performance Profile Creator"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto-yes          Automatically confirm (skip confirmation prompt)"
            echo "  --enable-rt-kernel  Enable Real-Time kernel (requires bare-metal instance)"
            echo "  --help              Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  ENABLE_RT_KERNEL    Set to 'true' to enable RT kernel (default: false)"
            echo "                      Note: RT kernel requires bare-metal EC2 instances (*.metal)"
            echo ""
            echo "This script:"
            echo "  - Loads CPU allocation from /tmp/cluster-config"
            echo "  - If config doesn't exist, runs CPU allocation calculator first"
            echo "  - Validates CPU ranges to prevent errors"
            echo "  - Detects instance type and validates RT kernel requirements"
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

# Detect instance type and validate RT kernel requirements
info "Detecting instance type..."
INSTANCE_TYPE=$(oc get node "$TARGET_NODE" -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}' 2>/dev/null || echo "unknown")

if [ "$INSTANCE_TYPE" = "unknown" ]; then
    warning "Could not detect instance type from node labels"
    warning "Assuming non-metal instance for safety"
    IS_METAL_INSTANCE=false
elif [[ "$INSTANCE_TYPE" == *".metal"* ]]; then
    IS_METAL_INSTANCE=true
    success "Detected bare-metal instance: $INSTANCE_TYPE"
else
    IS_METAL_INSTANCE=false
    info "Detected virtualized instance: $INSTANCE_TYPE"
fi

# Validate RT kernel requirements
if [ "$ENABLE_RT_KERNEL" = "true" ] && [ "$IS_METAL_INSTANCE" = "false" ]; then
    echo ""
    error "Real-Time (RT) Kernel Requires Bare-Metal Instance

Current instance type: $INSTANCE_TYPE (virtualized)
RT kernel requested: true

The Linux Real-Time kernel extension (kernel-rt) requires direct hardware
access and cannot run on virtualized EC2 instances.

COST COMPARISON (us-east-2):
  - Current ($INSTANCE_TYPE):  ~\$0.77/hr
  - Cheapest metal (m5zn.metal): ~\$3.96/hr (5x more expensive)

OPTIONS:
  1. Continue WITHOUT RT kernel (recommended for workshop):
     - CPU isolation, HugePages, NUMA tuning still work
     - Demonstrates 80% of low-latency concepts
     - Run: ENABLE_RT_KERNEL=false $0

  2. Redeploy with bare-metal instance:
     - Update agnosticd-v2-vars/low-latency-sno-aws.yml:
       control_plane_instance_type: m5zn.metal
     - Redeploy cluster, then run with:
       ENABLE_RT_KERNEL=true $0"
fi

# Display RT kernel status
if [ "$ENABLE_RT_KERNEL" = "true" ]; then
    if [ "$IS_METAL_INSTANCE" = "true" ]; then
        success "RT kernel will be enabled (bare-metal instance detected)"
    fi
else
    info "RT kernel disabled (default). CPU isolation, HugePages, and NUMA tuning will still be applied."
fi
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
# Build kernel args conditionally based on instance type and RT kernel setting
KERNEL_ARGS=()

# Only add nosmt for bare-metal instances
# For virtualized instances, nosmt disables hyperthreading which halves available CPUs
# This can cause control plane to fail due to insufficient resources
if [ "$IS_METAL_INSTANCE" = "true" ]; then
    KERNEL_ARGS+=("nosmt")
    info "Adding 'nosmt' kernel parameter (bare-metal instance)"
else
    info "Skipping 'nosmt' kernel parameter (virtualized instance - preserves hyperthreading)"
fi

if [ "$ENABLE_RT_KERNEL" = "true" ]; then
    # RT kernel specific args
    KERNEL_ARGS+=("nohz_full=$ISOLATED_CPUS")
    KERNEL_ARGS+=("rcu_nocbs=$ISOLATED_CPUS")
fi

# Build YAML with conditional RT kernel section
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
EOF

# Conditionally add RT kernel section
if [ "$ENABLE_RT_KERNEL" = "true" ]; then
    cat >> "$TEMP_FILE" << RTEOF
  realTimeKernel:
    enabled: true
RTEOF
fi

# Add kernel args
cat >> "$TEMP_FILE" << EOF
  additionalKernelArgs:
EOF

for arg in "${KERNEL_ARGS[@]}"; do
    echo "  - \"$arg\"" >> "$TEMP_FILE"
done

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
if [ "$ENABLE_RT_KERNEL" = "true" ]; then
    echo "   Real-Time Kernel: Enabled"
else
    echo "   Real-Time Kernel: Disabled (CPU isolation, HugePages, NUMA still active)"
fi
echo "   Instance Type: $INSTANCE_TYPE"
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

