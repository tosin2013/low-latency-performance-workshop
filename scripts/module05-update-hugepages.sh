#!/bin/bash
#
# Module 5: Update HugePages for VMI Testing
# Updates Performance Profile with sufficient HugePages for VMs
#
# This script:
# - Checks current HugePages allocation
# - Calculates optimal HugePages for VMI workloads
# - Updates Performance Profile if needed
# - Provides educational feedback
#
# Usage:
#   ./module05-update-hugepages.sh [OPTIONS]
#
# Options:
#   --hugepages COUNT   Number of 1GB HugePages (default: auto-calculate)
#   --auto-yes          Automatically confirm (skip confirmation prompt)
#   --help              Show this help message
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
HUGEPAGES_COUNT=""
AUTO_YES=false
CONFIG_FILE="/tmp/cluster-config"

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

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hugepages)
            HUGEPAGES_COUNT="$2"
            shift 2
            ;;
        --auto-yes)
            AUTO_YES=true
            shift
            ;;
        --help)
            echo "Module 5: Update HugePages for VMI Testing"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --hugepages COUNT   Number of 1GB HugePages (default: auto-calculate)"
            echo "  --auto-yes          Automatically confirm (skip confirmation prompt)"
            echo "  --help              Show this help message"
            echo ""
            echo "This script updates the Performance Profile with sufficient"
            echo "HugePages for VMI testing. It calculates the optimal amount"
            echo "based on available memory and cluster type."
            echo ""
            echo "Typical allocations:"
            echo "  - SNO (32GB RAM): 8-12 GB HugePages"
            echo "  - SNO (64GB RAM): 16-24 GB HugePages"
            echo "  - Multi-Node: 16-32 GB HugePages per worker"
            echo ""
            echo "This allows running multiple VMs with 2-4GB memory each."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Module 5: Update HugePages for VMI Testing ===${NC}"
echo ""

# Load cluster configuration (but not HUGEPAGES_COUNT from config)
if [ ! -f "$CONFIG_FILE" ]; then
    error "Cluster configuration not found at $CONFIG_FILE. Run module04-calculate-cpu-allocation.sh first."
fi

# Save the user-specified HUGEPAGES_COUNT before sourcing config
USER_HUGEPAGES_COUNT="$HUGEPAGES_COUNT"

source "$CONFIG_FILE"

# Restore user-specified value (don't use value from config file)
HUGEPAGES_COUNT="$USER_HUGEPAGES_COUNT"

# Validate required variables
if [ -z "${CLUSTER_TYPE:-}" ] || [ -z "${TARGET_NODE:-}" ]; then
    error "Invalid configuration in $CONFIG_FILE"
fi

info "Cluster type: $CLUSTER_TYPE"
info "Target node: $TARGET_NODE"
echo ""

# Check if Performance Profile exists
info "Checking for Performance Profile on cluster..."
PERF_PROFILE=""

if ! PERF_PROFILE=$(oc get performanceprofile -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || [ -z "$PERF_PROFILE" ]; then
    error "No Performance Profile found. Run module04-create-performance-profile.sh first."
fi

success "Performance Profile found on cluster: $PERF_PROFILE"

# Get current HugePages configuration from the cluster
info "Reading HugePages configuration from cluster Performance Profile..."
CURRENT_HUGEPAGES_COUNT=$(oc get performanceprofile "$PERF_PROFILE" -o jsonpath='{.spec.hugepages.pages[0].count}' 2>/dev/null || echo "0")
CURRENT_HUGEPAGES_SIZE=$(oc get performanceprofile "$PERF_PROFILE" -o jsonpath='{.spec.hugepages.pages[0].size}' 2>/dev/null || echo "1G")

# Calculate total HugePages in GB
if [[ "$CURRENT_HUGEPAGES_SIZE" == "1G" ]]; then
    CURRENT_HUGEPAGES=$CURRENT_HUGEPAGES_COUNT
elif [[ "$CURRENT_HUGEPAGES_SIZE" == "2Mi" ]]; then
    # Convert 2Mi pages to GB (2Mi * count / 1024)
    CURRENT_HUGEPAGES=$((CURRENT_HUGEPAGES_COUNT * 2 / 1024))
else
    # Unknown size, assume 1G
    CURRENT_HUGEPAGES=$CURRENT_HUGEPAGES_COUNT
fi

success "Current HugePages (from cluster): ${CURRENT_HUGEPAGES_COUNT} x ${CURRENT_HUGEPAGES_SIZE} = ${CURRENT_HUGEPAGES}GB"
echo ""

# Get total memory on node
info "Detecting available memory on node..."
TOTAL_MEMORY_KB=$(oc get node "$TARGET_NODE" -o jsonpath='{.status.capacity.memory}' 2>/dev/null | sed 's/Ki//')

if [ -z "$TOTAL_MEMORY_KB" ]; then
    error "Failed to detect memory on node $TARGET_NODE"
fi

TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))
success "Total memory: ${TOTAL_MEMORY_GB}GB"

