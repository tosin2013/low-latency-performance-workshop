#!/bin/bash
#
# Module 4: CPU Allocation Calculator
# Calculates optimal CPU allocation for Performance Profiles
#
# This script determines the best CPU allocation strategy based on:
# - Cluster architecture (SNO, Multi-Node, Multi-Master)
# - Total CPU count
# - Workshop-friendly conservative allocation
#
# Usage:
#   ./module04-calculate-cpu-allocation.sh [OPTIONS]
#
# Options:
#   --force-redetect    Force re-detection even if config exists
#   --help              Show this help message
#

set -euo pipefail

# Parse command-line arguments
FORCE_REDETECT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-redetect)
            FORCE_REDETECT=true
            shift
            ;;
        --help)
            echo "Module 4: CPU Allocation Calculator"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force-redetect    Force re-detection even if config exists"
            echo "  --help              Show this help message"
            echo ""
            echo "This script automatically detects:"
            echo "  - Current cluster context"
            echo "  - Target node (worker preferred, falls back to master)"
            echo "  - Cluster type (SNO, Multi-Node, Multi-Master)"
            echo "  - CPU count on target node"
            echo "  - Optimal CPU allocation strategy"
            echo ""
            echo "Configuration is saved to: /tmp/cluster-config"
            echo ""
            echo "If you switch clusters, the script will automatically detect"
            echo "the change and re-calculate for the new cluster."
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
NEED_REDETECT=false

if [ "$FORCE_REDETECT" = true ]; then
    warning "Force re-detect requested"
    NEED_REDETECT=true
elif [ ! -f "$CONFIG_FILE" ]; then
    info "No configuration file found, will auto-detect"
    NEED_REDETECT=true
else
    # Load existing config
    source "$CONFIG_FILE"

    # Check if cluster matches
    if [ "${SAVED_CLUSTER:-}" != "$CURRENT_CLUSTER" ]; then
        warning "Cluster changed: '${SAVED_CLUSTER:-none}' → '$CURRENT_CLUSTER'"
        NEED_REDETECT=true
    elif [ "${SAVED_SERVER:-}" != "$CURRENT_SERVER" ]; then
        warning "Server changed: '${SAVED_SERVER:-none}' → '$CURRENT_SERVER'"
        NEED_REDETECT=true
    else
        success "Configuration matches current cluster, reusing existing config"
        info "Target node: $TARGET_NODE"
        info "Cluster type: $CLUSTER_TYPE"
        info "Reserved CPUs: $RESERVED_CPUS"
        info "Isolated CPUs: $ISOLATED_CPUS"
        echo ""
        info "To force re-detection, run: $0 --force-redetect"
        exit 0
    fi
fi

# Clear old config if we need to redetect
if [ "$NEED_REDETECT" = true ]; then
    info "Regenerating configuration for current cluster..."
    rm -f "$CONFIG_FILE"
    unset TARGET_NODE CLUSTER_TYPE CPU_COUNT RESERVED_CPUS ISOLATED_CPUS SAVED_CLUSTER SAVED_SERVER
    echo ""
fi

