#!/bin/bash
#
# Recovery Script: Delete Old Performance Profile and Apply New Optimized Configuration
#
# This script:
# 1. Waits for the cluster to become accessible
# 2. Deletes the existing Performance Profile (reverts problematic config)
# 3. Waits for the node to revert
# 4. Runs the updated CPU allocation calculator
# 5. Creates a new Performance Profile with optimized settings
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}=== Performance Profile Recovery Script ===${NC}"
echo "This script will:"
echo "  1. Wait for cluster to become accessible"
echo "  2. Delete existing Performance Profile"
echo "  3. Wait for node to revert configuration"
echo "  4. Apply new optimized Performance Profile"
echo ""

# Step 1: Wait for cluster to be accessible
info "Step 1: Waiting for cluster to become accessible..."
MAX_WAIT=1800  # 30 minutes
WAITED=0
INTERVAL=30

while [ $WAITED -lt $MAX_WAIT ]; do
    if oc whoami &>/dev/null && oc get nodes &>/dev/null; then
        success "Cluster is accessible!"
        break
    fi
    
    if [ $((WAITED % 60)) -eq 0 ] && [ $WAITED -gt 0 ]; then
        info "Still waiting... ($((WAITED/60)) minutes elapsed)"
    fi
    
    sleep $INTERVAL
    WAITED=$((WAITED + INTERVAL))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    error "Cluster did not become accessible within 30 minutes. Please check AWS console."
fi

echo ""
info "Cluster details:"
oc whoami
oc get nodes

# Step 2: Find and delete existing Performance Profile
echo ""
info "Step 2: Looking for existing Performance Profiles..."

EXISTING_PROFILES=$(oc get performanceprofile -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$EXISTING_PROFILES" ]; then
    warning "No Performance Profiles found. Proceeding to create new one."
else
    info "Found Performance Profile(s): $EXISTING_PROFILES"
    
    for profile in $EXISTING_PROFILES; do
        echo ""
        warning "Deleting Performance Profile: $profile"
        oc delete performanceprofile "$profile" || warning "Failed to delete $profile (may already be deleted)"
    done
    
    echo ""
    success "Performance Profile(s) deleted. Node will reboot to revert configuration."
    echo ""
    info "Waiting for node to revert (this will take 10-20 minutes)..."
    echo "   Monitoring node status..."
    
    # Wait for node to be ready after revert
    TARGET_NODE=$(oc get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$TARGET_NODE" ]; then
        info "Waiting for node $TARGET_NODE to be Ready..."
        oc wait --for=condition=Ready node/$TARGET_NODE --timeout=1200s || warning "Node may still be rebooting"
    fi
    
    # Wait for MCP to be updated
    info "Waiting for Machine Config Pool to be updated..."
    oc wait --for=condition=Updated mcp/master --timeout=1200s || warning "MCP may still be updating"
    
    success "Node has reverted to standard configuration"
fi

# Step 3: Run updated CPU allocation calculator
echo ""
info "Step 3: Running updated CPU allocation calculator..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALCULATOR_SCRIPT="$SCRIPT_DIR/module04-calculate-cpu-allocation.sh"

if [ ! -f "$CALCULATOR_SCRIPT" ]; then
    error "CPU allocation calculator not found at $CALCULATOR_SCRIPT"
fi

bash "$CALCULATOR_SCRIPT" || error "CPU allocation calculation failed"

# Step 4: Create new Performance Profile with optimized settings
echo ""
info "Step 4: Creating new optimized Performance Profile..."
PROFILE_SCRIPT="$SCRIPT_DIR/module04-create-performance-profile.sh"

if [ ! -f "$PROFILE_SCRIPT" ]; then
    error "Performance Profile creator not found at $PROFILE_SCRIPT"
fi

echo ""
warning "The new Performance Profile will:"
echo "  - Use more conservative CPU allocation for virtualized instances"
echo "  - Skip 'nosmt' parameter (preserves hyperthreading)"
echo "  - Reserve more CPUs for control plane stability"
echo ""
read -p "Continue with creating new Performance Profile? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    warning "Performance Profile creation cancelled"
    exit 0
fi

bash "$PROFILE_SCRIPT" || error "Performance Profile creation failed"

echo ""
success "Recovery complete! New optimized Performance Profile has been applied."
echo ""
info "The node will reboot again to apply the new configuration."
info "Monitor progress with: oc get nodes && oc get mcp master"