# Calculate optimal HugePages if not specified
if [ -z "$HUGEPAGES_COUNT" ]; then
    info "Calculating optimal HugePages allocation for VMI testing..."
    echo ""

    # Calculate based on cluster type and total memory
    # Note: Module 5 VMI testing requires ~3GB per VMI (2GB guest + 1GB overhead)
    # Default test scale: 10 VMIs = 30GB needed
    if [ "$CLUSTER_TYPE" = "SNO" ]; then
        # SNO: Allocate enough for VMI testing (need memory for control plane too)
        if [ "$TOTAL_MEMORY_GB" -ge 128 ]; then
            HUGEPAGES_COUNT=32
            info "Large SNO (${TOTAL_MEMORY_GB}GB): Allocating 32GB HugePages"
            info "   Supports: ~10 VMIs with 2GB each + overhead"
        elif [ "$TOTAL_MEMORY_GB" -ge 64 ]; then
            HUGEPAGES_COUNT=24
            info "Medium SNO (${TOTAL_MEMORY_GB}GB): Allocating 24GB HugePages"
            info "   Supports: ~8 VMIs with 2GB each + overhead"
        elif [ "$TOTAL_MEMORY_GB" -ge 32 ]; then
            HUGEPAGES_COUNT=12
            info "Small SNO (${TOTAL_MEMORY_GB}GB): Allocating 12GB HugePages"
            info "   Supports: ~4 VMIs with 2GB each + overhead"
        else
            HUGEPAGES_COUNT=8
            info "Minimal SNO (${TOTAL_MEMORY_GB}GB): Allocating 8GB HugePages"
            info "   Supports: ~2-3 VMIs with 2GB each + overhead"
        fi
    else
        # Multi-Node: More aggressive (dedicated workers)
        if [ "$TOTAL_MEMORY_GB" -ge 128 ]; then
            HUGEPAGES_COUNT=48
            info "Large worker (${TOTAL_MEMORY_GB}GB): Allocating 48GB HugePages"
            info "   Supports: ~16 VMIs with 2GB each + overhead"
        elif [ "$TOTAL_MEMORY_GB" -ge 64 ]; then
            HUGEPAGES_COUNT=32
            info "Medium worker (${TOTAL_MEMORY_GB}GB): Allocating 32GB HugePages"
            info "   Supports: ~10 VMIs with 2GB each + overhead"
        elif [ "$TOTAL_MEMORY_GB" -ge 32 ]; then
            HUGEPAGES_COUNT=16
            info "Small worker (${TOTAL_MEMORY_GB}GB): Allocating 16GB HugePages"
            info "   Supports: ~5 VMIs with 2GB each + overhead"
        else
            HUGEPAGES_COUNT=8
            info "Minimal worker (${TOTAL_MEMORY_GB}GB): Allocating 8GB HugePages"
            info "   Supports: ~2-3 VMIs with 2GB each + overhead"
        fi
    fi
fi

echo ""
echo -e "${YELLOW}📊 HugePages Allocation Plan:${NC}"
echo "───────────────────────────────────────────────────────"
echo "  Total Memory: ${TOTAL_MEMORY_GB}GB"
echo "  Current HugePages: ${CURRENT_HUGEPAGES}GB"
echo "  New HugePages: ${HUGEPAGES_COUNT}GB"
echo "  Percentage: $((HUGEPAGES_COUNT * 100 / TOTAL_MEMORY_GB))% of total memory"
echo ""
echo "  VMI Capacity Calculation:"
echo "  • Each VMI needs: ~3GB (2GB guest + 1GB virt-launcher overhead)"
echo "  • Max concurrent VMIs: ~$((HUGEPAGES_COUNT / 3))"
echo ""
echo "  Example VMI Configurations:"
if [ "$HUGEPAGES_COUNT" -ge 32 ]; then
    echo "  • 10+ VMIs with 2GB memory each"
    echo "  • ✅ Module 5 default test (10 VMIs) will run successfully"
    echo "  • 8+ VMIs with 4GB memory each"
    echo "  • 5+ VMIs with 6GB memory each"
