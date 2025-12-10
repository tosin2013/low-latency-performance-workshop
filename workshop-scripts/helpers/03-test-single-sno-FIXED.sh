#!/bin/bash
# Test deployment of a single student SNO cluster
# FIXED VERSION: Properly exits on failure without retries
#
# Usage: 
#   ./03-test-single-sno-FIXED.sh [student_name] [mode]
#
# Examples:
#   ./03-test-single-sno-FIXED.sh user1           # RHPDS mode (default, with hub integration)
#   ./03-test-single-sno-FIXED.sh user1 rhpds     # RHPDS mode (explicit)
#   ./03-test-single-sno-FIXED.sh user1 standalone # Standalone mode (no hub integration)

# EXIT ON ERROR - CRITICAL FIX
set -e          # Exit immediately if a command exits with a non-zero status
set -o pipefail # Return value of a pipeline is the status of the last command to exit with a non-zero status
set -u          # Treat unset variables as an error

STUDENT_NAME=${1:-user1}
DEPLOYMENT_MODE=${2:-rhpds}  # rhpds or standalone
AGNOSTICD_DIR=~/agnosticd
WORKSHOP_DIR=/home/lab-user/low-latency-performance-workshop
SECRETS_FILE=~/secrets-ec2.yml
CONFIG_DIR=${WORKSHOP_DIR}/agnosticd-configs/low-latency-workshop-sno

echo "============================================"
echo " Test SNO Deployment (FAILURE-SAFE VERSION)"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: test-${STUDENT_NAME}"
echo "Mode: ${DEPLOYMENT_MODE}"
echo ""

# Validate deployment mode
if [[ "${DEPLOYMENT_MODE}" != "rhpds" && "${DEPLOYMENT_MODE}" != "standalone" ]]; then
    echo "✗ Invalid deployment mode: ${DEPLOYMENT_MODE}"
    echo "Valid modes: rhpds, standalone"
    exit 1
fi

# ============================================
# Prerequisites Check
# ============================================
echo "[1/5] Checking prerequisites..."

# Check ansible-navigator
if ! command -v ansible-navigator &> /dev/null; then
    echo "✗ ansible-navigator not found"
    echo "Run: ./01-setup-ansible-navigator.sh"
    exit 1
fi
echo "✓ ansible-navigator available"

# Check secrets file
if [ ! -f ${SECRETS_FILE} ]; then
    echo "✗ Secrets file not found: ${SECRETS_FILE}"
    echo "Run: ./02-configure-aws-credentials.sh"
    exit 1
fi
echo "✓ Secrets file exists"

# Check AgnosticD
if [ ! -d ${AGNOSTICD_DIR} ]; then
    echo "✗ AgnosticD directory not found: ${AGNOSTICD_DIR}"
    echo "Clone: git clone https://github.com/tosin2013/agnosticd.git ~/agnosticd"
    exit 1
fi
echo "✓ AgnosticD repository found"

# Check hub cluster access (only for RHPDS mode)
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    if ! oc whoami &> /dev/null; then
        echo "✗ Not logged into hub cluster (required for RHPDS mode)"
        echo "Run: oc login <hub-api-url>"
        echo "Or use standalone mode: ./03-test-single-sno-FIXED.sh ${STUDENT_NAME} standalone"
        exit 1
    fi
    echo "✓ Logged into hub cluster: $(oc whoami --show-server)"
    
    # Check RHACM
    if ! oc get multiclusterhub -n open-cluster-management &> /dev/null; then
        echo "⚠ RHACM not found - SNO will deploy but not auto-import"
    fi
else
    echo "ℹ Standalone mode - skipping hub cluster check"
fi

# ============================================
# Export Hub Details (RHPDS mode only)
# ============================================
echo ""
echo "[2/5] Setting up deployment environment..."

if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    export HUB_API_URL=$(oc whoami --show-server)
    export HUB_KUBECONFIG=~/.kube/config
    
    echo "Mode: RHPDS (with hub integration)"
    echo "Hub API: ${HUB_API_URL}"
    echo "Kubeconfig: ${HUB_KUBECONFIG}"
    
    SAMPLE_VARS_FILE="ansible/configs/low-latency-workshop-sno/sample_vars/rhpds.yml"
else
    echo "Mode: Standalone (no hub integration)"
    echo "Hub integration: Disabled"
    
    SAMPLE_VARS_FILE="ansible/configs/low-latency-workshop-sno/sample_vars/standalone.yml"
fi

# ============================================
# Copy Config to AgnosticD
# ============================================
echo ""
echo "[3/5] Copying workshop config to AgnosticD..."

# Remove old config if exists
rm -rf ${AGNOSTICD_DIR}/ansible/configs/low-latency-workshop-sno

# Copy our config
cp -r ${CONFIG_DIR} ${AGNOSTICD_DIR}/ansible/configs/

