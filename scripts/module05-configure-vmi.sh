#!/bin/bash
#
# Module 5: VMI Configuration Helper
# Configures VirtualMachineInstance with optimal settings
#
# This script:
# - Detects available Performance Profile
# - Checks for HugePages availability
# - Configures CPU pinning if available
# - Generates optimized VMI YAML
# - Provides educational feedback
#
# Usage:
#   ./module05-configure-vmi.sh [OPTIONS]
#
# Options:
#   --name NAME         VMI name (default: fedora-vmi)
#   --namespace NS      Namespace (default: default)
#   --memory SIZE       Memory size (default: 2Gi)
#   --cpus NUM          Number of CPUs (default: 2)
#   --output FILE       Output file (default: fedora-vmi.yml)
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
VMI_NAME="fedora-vmi"
NAMESPACE="default"
MEMORY="2Gi"
CPUS=2
OUTPUT_FILE="fedora-vmi.yml"

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
        --name)
            VMI_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Module 5: VMI Configuration Helper"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --name NAME         VMI name (default: fedora-vmi)"
            echo "  --namespace NS      Namespace (default: default)"
            echo "  --memory SIZE       Memory size (default: 2Gi)"
            echo "  --cpus NUM          Number of CPUs (default: 2)"
            echo "  --output FILE       Output file (default: fedora-vmi.yml)"
            echo "  --help              Show this help message"
            echo ""
            echo "This script automatically detects:"
            echo "  - Performance Profile availability"
            echo "  - HugePages configuration"
            echo "  - Isolated CPUs for pinning"
            echo "  - Optimal VMI configuration"
            echo ""
            echo "The script generates an optimized VMI YAML file with:"
            echo "  - CPU pinning (if Performance Profile exists)"
            echo "  - HugePages (if available)"
            echo "  - Appropriate CPU model"
            echo "  - Educational comments"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Module 5: VMI Configuration ===${NC}"
echo "VMI Name: $VMI_NAME"
echo "Namespace: $NAMESPACE"
echo "Memory: $MEMORY"
echo "CPUs: $CPUS"
echo "Output: $OUTPUT_FILE"
echo ""

# Detect Performance Profile
info "Checking for Performance Profile..."
PERF_PROFILE=""
HAS_PERF_PROFILE=false

