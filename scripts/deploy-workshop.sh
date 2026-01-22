#!/bin/bash
#
# Deploy Workshop - Hub + Spoke Architecture
#
# This script orchestrates the deployment of the Low-Latency Performance Workshop
# using the Hub + Spoke architecture:
#   1. Deploys student SNO clusters FIRST (generates credentials)
#   2. Collects credentials from each deployment
#   3. Deploys Hub cluster SECOND (with collected credentials)
#
# Usage:
#   ./deploy-workshop.sh --hub-account sandbox1111 --student-account sandbox2222 --students student1,student2,student3
#

set -euo pipefail

# Default values
HUB_ACCOUNT=""
STUDENT_ACCOUNT=""
STUDENTS=""
DRY_RUN=false
AGNOSTICD_DIR="${AGNOSTICD_DIR:-$HOME/Development/agnosticd-v2}"
OUTPUT_DIR="${AGNOSTICD_OUTPUT_DIR:-$HOME/Development/agnosticd-v2-output}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hub-account)
            HUB_ACCOUNT="$2"
            shift 2
            ;;
        --student-account)
            STUDENT_ACCOUNT="$2"
            shift 2
            ;;
        --students)
            STUDENTS="$2"
            shift 2
            ;;
        --agnosticd-dir)
            AGNOSTICD_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --hub-account ACCOUNT      AWS account for Hub cluster (required)"
            echo "  --student-account ACCOUNT AWS account for Student SNO clusters (required)"
            echo "  --students LIST           Comma-separated list of student GUIDs (required)"
            echo "  --agnosticd-dir DIR       AgnosticD v2 directory (default: ~/Development/agnosticd-v2)"
            echo "  --output-dir DIR          Output directory (default: ~/Development/agnosticd-v2-output)"
            echo "  --dry-run                 Show commands that would be executed without deploying"
            echo "  --help, -h                Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --hub-account sandbox1111 --student-account sandbox2222 --students student1,student2,student3"
            echo "  $0 --hub-account sandbox1111 --student-account sandbox2222 --students student1,student2 --dry-run"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$HUB_ACCOUNT" ] || [ -z "$STUDENT_ACCOUNT" ] || [ -z "$STUDENTS" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Use --help for usage information"
    exit 1
fi

# Check if AgnosticD directory exists
if [ ! -d "$AGNOSTICD_DIR" ]; then
    echo -e "${RED}Error: AgnosticD directory not found: $AGNOSTICD_DIR${NC}"
    exit 1
fi

# Check if agd script exists
if [ ! -f "$AGNOSTICD_DIR/bin/agd" ]; then
    echo -e "${RED}Error: agd script not found: $AGNOSTICD_DIR/bin/agd${NC}"
    exit 1
fi

# Ensure config files are available in AgnosticD directory
# Calculate script directory early (before any cd commands)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSHOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_SOURCE_DIR="$WORKSHOP_DIR/agnosticd-v2-vars"
CONFIG_TARGET_DIR="$AGNOSTICD_DIR/agnosticd-v2-vars"