# Auto-detect TARGET_NODE if not set
if [ -z "${TARGET_NODE:-}" ]; then
    info "TARGET_NODE not set, auto-detecting..."

    # Try to get a worker node first, fall back to master
    TARGET_NODE=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$TARGET_NODE" ]; then
        # No worker nodes, try master nodes
        TARGET_NODE=$(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi

    if [ -z "$TARGET_NODE" ]; then
        # Fall back to any node
        TARGET_NODE=$(oc get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi

    if [ -z "$TARGET_NODE" ]; then
        error "Failed to detect any nodes. Check cluster connectivity."
    fi

    success "Auto-detected target node: $TARGET_NODE"

    # Save to config file
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "TARGET_NODE=$TARGET_NODE" >> "$CONFIG_FILE"
fi

# Auto-detect CLUSTER_TYPE if not set
if [ -z "${CLUSTER_TYPE:-}" ]; then
    info "CLUSTER_TYPE not set, auto-detecting..."

    # Count total nodes
    TOTAL_NODES=$(oc get nodes --no-headers 2>/dev/null | wc -l)

    # Count master and worker nodes
    MASTER_COUNT=$(oc get nodes -l node-role.kubernetes.io/master --no-headers 2>/dev/null | wc -l)
    WORKER_COUNT=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers 2>/dev/null | wc -l)

    # Detect cluster type based on node count and roles
    if [ "$TOTAL_NODES" -eq 1 ]; then
        # Single node = SNO (regardless of labels)
        CLUSTER_TYPE="SNO"
        info "Detected Single Node OpenShift (SNO) - 1 node with all roles"
    elif [ "$MASTER_COUNT" -eq 1 ] && [ "$WORKER_COUNT" -eq 1 ] && [ "$TOTAL_NODES" -eq 1 ]; then
        # One node with both master and worker labels = SNO
        CLUSTER_TYPE="SNO"
        info "Detected Single Node OpenShift (SNO) - 1 node with master+worker roles"
    elif [ "$WORKER_COUNT" -gt 1 ] || ([ "$MASTER_COUNT" -ge 1 ] && [ "$WORKER_COUNT" -ge 1 ] && [ "$TOTAL_NODES" -gt 1 ]); then
        # Multiple nodes with dedicated workers = Multi-Node
        CLUSTER_TYPE="MULTI_NODE"
        info "Detected Multi-Node cluster (${TOTAL_NODES} nodes: ${MASTER_COUNT} masters, ${WORKER_COUNT} workers)"
    elif [ "$MASTER_COUNT" -gt 1 ]; then
        # Multiple master nodes, no dedicated workers = Multi-Master
        CLUSTER_TYPE="MULTI_MASTER"
        info "Detected Multi-Master cluster (${MASTER_COUNT} master nodes)"
    else
        # Fallback
        CLUSTER_TYPE="SNO"
        warning "Unable to determine cluster type precisely, defaulting to SNO"
        info "Total nodes: ${TOTAL_NODES}, Masters: ${MASTER_COUNT}, Workers: ${WORKER_COUNT}"
    fi

    # Save to config file
    echo "CLUSTER_TYPE=$CLUSTER_TYPE" >> "$CONFIG_FILE"
fi

echo ""
echo -e "${BLUE}=== CPU Allocation Planning ===${NC}"
echo "Target node: $TARGET_NODE"
echo "Cluster type: $CLUSTER_TYPE"
echo ""

# Get CPU count from the node
info "Detecting CPU count on node $TARGET_NODE..."

# Try multiple methods to get CPU count
CPU_COUNT=""

# Method 1: Try oc debug with timeout
info "Trying oc debug method..."
CPU_COUNT=$(timeout 30 oc debug node/"$TARGET_NODE" -- chroot /host nproc 2>/dev/null | grep -E '^[0-9]+$' | head -1 || true)

# Method 2: Try getting from node status
if [ -z "$CPU_COUNT" ]; then
    info "Trying node status method..."
    CPU_COUNT=$(oc get node "$TARGET_NODE" -o jsonpath='{.status.capacity.cpu}' 2>/dev/null || true)
fi

# Method 3: Try getting from allocatable
if [ -z "$CPU_COUNT" ]; then
    info "Trying allocatable method..."
    CPU_COUNT=$(oc get node "$TARGET_NODE" -o jsonpath='{.status.allocatable.cpu}' 2>/dev/null || true)
fi

# Validate CPU count
if [ -z "$CPU_COUNT" ]; then
    error "Failed to detect CPU count on node $TARGET_NODE using any method"
fi

if ! [[ "$CPU_COUNT" =~ ^[0-9]+$ ]]; then
    error "Invalid CPU count detected: '$CPU_COUNT' (expected a number)"
fi

if [ "$CPU_COUNT" -eq 0 ] 2>/dev/null; then
    error "CPU count is 0, which is invalid"
fi

success "Detected $CPU_COUNT CPUs on node $TARGET_NODE"
echo ""

# Detect instance type
info "Detecting instance type..."
INSTANCE_TYPE=$(oc get node "$TARGET_NODE" -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}' 2>/dev/null || echo "unknown")

if [ "$INSTANCE_TYPE" = "unknown" ]; then
    warning "Could not detect instance type from node labels"
    IS_METAL_INSTANCE=false
elif [[ "$INSTANCE_TYPE" == *".metal"* ]]; then
    IS_METAL_INSTANCE=true
    success "Detected bare-metal instance: $INSTANCE_TYPE"
else
    IS_METAL_INSTANCE=false
    info "Detected virtualized instance: $INSTANCE_TYPE"
fi
echo ""

# Calculate CPU allocation based on cluster architecture
calculate_sno_allocation() {
    local cpu_count=$1
    
    echo -e "${YELLOW}🔧 SNO CPU Allocation Strategy (Workshop-Friendly):${NC}"
    echo "   - Conservative allocation preserving cluster functionality"
    echo "   - Reserve sufficient CPUs for control plane, container runtime, and system services"
    echo "   - Target ~60-75% isolation for performance demonstration"
    echo ""
    
    # Check if this is a virtualized instance (m5.4xlarge, etc.)
    # For virtualized instances, we need to be more conservative since nosmt won't be used
    # and we need to account for hyperthreading
    if [ "${IS_METAL_INSTANCE:-false}" = "false" ] && [ "$cpu_count" -eq 16 ]; then
        # Special case: m5.4xlarge (16 vCPUs, 8 physical cores with HT)
        # Reserve 6 CPUs (0-5) for control plane, isolate 10 CPUs (6-15)
        # This is more conservative to ensure API server can start
        RESERVED_COUNT=6
        echo "   - Virtualized instance ($cpu_count vCPUs): Reserve $RESERVED_COUNT CPUs (~37.5%) for control plane stability"
        echo "   - Note: Without nosmt, hyperthreading is enabled, so more CPUs available for system"
    elif [ "$cpu_count" -gt 16 ]; then
        # High CPU count (32+ cores): Reserve ~40% for system, isolate ~60%
        RESERVED_COUNT=$((cpu_count * 40 / 100))
        echo "   - High CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~40%) for system stability"
    elif [ "$cpu_count" -gt 8 ]; then
        # Medium CPU count (16+ cores): Reserve ~37.5% for system, isolate ~62.5%
        # More conservative for virtualized instances
        if [ "${IS_METAL_INSTANCE:-false}" = "false" ]; then
            # Virtualized: Reserve more for control plane
            RESERVED_COUNT=$((cpu_count * 37 / 100))
            if [ "$RESERVED_COUNT" -lt 6 ]; then RESERVED_COUNT=6; fi
            echo "   - Medium CPU count virtualized ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~37.5%) for system stability"
        else
            # Bare-metal: Can be more aggressive
            RESERVED_COUNT=$((cpu_count / 2))
            echo "   - Medium CPU count bare-metal ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~50%) for system stability"
        fi
    elif [ "$cpu_count" -gt 4 ]; then
        # Lower CPU count (8+ cores): Reserve ~60% for system, isolate ~40%
        RESERVED_COUNT=$((cpu_count * 60 / 100))
        if [ "$RESERVED_COUNT" -lt 3 ]; then RESERVED_COUNT=3; fi  # Minimum 3 for SNO
        echo "   - Lower CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~60%) for system stability"
    else
        # Very low CPU count: Reserve most for system, minimal isolation
        RESERVED_COUNT=$((cpu_count - 1))
        if [ "$RESERVED_COUNT" -lt 2 ]; then RESERVED_COUNT=2; fi
        echo "   - Very low CPU count ($cpu_count cores): Minimal isolation for demonstration only"
    fi
    
    RESERVED_CPUS="0-$((RESERVED_COUNT - 1))"
    ISOLATED_CPUS="$RESERVED_COUNT-$((cpu_count - 1))"
}

calculate_multinode_allocation() {
    local cpu_count=$1
    
    echo -e "${YELLOW}🔧 Multi-Node CPU Allocation Strategy (Workshop-Friendly):${NC}"
    echo "   - More aggressive allocation possible (control plane on separate nodes)"
    echo "   - Target ~75% isolation while preserving worker node functionality"
    echo ""
    
    if [ "$cpu_count" -gt 8 ]; then
        # High CPU count: Reserve ~25% for system, isolate ~75%
        RESERVED_COUNT=$((cpu_count * 25 / 100))
        if [ "$RESERVED_COUNT" -lt 2 ]; then RESERVED_COUNT=2; fi  # Minimum 2 for worker
        echo "   - High CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~25%) for system"
    elif [ "$cpu_count" -gt 4 ]; then
        # Medium CPU count: Reserve ~33% for system, isolate ~67%
        RESERVED_COUNT=$((cpu_count * 33 / 100))
        if [ "$RESERVED_COUNT" -lt 2 ]; then RESERVED_COUNT=2; fi
        echo "   - Medium CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~33%) for system"
    else
        # Low CPU count: Reserve 50% for system
        RESERVED_COUNT=2
        echo "   - Low CPU count ($cpu_count cores): Reserve 2 CPUs (50%) for system"
    fi
    
    RESERVED_CPUS="0-$((RESERVED_COUNT - 1))"
    ISOLATED_CPUS="$RESERVED_COUNT-$((cpu_count - 1))"
}

calculate_multimaster_allocation() {
    local cpu_count=$1
    
    echo -e "${YELLOW}🔧 Multi-Master CPU Allocation Strategy (Workshop-Friendly):${NC}"
    echo "   - Balanced allocation for control plane and workloads"
    echo "   - Target ~60% isolation while maintaining control plane stability"
    echo ""
    
    if [ "$cpu_count" -gt 8 ]; then
        # High CPU count: Reserve ~40% for control plane, isolate ~60%
        RESERVED_COUNT=$((cpu_count * 40 / 100))
        if [ "$RESERVED_COUNT" -lt 3 ]; then RESERVED_COUNT=3; fi  # Minimum 3 for master
        echo "   - High CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~40%) for control plane"
    elif [ "$cpu_count" -gt 4 ]; then
        # Medium CPU count: Reserve ~50% for control plane
        RESERVED_COUNT=$((cpu_count / 2))
        echo "   - Medium CPU count ($cpu_count cores): Reserve $RESERVED_COUNT CPUs (~50%) for control plane"
    else
        # Low CPU count: Reserve most for control plane
        RESERVED_COUNT=$((cpu_count - 1))
        if [ "$RESERVED_COUNT" -lt 2 ]; then RESERVED_COUNT=2; fi
        echo "   - Low CPU count ($cpu_count cores): Minimal isolation for demonstration"
    fi
    
    RESERVED_CPUS="0-$((RESERVED_COUNT - 1))"
    ISOLATED_CPUS="$RESERVED_COUNT-$((cpu_count - 1))"
}

# Calculate allocation based on cluster type
case "$CLUSTER_TYPE" in
    SNO)
        calculate_sno_allocation "$CPU_COUNT"
        ;;
    MULTI_NODE)
        calculate_multinode_allocation "$CPU_COUNT"
        ;;
    MULTI_MASTER)
        calculate_multimaster_allocation "$CPU_COUNT"
        ;;
    *)
        error "Unknown cluster type: $CLUSTER_TYPE"
        ;;