elif [ "$HUGEPAGES_COUNT" -ge 24 ]; then
    echo "  • 8 VMIs with 2GB memory each"
    echo "  • 6 VMIs with 4GB memory each"
    echo "  • 4 VMIs with 6GB memory each"
    echo "  • ⚠️  Module 5 default test (10 VMIs) needs scale reduction to 8"
elif [ "$HUGEPAGES_COUNT" -ge 16 ]; then
    echo "  • 5 VMIs with 2GB memory each"
    echo "  • 4 VMIs with 4GB memory each"
    echo "  • ⚠️  Module 5 default test (10 VMIs) needs scale reduction to 4-5"
elif [ "$HUGEPAGES_COUNT" -ge 12 ]; then
    echo "  • 4 VMIs with 2GB memory each"
    echo "  • 3 VMIs with 4GB memory each"
    echo "  • ⚠️  Module 5 default test (10 VMIs) needs scale reduction to 4"
elif [ "$HUGEPAGES_COUNT" -ge 8 ]; then
    echo "  • 2-3 VMIs with 2GB memory each"
    echo "  • 2 VMIs with 4GB memory each"
    echo "  • ⚠️  Module 5 default test (10 VMIs) needs scale reduction to 2"
else
    echo "  • 1-2 VMIs with 2GB memory each"
    echo "  • ❌ Insufficient for Module 5 default test (10 VMIs)"
fi
echo "───────────────────────────────────────────────────────"
echo ""

# Check if update is needed
info "Comparing HugePages configuration..."
info "  Performance Profile (cluster): ${CURRENT_HUGEPAGES}GB"
info "  Calculated optimal (for Module 5): ${HUGEPAGES_COUNT}GB"
echo ""

if [ "$CURRENT_HUGEPAGES" -eq "$HUGEPAGES_COUNT" ]; then
    success "HugePages already set to optimal value (${HUGEPAGES_COUNT}GB) - no update needed"
    info "Performance Profile on cluster matches calculated optimal allocation"
    exit 0
fi

info "Update needed: ${CURRENT_HUGEPAGES}GB → ${HUGEPAGES_COUNT}GB"
echo ""

# Ask for confirmation (unless --auto-yes)
if [ "$AUTO_YES" = false ]; then
    echo -e "${YELLOW}⚠️  This will update the Performance Profile and trigger a node reboot.${NC}"
    echo ""
    read -p "Update HugePages from ${CURRENT_HUGEPAGES}GB to ${HUGEPAGES_COUNT}GB? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        warning "HugePages update cancelled"
        exit 0
    fi
else
    info "Auto-confirming (--auto-yes flag set)"
fi

# Update Performance Profile
info "Updating Performance Profile..."
echo ""

# Use oc patch to update HugePages
if oc patch performanceprofile "$PERF_PROFILE" --type=json -p "[{\"op\": \"replace\", \"path\": \"/spec/hugepages/pages/0/count\", \"value\": $HUGEPAGES_COUNT}]"; then
    success "Performance Profile updated successfully!"
else
    error "Failed to update Performance Profile"
fi

# Update config file
if grep -q "HUGEPAGES_COUNT=" "$CONFIG_FILE"; then
    sed -i "s/HUGEPAGES_COUNT=.*/HUGEPAGES_COUNT=$HUGEPAGES_COUNT/" "$CONFIG_FILE"
else
    echo "HUGEPAGES_COUNT=$HUGEPAGES_COUNT" >> "$CONFIG_FILE"
fi

echo ""
success "HugePages configuration updated to ${HUGEPAGES_COUNT}GB"
echo ""

# Next steps
echo -e "${CYAN}📋 Next Steps:${NC}"
echo "  1. Monitor Machine Config Pool: oc get mcp -w"
echo "  2. Wait for node to reboot (10-15 minutes)"
echo "  3. Verify HugePages: oc debug node/$TARGET_NODE -- chroot /host cat /proc/meminfo | grep -i huge"
echo "  4. Continue with Module 5 VMI deployment"
echo ""

warning "Node will reboot to apply HugePages changes"
info "This is expected and required for HugePages allocation"