if [ -d "$CONFIG_SOURCE_DIR" ]; then
    mkdir -p "$CONFIG_TARGET_DIR"
    echo -e "${BLUE}Copying config files to AgnosticD...${NC}"
    cp -u "$CONFIG_SOURCE_DIR"/*.yml "$CONFIG_TARGET_DIR/" 2>/dev/null || true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Low-Latency Performance Workshop${NC}"
echo -e "${BLUE}Hub + Spoke Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Hub Account: ${GREEN}$HUB_ACCOUNT${NC}"
echo -e "Student Account: ${GREEN}$STUDENT_ACCOUNT${NC}"
echo -e "Students: ${GREEN}$STUDENTS${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Mode: DRY-RUN (no actual deployment)${NC}"
fi
echo ""

# Helper function to execute commands with dry-run support
execute_cmd() {
    local cmd=("$@")
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would execute:${NC}"
        echo "  ${cmd[*]}"
        echo ""
        return 0
    else
        "${cmd[@]}"
    fi
}

# Convert comma-separated students to array
IFS=',' read -ra STUDENT_ARRAY <<< "$STUDENTS"

# ===================================================================
# STEP 1: Deploy Student SNO Clusters
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 1: Deploying Student SNO Clusters${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

for student in "${STUDENT_ARRAY[@]}"; do
    student=$(echo "$student" | xargs) # Trim whitespace
    user_info_file="$OUTPUT_DIR/$student/provision-user-info.yaml"
    
    # Check if cluster already exists
    if [ -f "$user_info_file" ]; then
        echo -e "${BLUE}Checking existing deployment for: ${GREEN}$student${NC}"
        bastion=$(grep -oP 'bastion\.\S+\.opentlc\.com' "$user_info_file" | head -1 || echo "")
        if [ -n "$bastion" ]; then
            echo -e "${YELLOW}⚠️  SNO cluster for $student already exists (bastion: $bastion)${NC}"
            echo -e "${YELLOW}   Skipping deployment - using existing cluster${NC}"
            echo ""
            continue
        fi
    fi
    
    echo -e "${BLUE}Deploying SNO cluster for: ${GREEN}$student${NC}"
    
    cd "$AGNOSTICD_DIR"
    execute_cmd ./bin/agd provision -g "$student" -c low-latency-sno-aws -a "$STUDENT_ACCOUNT" || {
        echo -e "${RED}Failed to deploy SNO cluster for $student${NC}"
        exit 1
    }
    
    if [ "$DRY_RUN" != true ]; then
        echo -e "${GREEN}✓ SNO cluster deployed for $student${NC}"
    else
        echo -e "${GREEN}✓ [DRY-RUN] SNO cluster deployment skipped for $student${NC}"
    fi
    echo ""
done

# ===================================================================
# STEP 2: Collect Student Credentials
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 2: Collecting Student Credentials${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

declare -A STUDENT_BASTIONS
declare -A STUDENT_CONSOLES

for student in "${STUDENT_ARRAY[@]}"; do
    student=$(echo "$student" | xargs) # Trim whitespace
    user_info_file="$OUTPUT_DIR/$student/provision-user-info.yaml"
    
    if [ ! -f "$user_info_file" ]; then
        echo -e "${RED}Error: Credentials file not found: $user_info_file${NC}"
        exit 1
    fi
    
    # Extract bastion hostname
    bastion=$(grep -oP 'bastion\.\S+\.opentlc\.com' "$user_info_file" | head -1 || echo "")
    if [ -z "$bastion" ]; then
        echo -e "${RED}Error: Could not extract bastion hostname for $student${NC}"
        exit 1
    fi
    
    # Extract console URL
    console=$(grep -oP 'https://console-openshift-console\.apps\.\S+' "$user_info_file" | head -1 || echo "")
    
    STUDENT_BASTIONS["$student"]="$bastion"
    STUDENT_CONSOLES["$student"]="$console"
    
    echo -e "${GREEN}✓ Collected credentials for $student${NC}"
    echo "  Bastion: $bastion"
    echo "  Console: $console"
    echo ""
done

# ===================================================================
# STEP 3: Configure OpenShift Virtualization for Virtualized Instances
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 3: Configuring OpenShift Virtualization${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${BLUE}Applying KVM emulation patch for virtualized instances (non-bare-metal)${NC}"
echo -e "${BLUE}This enables OpenShift Virtualization on EC2 instances like m5.4xlarge${NC}"
echo ""

for student in "${STUDENT_ARRAY[@]}"; do
    student=$(echo "$student" | xargs) # Trim whitespace
    kubeconfig_file="$OUTPUT_DIR/$student/openshift-cluster_${student}_kubeconfig"
    
    if [ ! -f "$kubeconfig_file" ]; then
        echo -e "${YELLOW}⚠️  Kubeconfig not found for $student - skipping OCP Virt config${NC}"
        continue
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would configure OpenShift Virtualization for $student${NC}"
        continue
    fi
    
    export KUBECONFIG="$kubeconfig_file"
    
    # Check if cluster is accessible
    if ! oc get nodes &>/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Cannot connect to $student cluster - skipping OCP Virt config${NC}"
        continue
    fi
    
    # Check if this is a virtualized instance (not bare-metal)
    INSTANCE_TYPE=$(oc get nodes -o jsonpath='{.items[0].metadata.labels.node\.kubernetes\.io/instance-type}' 2>/dev/null || echo "unknown")
    
    if [[ "$INSTANCE_TYPE" == *"metal"* ]]; then
        echo -e "${CYAN}ℹ️  $student: Bare-metal instance ($INSTANCE_TYPE) - emulation not needed${NC}"
        continue
    fi
    
    echo -e "${BLUE}Configuring $student (instance type: $INSTANCE_TYPE)...${NC}"
    
    # Wait for HyperConverged CR to exist (max 60 seconds)
    echo -e "  ${CYAN}Waiting for HyperConverged CR...${NC}"
    HCO_READY=false
    for i in {1..30}; do
        if oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv &>/dev/null 2>&1; then
            HCO_READY=true
            break
        fi
        sleep 2
    done
    
    if [ "$HCO_READY" != true ]; then
        echo -e "${YELLOW}⚠️  HyperConverged CR not found for $student - OCP Virt may still be installing${NC}"
        echo -e "   ${YELLOW}You can apply the patch manually later:${NC}"
        echo -e "   ${YELLOW}export KUBECONFIG=$kubeconfig_file${NC}"
        echo -e "   ${YELLOW}oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type merge -p '...patch...'${NC}"
        continue
    fi
    
    # Apply the KVM emulation patch
    if oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type merge -p \
        '{"metadata":{"annotations":{"kubevirt.kubevirt.io/jsonpatch":"[{\"op\":\"add\",\"path\":\"/spec/configuration/developerConfiguration/useEmulation\",\"value\":true}]"}}}' 2>/dev/null; then
        echo -e "${GREEN}✓ KVM emulation patch applied for $student${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not apply emulation patch for $student${NC}"
    fi
    echo ""
done

# Allow virt-handler pods to restart with new configuration
if [ "$DRY_RUN" != true ]; then
    echo -e "${CYAN}Waiting 15 seconds for virt-handler pods to detect emulation config...${NC}"
    sleep 15
fi
echo ""

# ===================================================================
# STEP 4: Deploy Hub Cluster
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 4: Deploying Hub Cluster${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${BLUE}Note: Student credentials are collected but not passed to Hub deployment.${NC}"
echo -e "${BLUE}      Per-student Showroom instances will be configured later using deploy-student-showrooms.sh${NC}"
echo ""

cd "$AGNOSTICD_DIR"

# Deploy Hub cluster (no extra vars needed - Showroom is configured later)
HUB_CMD=(./bin/agd provision -g hub -c workshop-hub-aws -a "$HUB_ACCOUNT")

# Execute with dry-run support
execute_cmd "${HUB_CMD[@]}" || {
    echo -e "${RED}Failed to deploy Hub cluster${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Note: This was a dry-run, so no actual deployment occurred${NC}"
    fi
    exit 1
}

if [ "$DRY_RUN" != true ]; then
    echo -e "${GREEN}✓ Hub cluster deployed${NC}"
else
    echo -e "${GREEN}✓ [DRY-RUN] Hub cluster deployment skipped${NC}"
fi
echo ""

# ===================================================================
# STEP 5: Deploy Per-Student Showroom Instances
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 5: Deploying Per-Student Showrooms${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

SHOWROOM_SCRIPT="$SCRIPT_DIR/deploy-student-showrooms.sh"

if [ -f "$SHOWROOM_SCRIPT" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would run: $SHOWROOM_SCRIPT --students $STUDENTS${NC}"
        echo -e "${GREEN}✓ [DRY-RUN] Per-student Showroom deployment skipped${NC}"
    else
        echo -e "${BLUE}Running: $SHOWROOM_SCRIPT --students $STUDENTS${NC}"
        "$SHOWROOM_SCRIPT" --students "$STUDENTS" || {
            echo -e "${YELLOW}⚠️  Per-student Showroom deployment had issues${NC}"
            echo -e "${YELLOW}   You can retry manually: $SHOWROOM_SCRIPT --students $STUDENTS${NC}"
        }
        echo -e "${GREEN}✓ Per-student Showrooms deployed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  deploy-student-showrooms.sh not found at $SHOWROOM_SCRIPT${NC}"
    echo -e "${YELLOW}   Skipping per-student Showroom deployment${NC}"
fi
echo ""

# ===================================================================
# STEP 6: Output Access Information
# ===================================================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}STEP 6: Access Information${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Get Hub information
hub_user_info="$OUTPUT_DIR/hub/provision-user-info.yaml"
hub_kubeconfig="$OUTPUT_DIR/hub/openshift-cluster_hub_kubeconfig"

if [ -f "$hub_user_info" ]; then
    hub_console=$(grep -oP 'https://console-openshift-console\.apps\.\S+' "$hub_user_info" | head -1 || echo "")
    
    echo -e "${GREEN}Hub Cluster:${NC}"
    echo "  Console: $hub_console"
    echo ""
fi

# Get ingress domain for Showroom URLs
INGRESS_DOMAIN=""
if [ -f "$hub_kubeconfig" ]; then
    export KUBECONFIG="$hub_kubeconfig"
    INGRESS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")
fi

echo -e "${GREEN}Student Workshop URLs:${NC}"
for student in "${STUDENT_ARRAY[@]}"; do
    student=$(echo "$student" | xargs) # Trim whitespace
    if [ -n "$INGRESS_DOMAIN" ]; then
        echo -e "  ${BLUE}$student${NC}: https://${student}-workshop-low-latency-workshop.${INGRESS_DOMAIN}/"
    else
        echo -e "  ${BLUE}$student${NC}: (Showroom URL available after cluster is ready)"
    fi
done
echo ""

echo -e "${GREEN}Student SNO Clusters:${NC}"
for student in "${STUDENT_ARRAY[@]}"; do
    student=$(echo "$student" | xargs) # Trim whitespace
    echo "  $student:"
    echo "    Bastion: ${STUDENT_BASTIONS[$student]}"
    echo "    Console: ${STUDENT_CONSOLES[$student]}"
    echo "    Password: (available in ~/Development/agnosticd-v2-output/$student/provision-user-info.yaml)"
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Each student can access their workshop at:"
echo "  https://<student>-workshop-low-latency-workshop.<ingress-domain>/"
echo ""
echo "The workshop includes:"
echo "  - Workshop documentation (left panel)"
echo "  - Terminal connected to their bastion (right panel)"