if PERF_PROFILE=$(oc get performanceprofile -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && [ -n "$PERF_PROFILE" ]; then
    HAS_PERF_PROFILE=true
    success "Performance Profile found: $PERF_PROFILE"
    
    # Get isolated CPUs
    ISOLATED_CPUS=$(oc get performanceprofile "$PERF_PROFILE" -o jsonpath='{.spec.cpu.isolated}' 2>/dev/null || echo "")
    RESERVED_CPUS=$(oc get performanceprofile "$PERF_PROFILE" -o jsonpath='{.spec.cpu.reserved}' 2>/dev/null || echo "")
    
    info "Isolated CPUs: $ISOLATED_CPUS"
    info "Reserved CPUs: $RESERVED_CPUS"
else
    warning "No Performance Profile found"
    info "This is expected if Module 4 hasn't been completed"
fi

echo ""

# Check HugePages availability
info "Checking for HugePages..."
HAS_HUGEPAGES=false
HUGEPAGE_SIZE=""

if HUGEPAGE_SIZE=$(oc get nodes -o jsonpath='{.items[0].status.allocatable.hugepages-1Gi}' 2>/dev/null) && [ -n "$HUGEPAGE_SIZE" ]; then
    HAS_HUGEPAGES=true
    success "HugePages available: $HUGEPAGE_SIZE"
elif HUGEPAGE_SIZE=$(oc get nodes -o jsonpath='{.items[0].status.allocatable.hugepages-2Mi}' 2>/dev/null) && [ -n "$HUGEPAGE_SIZE" ]; then
    HAS_HUGEPAGES=true
    success "HugePages available: $HUGEPAGE_SIZE (2Mi)"
else
    warning "HugePages not available"
    info "Using regular memory allocation"
fi

echo ""

# Determine CPU mode
# Check if we're on a virtualized instance (emulation mode)
# host-passthrough requires KVM which isn't available on virtualized instances
EMULATION_MODE=$(oc get kubevirt -n openshift-cnv kubevirt-kubevirt-hyperconverged -o jsonpath='{.spec.configuration.developerConfiguration.useEmulation}' 2>/dev/null || echo "false")

if [ "$HAS_PERF_PROFILE" = true ] && [ "$EMULATION_MODE" != "true" ]; then
    # Use host-passthrough only if we have Performance Profile AND hardware virtualization (KVM)
    CPU_MODE="host-passthrough"
    info "Using CPU mode: host-passthrough (best performance with CPU pinning and KVM)"
elif [ "$EMULATION_MODE" = "true" ]; then
    # Virtualized instances (m5.4xlarge) - must use host-model
    CPU_MODE="host-model"
    warning "Virtualized instance detected (emulation mode)"
    info "Using CPU mode: host-model (required for software emulation/QEMU TCG)"
    if [ "$HAS_PERF_PROFILE" = true ]; then
        warning "Performance Profile exists but host-passthrough not available on virtualized instances"
        info "host-model will be used instead (compatible with software emulation)"
    fi
else
    CPU_MODE="host-model"
    info "Using CPU mode: host-model (better compatibility)"
fi

echo ""
echo -e "${YELLOW}🚀 Generating VMI configuration...${NC}"
echo ""

# Generate VMI YAML
cat > "$OUTPUT_FILE" << EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  name: $VMI_NAME
  namespace: $NAMESPACE
  labels:
    app: $VMI_NAME
    performance-optimized: "$HAS_PERF_PROFILE"
spec:
  domain:
    cpu:
      cores: $CPUS
      model: $CPU_MODE
EOF

# Add CPU pinning if Performance Profile exists
if [ "$HAS_PERF_PROFILE" = true ]; then
    cat >> "$OUTPUT_FILE" << EOF
      dedicatedCpuPlacement: true  # Pin CPUs to isolated cores
EOF
fi

# Add memory configuration
cat >> "$OUTPUT_FILE" << EOF
    memory:
EOF

# Add HugePages if available
if [ "$HAS_HUGEPAGES" = true ]; then
    if [[ "$HUGEPAGE_SIZE" == *"Gi"* ]]; then
        cat >> "$OUTPUT_FILE" << EOF
      hugepages:
        pageSize: 1Gi  # Use 1GB HugePages for reduced latency
EOF
    else
        cat >> "$OUTPUT_FILE" << EOF
      hugepages:
        pageSize: 2Mi  # Use 2MB HugePages for reduced latency
EOF
    fi
fi

cat >> "$OUTPUT_FILE" << EOF
      guest: $MEMORY
    devices:
      disks:
        - name: containerdisk
          disk:
            bus: virtio
        - name: cloudinitdisk
          disk:
            bus: virtio
      interfaces:
        - name: default
          masquerade: {}
      rng: {}  # Random number generator for better entropy
  networks:
    - name: default
      pod: {}
  volumes:
    - name: containerdisk
      containerDisk:
        image: quay.io/containerdisks/fedora:latest
    - name: cloudinitdisk
      cloudInitNoCloud:
        userData: |
          #cloud-config
          password: fedora
          chpasswd: { expire: False }
          ssh_pwauth: True
          disable_root: false
EOF

success "VMI configuration generated: $OUTPUT_FILE"
echo ""

# Display configuration summary
echo -e "${GREEN}📊 Configuration Summary:${NC}"
echo "───────────────────────────────────────────────────────"
echo "  VMI Name: $VMI_NAME"
echo "  Namespace: $NAMESPACE"
echo "  CPUs: $CPUS"
echo "  Memory: $MEMORY"
echo "  CPU Mode: $CPU_MODE"

if [ "$HAS_PERF_PROFILE" = true ]; then
    echo "  CPU Pinning: ✅ Enabled (dedicatedCpuPlacement: true)"
    echo "  Isolated CPUs: $ISOLATED_CPUS"
else
    echo "  CPU Pinning: ❌ Disabled (no Performance Profile)"
fi

if [ "$HAS_HUGEPAGES" = true ]; then
    echo "  HugePages: ✅ Enabled ($HUGEPAGE_SIZE)"
else
    echo "  HugePages: ❌ Disabled (not available)"
fi

echo "───────────────────────────────────────────────────────"
echo ""

# Educational feedback
if [ "$HAS_PERF_PROFILE" = false ]; then
    echo -e "${YELLOW}🎯 Performance Tip:${NC}"
    echo "   For optimal VMI performance, consider completing Module 4 first."
    echo "   Performance profiles will enable:"
    echo "   • dedicatedCpuPlacement: true (guaranteed CPU access)"
    echo "   • HugePages support (reduced memory latency)"
    echo "   • CPU isolation (eliminates noisy neighbor effects)"
    echo "   • Faster VMI startup times (up to 50% improvement)"
    echo ""
    echo "   You can continue with default settings or go back to Module 4."
    echo ""
fi

# Next steps
echo -e "${CYAN}📋 Next Steps:${NC}"
echo "  1. Review the generated configuration: cat $OUTPUT_FILE"
echo "  2. Create the VMI: oc apply -f $OUTPUT_FILE"
echo "  3. Wait for VMI to start: oc wait --for=condition=Ready vmi/$VMI_NAME --timeout=300s"
echo "  4. Access the VMI: virtctl console $VMI_NAME"
echo ""

success "VMI configuration complete!"