esac

# Calculate counts for validation
ISOLATED_COUNT=$((CPU_COUNT - RESERVED_COUNT))

# Validate allocation
if [ "$RESERVED_COUNT" -le 0 ] || [ "$ISOLATED_COUNT" -le 0 ]; then
    error "Invalid CPU allocation: Reserved=$RESERVED_COUNT, Isolated=$ISOLATED_COUNT"
fi

if [ "$RESERVED_COUNT" -ge "$CPU_COUNT" ]; then
    error "Reserved CPUs ($RESERVED_COUNT) must be less than total CPUs ($CPU_COUNT)"
fi

# Calculate percentages
RESERVED_PERCENT=$((RESERVED_COUNT * 100 / CPU_COUNT))
ISOLATED_PERCENT=$((ISOLATED_COUNT * 100 / CPU_COUNT))

# Display final allocation
echo ""
echo -e "${GREEN}📊 Final CPU Allocation (Workshop-Optimized):${NC}"
echo "   Reserved CPUs: $RESERVED_CPUS"
echo "   Isolated CPUs: $ISOLATED_CPUS"
echo ""
echo "   Reserved: $RESERVED_COUNT CPUs ($RESERVED_PERCENT%) - System/Control Plane"
echo "   Isolated: $ISOLATED_COUNT CPUs ($ISOLATED_PERCENT%) - High-Performance Workloads"
echo ""
success "This allocation preserves cluster functionality while demonstrating performance benefits"

# Save CPU configuration with cluster context
{
    echo "# Cluster Context"
    echo "SAVED_CLUSTER=$CURRENT_CLUSTER"
    echo "SAVED_SERVER=$CURRENT_SERVER"
    echo ""
    echo "# Instance Information"
    echo "INSTANCE_TYPE=$INSTANCE_TYPE"
    echo "IS_METAL_INSTANCE=$IS_METAL_INSTANCE"
    echo ""
    echo "# CPU Configuration"
    echo "CPU_COUNT=$CPU_COUNT"
    echo "RESERVED_CPUS=$RESERVED_CPUS"
    echo "ISOLATED_CPUS=$ISOLATED_CPUS"
    echo "RESERVED_COUNT=$RESERVED_COUNT"
    echo "ISOLATED_COUNT=$ISOLATED_COUNT"
} >> "$CONFIG_FILE"

success "CPU allocation saved to $CONFIG_FILE"
echo ""
echo -e "${CYAN}Next step: Create Performance Profile with these settings${NC}"