echo "✓ Config copied"

# ============================================
# Deploy SNO
# ============================================
echo ""
echo "[4/5] Deploying SNO cluster..."
echo ""
echo "This will take approximately 30-45 minutes"
echo "Log file: /tmp/test-${STUDENT_NAME}.log"
echo ""

cd ${AGNOSTICD_DIR}

# Setup output directory for SSH keys and kubeconfig
OUTPUT_DIR="${HOME}/agnosticd-output"
mkdir -p ${OUTPUT_DIR}
echo "✓ Output directory prepared: ${OUTPUT_DIR}"
echo "  SSH keys and kubeconfig will be saved here"

# Extract AWS credentials from secrets file for container environment
AWS_ACCESS_KEY=$(grep "aws_access_key_id:" ${SECRETS_FILE} | awk '{print $2}' | tr -d '"')
AWS_SECRET_KEY=$(grep "aws_secret_access_key:" ${SECRETS_FILE} | awk '{print $2}' | tr -d '"')
AWS_REGION=$(grep "aws_region:" ${SECRETS_FILE} | awk '{print $2}' | tr -d '"')

echo "✓ AWS credentials extracted from secrets file"
echo "  Region: ${AWS_REGION}"
echo "  Access Key: ${AWS_ACCESS_KEY:0:8}***"

# Export AWS credentials as environment variables (for --penv to pass through)
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

# Build ansible-navigator command using our custom config
# Pass AWS credentials as environment variables to the container
# Mount output directory so SSH keys and kubeconfig are accessible on host
ANSIBLE_NAVIGATOR_CMD="ansible-navigator run ansible/main.yml \
  --mode stdout \
  --pull-policy missing \
  -vvv \
  --eev ${HOME}/.kube:/home/runner/.kube:z \
  --eev ${SECRETS_FILE}:/runner/secrets-ec2.yml:z \
  --eev ${OUTPUT_DIR}:/runner/agnosticd-output:z \
  --penv AWS_ACCESS_KEY_ID \
  --penv AWS_SECRET_ACCESS_KEY \
  --penv AWS_DEFAULT_REGION \
  -e @${SAMPLE_VARS_FILE} \
  -e @/runner/secrets-ec2.yml \
  -e env_type=low-latency-workshop-sno \
  -e software_to_deploy=openshift4 \
  -e ACTION=provision \
  -e guid=test-${STUDENT_NAME} \
  -e student_name=${STUDENT_NAME} \
  -e output_dir=/runner/agnosticd-output/test-${STUDENT_NAME} \
  -e email=${STUDENT_NAME}@workshop.example.com"

# Add hub details for RHPDS mode
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    ANSIBLE_NAVIGATOR_CMD="${ANSIBLE_NAVIGATOR_CMD} \
  -e rhacm_hub_api=\"${HUB_API_URL}\" \
  -e rhacm_hub_kubeconfig=\"/home/runner/.kube/config\""
fi

# CRITICAL FIX: Capture exit code properly
# Instead of: eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee /tmp/test-${STUDENT_NAME}.log
# We use: Store output AND capture exit code
echo "Running ansible-navigator with AgnosticD provision action..."
echo "This will provision a new SNO cluster on AWS..."
echo ""

# Create a temporary file for the deployment output
DEPLOY_LOG="/tmp/test-${STUDENT_NAME}.log"
DEPLOY_EXIT_CODE=0

# Run deployment and capture BOTH output and exit code
if ! eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee "${DEPLOY_LOG}"; then
    DEPLOY_EXIT_CODE=$?
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ❌ DEPLOYMENT FAILED                                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Ansible playbook exited with code: ${DEPLOY_EXIT_CODE}"
    echo "Log file: ${DEPLOY_LOG}"
    echo ""
    echo "Common causes:"
    echo "  1. AWS service quota exceeded (VPCs, vCPUs, Elastic IPs)"
    echo "  2. Invalid AWS credentials or permissions"
    echo "  3. Network connectivity issues"
    echo "  4. OpenShift pull secret invalid"
    echo ""
    echo "Check the log file for details:"
    echo "  tail -100 ${DEPLOY_LOG}"
    echo ""
    echo "To cleanup partial deployment:"
    echo "  ./99-destroy-sno-complete.sh ${STUDENT_NAME}"
    echo ""
    exit ${DEPLOY_EXIT_CODE}
fi

echo ""
echo "✓ Ansible playbook completed successfully"

# ============================================
# Post-Bastion SSH Test
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🔍 POST-DEPLOYMENT BASTION SSH TEST                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Testing SSH connectivity to bastion..."
echo ""

