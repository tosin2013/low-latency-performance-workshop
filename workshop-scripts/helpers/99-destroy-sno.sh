#!/bin/bash
# Destroy/cleanup a single SNO deployment

set -e

STUDENT_NAME=${1:-user1}
DEPLOYMENT_MODE=${2:-rhpds}

AGNOSTICD_DIR=~/agnosticd
SECRETS_FILE=~/secrets-ec2.yml
CONFIG_DIR=~/low-latency-performance-workshop/agnosticd-configs/low-latency-workshop-sno

# Validate mode
if [[ "${DEPLOYMENT_MODE}" != "rhpds" && "${DEPLOYMENT_MODE}" != "standalone" ]]; then
    echo "Error: Deployment mode must be 'rhpds' or 'standalone'"
    echo "Usage: $0 <student_name> <rhpds|standalone>"
    exit 1
fi

echo "============================================"
echo " Destroy SNO Deployment"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: workshop-${STUDENT_NAME}"
echo "Mode: ${DEPLOYMENT_MODE}"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/4] Checking prerequisites..."

# Check ansible-navigator
if ! command -v ansible-navigator &> /dev/null; then
    echo "Error: ansible-navigator not found"
    echo "Run: ./01-setup-ansible-navigator.sh"
    exit 1
fi
echo "✓ ansible-navigator available"

# Check secrets file
if [ ! -f ${SECRETS_FILE} ]; then
    echo "Error: ${SECRETS_FILE} not found"
    echo "Run: ./02-configure-aws-credentials.sh"
    exit 1
fi
echo "✓ Secrets file exists"

# Check AgnosticD
if [ ! -d ${AGNOSTICD_DIR} ]; then
    echo "Error: AgnosticD not found at ${AGNOSTICD_DIR}"
    exit 1
fi
echo "✓ AgnosticD repository found"

# ============================================
# Set Environment
# ============================================
echo ""
echo "[2/4] Setting up environment..."

# Select sample vars based on mode
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    # Export hub details for RHACM cleanup
    export HUB_API_URL=$(oc whoami --show-server 2>/dev/null || echo "")
    export HUB_KUBECONFIG=~/.kube/config
    
    echo "Mode: RHPDS (will remove from RHACM hub)"
    if [ -n "${HUB_API_URL}" ]; then
        echo "Hub API: ${HUB_API_URL}"
    else
        echo "Warning: Not logged into hub cluster"
    fi
    
    SAMPLE_VARS_FILE="ansible/configs/low-latency-workshop-sno/sample_vars/rhpds.yml"
else
    echo "Mode: Standalone (no hub cleanup)"
    SAMPLE_VARS_FILE="ansible/configs/low-latency-workshop-sno/sample_vars/standalone.yml"
fi

# ============================================
# Copy Config to AgnosticD
# ============================================
echo ""
echo "[3/4] Copying workshop config to AgnosticD..."

# Remove old config if exists
rm -rf ${AGNOSTICD_DIR}/ansible/configs/low-latency-workshop-sno

# Copy our config
cp -r ${CONFIG_DIR} ${AGNOSTICD_DIR}/ansible/configs/

echo "✓ Config copied"

# ============================================
# Destroy SNO
# ============================================
echo ""
echo "[4/4] Destroying SNO cluster..."
echo ""
echo "This will remove all AWS resources for ${STUDENT_NAME}"
echo "Log file: /tmp/destroy-${STUDENT_NAME}.log"
echo ""

cd ${AGNOSTICD_DIR}

# Extract AWS credentials from secrets file
AWS_ACCESS_KEY=$(grep "aws_access_key_id:" ${SECRETS_FILE} | awk '{print $2}')
AWS_SECRET_KEY=$(grep "aws_secret_access_key:" ${SECRETS_FILE} | awk '{print $2}')
AWS_REGION=$(grep "aws_region:" ${SECRETS_FILE} | awk '{print $2}')

echo "✓ AWS credentials extracted from secrets file"
echo "  Region: ${AWS_REGION}"

# Export AWS credentials as environment variables (for --penv to pass through)
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

# Build ansible-navigator command for destroy
ANSIBLE_NAVIGATOR_CMD="ansible-navigator run ansible/main.yml \
  --mode stdout \
  --pull-policy missing \
  --eev ${HOME}/.kube:/home/runner/.kube:z \
  --eev ${SECRETS_FILE}:/runner/secrets-ec2.yml:z \
  --penv AWS_ACCESS_KEY_ID \
  --penv AWS_SECRET_ACCESS_KEY \
  --penv AWS_DEFAULT_REGION \
  -e @${SAMPLE_VARS_FILE} \
  -e @/runner/secrets-ec2.yml \
  -e env_type=low-latency-workshop-sno \
  -e ACTION=destroy \
  -e guid=workshop-${STUDENT_NAME} \
  -e student_name=${STUDENT_NAME}"

# Add hub details for RHPDS mode
if [ "${DEPLOYMENT_MODE}" == "rhpds" ] && [ -n "${HUB_API_URL}" ]; then
    ANSIBLE_NAVIGATOR_CMD="${ANSIBLE_NAVIGATOR_CMD} \
  -e HUB_API_URL=\"${HUB_API_URL}\" \
  -e HUB_KUBECONFIG=\"/home/runner/.kube/config\""
fi

# Run destroy
echo "Running ansible-navigator with AgnosticD destroy action..."
echo ""
eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee /tmp/destroy-${STUDENT_NAME}.log

# ============================================
# Verification
# ============================================
echo ""
echo "============================================"
echo " Destroy Summary"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: workshop-${STUDENT_NAME}"
echo "Mode: ${DEPLOYMENT_MODE}"
echo "Log: /tmp/destroy-${STUDENT_NAME}.log"
echo ""

if [ "${DEPLOYMENT_MODE}" == "rhpds" ] && [ -n "${HUB_API_URL}" ]; then
    echo "To verify RHACM cleanup:"
    echo "  oc get managedcluster workshop-${STUDENT_NAME}"
    echo "  (should return: NotFound)"
    echo ""
fi

echo "To verify AWS cleanup:"
echo "  aws ec2 describe-instances --region ${AWS_REGION} --filters \"Name=tag:guid,Values=workshop-${STUDENT_NAME}\""
echo "  (should return: empty or terminated)"
echo ""
echo "To verify VPC cleanup:"
echo "  aws ec2 describe-vpcs --region ${AWS_REGION} --filters \"Name=tag:guid,Values=workshop-${STUDENT_NAME}\""
echo "  (should return: empty)"
echo ""

echo "✅ Destroy command completed"
echo ""


