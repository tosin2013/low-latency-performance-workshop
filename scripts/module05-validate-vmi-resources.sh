#!/bin/bash
# Module 5: Pre-Flight Validation for VMI Testing
# Validates that sufficient resources are available before running kube-burner VMI tests

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Configuration
VMI_MEMORY_GB=2          # Guest memory per VMI
VMI_OVERHEAD_GB=1        # virt-launcher overhead per VMI
VMI_TOTAL_GB=$((VMI_MEMORY_GB + VMI_OVERHEAD_GB))
DEFAULT_VMI_COUNT=10     # Default test scale (5 iterations × 2 replicas)

echo "=== Module 5: VMI Resource Validation ==="
echo ""

# Get target node
TARGET_NODE=$(oc get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$TARGET_NODE" ]; then
    error "Failed to detect cluster nodes"
fi

info "Target node: $TARGET_NODE"
echo ""

# Check if Performance Profile exists
info "Checking for Performance Profile..."
PERF_PROFILE=$(oc get performanceprofile -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$PERF_PROFILE" ]; then
    warning "No Performance Profile found"
    warning "VMI testing will work but without performance optimizations"
    warning "Consider completing Module 4 first for best results"
    echo ""
    HAS_PERF_PROFILE=false
else
    success "Performance Profile found: $PERF_PROFILE"
    HAS_PERF_PROFILE=true
fi

# Check HugePages availability
info "Checking HugePages availability..."
HUGEPAGES_ALLOCATABLE=$(oc get node "$TARGET_NODE" -o jsonpath='{.status.allocatable.hugepages-1Gi}' 2>/dev/null | sed 's/Gi//' || echo "0")

if [ -z "$HUGEPAGES_ALLOCATABLE" ] || [ "$HUGEPAGES_ALLOCATABLE" = "0" ]; then
    warning "No HugePages available on cluster"
    warning "VMI testing will work but without HugePages optimization"
    echo ""
    HAS_HUGEPAGES=false
    HUGEPAGES_GB=0
else
    success "HugePages available: ${HUGEPAGES_ALLOCATABLE}GB"
    HAS_HUGEPAGES=true
    HUGEPAGES_GB=$HUGEPAGES_ALLOCATABLE
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resource Capacity Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Calculate VMI capacity
if [ "$HAS_HUGEPAGES" = true ]; then
    MAX_VMIS=$((HUGEPAGES_GB / VMI_TOTAL_GB))
    info "VMI Resource Requirements (with HugePages):"
    echo "  • Guest memory per VMI: ${VMI_MEMORY_GB}GB"
    echo "  • virt-launcher overhead: ${VMI_OVERHEAD_GB}GB"
    echo "  • Total per VMI: ${VMI_TOTAL_GB}GB"
    echo ""
    info "Available Resources:"
    echo "  • HugePages: ${HUGEPAGES_GB}GB"
    echo "  • Max concurrent VMIs: ~${MAX_VMIS}"
    echo ""
else
    # Without HugePages, use regular memory
    TOTAL_MEMORY_KB=$(oc get node "$TARGET_NODE" -o jsonpath='{.status.capacity.memory}' 2>/dev/null | sed 's/Ki//')
    TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))
    # Reserve 50% for system and control plane
    AVAILABLE_MEMORY_GB=$((TOTAL_MEMORY_GB / 2))
    MAX_VMIS=$((AVAILABLE_MEMORY_GB / VMI_TOTAL_GB))
    
    info "VMI Resource Requirements (without HugePages):"
    echo "  • Guest memory per VMI: ${VMI_MEMORY_GB}GB"
    echo "  • virt-launcher overhead: ${VMI_OVERHEAD_GB}GB"
    echo "  • Total per VMI: ${VMI_TOTAL_GB}GB"
    echo ""
    info "Available Resources:"
    echo "  • Total memory: ${TOTAL_MEMORY_GB}GB"
    echo "  • Available for VMs: ~${AVAILABLE_MEMORY_GB}GB (50% reserved for system)"
    echo "  • Max concurrent VMIs: ~${MAX_VMIS}"
    echo ""
fi

# Validate against default test scale
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Module 5 Default Test Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Default test configuration:"
echo "  • Job iterations: 5"
echo "  • Replicas per iteration: 2"
echo "  • Total VMIs: ${DEFAULT_VMI_COUNT}"
echo "  • Memory required: $((DEFAULT_VMI_COUNT * VMI_TOTAL_GB))GB"
echo ""