if [ -f "${WORKSHOP_DIR}/workshop-scripts/test-bastion-ssh.sh" ]; then
    # Run SSH connectivity test
    if ${WORKSHOP_DIR}/workshop-scripts/test-bastion-ssh.sh ${STUDENT_NAME}; then
        echo ""
        echo "✅ Bastion SSH test PASSED!"
        echo ""
    else
        echo ""
        echo "⚠️  Bastion SSH test FAILED!"
        echo "The bastion may not be fully initialized yet, or there's a connectivity issue."
        echo "Check the logs above for details."
        echo ""
        read -p "Continue anyway? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
            echo "Aborted. Fix SSH connectivity before proceeding."
            exit 1
        fi
    fi
else
    echo "⚠️  SSH test script not found, skipping..."
fi

# ============================================
# Verification
# ============================================
echo ""
echo "[5/5] Verifying deployment..."
echo ""

# Check for kubeconfig
KUBECONFIG_PATH=~/agnosticd-output/test-${STUDENT_NAME}/kubeconfig
SSH_KEY_PATH=~/agnosticd-output/test-${STUDENT_NAME}/ssh_provision_test-${STUDENT_NAME}

if [ -f ${KUBECONFIG_PATH} ]; then
    echo "✓ SNO kubeconfig created: ${KUBECONFIG_PATH}"
    
    # Try to access SNO
    echo ""
    echo "Testing SNO cluster access..."
    if oc --kubeconfig=${KUBECONFIG_PATH} get nodes &> /dev/null; then
        echo "✓ SNO cluster accessible"
        oc --kubeconfig=${KUBECONFIG_PATH} get nodes
    else
        echo "⚠ Cannot access SNO yet (may still be provisioning)"
    fi
else
    echo "⚠ Kubeconfig not found - check logs"
fi

# Check for SSH key (AgnosticD format: ssh_provision_${GUID})
echo ""
SSH_KEY_PATH=~/agnosticd-output/test-${STUDENT_NAME}/ssh_provision_test-${STUDENT_NAME}
if [ -f ${SSH_KEY_PATH} ]; then
    echo "✓ SSH key created: ${SSH_KEY_PATH}"
    chmod 600 ${SSH_KEY_PATH}
    
    # Get bastion IP
    BASTION_IP=$(aws ec2 describe-instances \
      --region ${AWS_REGION} \
      --filters "Name=tag:guid,Values=test-${STUDENT_NAME}" "Name=tag:Name,Values=bastion" "Name=instance-state-name,Values=running" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text 2>/dev/null)
    
    if [ -n "${BASTION_IP}" ] && [ "${BASTION_IP}" != "None" ]; then
        echo "✓ Bastion IP: ${BASTION_IP}"
        echo ""
        echo "To SSH into bastion:"
        echo "  ssh -i ${SSH_KEY_PATH} ec2-user@${BASTION_IP}"
    fi
else
    echo "⚠ SSH key not found - check logs"
fi

# Check RHACM import (RHPDS mode only)
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo ""
    echo "Checking RHACM import..."
    RHACM_IMPORT_SUCCESS=false
    
    if oc get managedcluster workshop-${STUDENT_NAME} &> /dev/null; then
        echo "✓ ManagedCluster created"
        
        # Check status
        STATUS=$(oc get managedcluster workshop-${STUDENT_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "Unknown")
        if [ "${STATUS}" == "True" ]; then
            echo "✓ Cluster is Ready"
            RHACM_IMPORT_SUCCESS=true
        else
            echo "⚠ Cluster not yet Ready (may still be importing)"
        fi
        
        # Show details
        echo ""
        oc get managedcluster workshop-${STUDENT_NAME}
    else
        echo "⚠ ManagedCluster not found - auto-import may have failed"
    fi
else
    echo ""
    echo "ℹ Standalone mode - skipping RHACM import check"
    echo "Access SNO directly via kubeconfig"
fi

echo ""
echo "============================================"
echo " Test Deployment Summary"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: test-${STUDENT_NAME}"
echo "Mode: ${DEPLOYMENT_MODE}"
echo "Status: ✅ SUCCESS"
echo "Log: /tmp/test-${STUDENT_NAME}.log"
echo "Kubeconfig: ${KUBECONFIG_PATH}"
echo ""
echo "To access SNO cluster:"
echo "  oc --kubeconfig=${KUBECONFIG_PATH} get nodes"
echo ""

if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo "To check RHACM status:"
    echo "  oc get managedcluster workshop-${STUDENT_NAME}"
    echo ""
fi

echo "Next steps:"
echo "  1. Verify cluster is fully operational"
echo "  2. Test workshop Module 2 exercises"
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    echo "  3. If successful, deploy for all students:"
    echo "     ./04-provision-student-clusters.sh 30"
else
    echo "  3. Deploy additional clusters as needed"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ DEPLOYMENT COMPLETED SUCCESSFULLY                     ║"
echo "╚════════════════════════════════════════════════════════════╝"