if [ "$MAX_VMIS" -ge "$DEFAULT_VMI_COUNT" ]; then
    success "✅ SUFFICIENT RESOURCES"
    echo ""
    echo "Your cluster can run the default Module 5 test (${DEFAULT_VMI_COUNT} VMIs)"
    echo ""
    VALIDATION_PASSED=true
elif [ "$MAX_VMIS" -ge 5 ]; then
    warning "⚠️  PARTIAL RESOURCES"
    echo ""
    echo "Your cluster can run ~${MAX_VMIS} VMIs, but default test needs ${DEFAULT_VMI_COUNT}"
    echo ""
    echo "Recommended adjustments for vmi-latency-config.yml:"
    if [ "$MAX_VMIS" -ge 8 ]; then
        echo "  • jobIterations: 5 → 4"
        echo "  • replicas: 2 → 2"
        echo "  • Total VMIs: 8 (fits in ${HUGEPAGES_GB}GB HugePages)"
    elif [ "$MAX_VMIS" -ge 6 ]; then
        echo "  • jobIterations: 5 → 3"
        echo "  • replicas: 2 → 2"
        echo "  • Total VMIs: 6 (fits in ${HUGEPAGES_GB}GB HugePages)"
    else
        echo "  • jobIterations: 5 → 2"
        echo "  • replicas: 2 → 2"
        echo "  • Total VMIs: 4 (fits in ${HUGEPAGES_GB}GB HugePages)"
    fi
    echo ""
    VALIDATION_PASSED=false
else
    error "❌ INSUFFICIENT RESOURCES"
    echo ""
    echo "Your cluster can only run ~${MAX_VMIS} VMIs, but default test needs ${DEFAULT_VMI_COUNT}"
    echo ""
    echo "Solutions:"
    echo "  1. Increase HugePages allocation:"
    echo "     bash ~/low-latency-performance-workshop/scripts/module05-update-hugepages.sh"
    echo ""
    echo "  2. Reduce test scale in vmi-latency-config.yml:"
    echo "     • jobIterations: 5 → 2"
    echo "     • replicas: 2 → 1"
    echo "     • Total VMIs: 2"
    echo ""
    VALIDATION_PASSED=false
fi

# Check isolated CPUs if Performance Profile exists
if [ "$HAS_PERF_PROFILE" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 CPU Isolation Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ISOLATED_CPUS=$(oc get performanceprofile "$PERF_PROFILE" -o jsonpath='{.spec.cpu.isolated}' 2>/dev/null || echo "")
    if [ -n "$ISOLATED_CPUS" ]; then
        # Count isolated CPUs (simple count, assumes format like "12-31")
        if [[ "$ISOLATED_CPUS" =~ ([0-9]+)-([0-9]+) ]]; then
            START=${BASH_REMATCH[1]}
            END=${BASH_REMATCH[2]}
            ISOLATED_COUNT=$((END - START + 1))
        else
            ISOLATED_COUNT=0
        fi
        
        success "Isolated CPUs: $ISOLATED_CPUS (${ISOLATED_COUNT} CPUs)"
        echo ""
        
        if [ "$ISOLATED_COUNT" -ge "$DEFAULT_VMI_COUNT" ]; then
            success "Sufficient isolated CPUs for ${DEFAULT_VMI_COUNT} VMIs with dedicated CPU placement"
        else
            warning "Only ${ISOLATED_COUNT} isolated CPUs available"
            warning "Default test (${DEFAULT_VMI_COUNT} VMIs) may not all get dedicated CPUs"
            echo ""
            echo "Consider:"
            echo "  • Reducing test scale to ${ISOLATED_COUNT} VMIs"
            echo "  • Or disabling dedicatedCpuPlacement in VMI template"
        fi
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$VALIDATION_PASSED" = true ]; then
    success "✅ All validations passed - ready for Module 5 testing!"
    echo ""
    echo "Next steps:"
    echo "  1. Create VMI test configuration: cd ~/kube-burner-configs"
    echo "  2. Run: kube-burner init -c vmi-latency-config.yml"
    echo "  3. Monitor: oc get vmi --all-namespaces"
    exit 0
else
    warning "⚠️  Validation completed with warnings"
    echo ""
    echo "You can proceed with testing, but consider:"
    echo "  • Increasing HugePages allocation (recommended)"
    echo "  • Reducing test scale to match available resources"
    echo ""
    echo "To increase HugePages:"
    echo "  bash ~/low-latency-performance-workshop/scripts/module05-update-hugepages.sh"
    echo ""
    exit 1
fi

