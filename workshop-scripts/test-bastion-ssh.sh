#!/bin/bash
# Test SSH connectivity to bastion after deployment

set -e

STUDENT_NAME=${1:-student1}
GUID="test-${STUDENT_NAME}"
AWS_REGION="us-east-2"
# AgnosticD creates keys with format: ssh_provision_${GUID}
SSH_KEY="${HOME}/agnosticd-output/${GUID}/ssh_provision_${GUID}"
MAX_RETRIES=30
RETRY_DELAY=10

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🔍 BASTION SSH CONNECTIVITY TEST                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "GUID: ${GUID}"
echo "Region: ${AWS_REGION}"
echo ""

# Step 1: Find bastion instance
echo "[1/4] Finding bastion instance..."
BASTION_IP=$(aws ec2 describe-instances \
  --region ${AWS_REGION} \
  --filters \
    "Name=tag:guid,Values=${GUID}" \
    "Name=tag:AnsibleGroup,Values=bastions" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null)

if [ -z "${BASTION_IP}" ] || [ "${BASTION_IP}" == "None" ]; then
    echo "  ✗ ERROR: Bastion instance not found!"
    echo ""
    echo "Debugging info:"
    echo "  Checking all instances with guid=${GUID}:"
    aws ec2 describe-instances \
      --region ${AWS_REGION} \
      --filters "Name=tag:guid,Values=${GUID}" \
      --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
      --output table
    exit 1
fi

echo "  ✓ Bastion found: ${BASTION_IP}"

# Step 2: Check SSH key exists
echo ""
echo "[2/4] Checking SSH key..."
if [ ! -f "${SSH_KEY}" ]; then
    echo "  ✗ ERROR: SSH key not found at ${SSH_KEY}"
    echo ""
    echo "Checking output directory contents:"
    ls -la "${HOME}/agnosticd-output/${GUID}/" 2>&1 | head -20
    exit 1
fi

echo "  ✓ SSH key found: ${SSH_KEY}"
chmod 600 "${SSH_KEY}"

# Step 3: Wait for SSH to be ready
echo ""
echo "[3/4] Waiting for SSH to be ready (max ${MAX_RETRIES} attempts)..."
ATTEMPT=1
while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo -n "  Attempt ${ATTEMPT}/${MAX_RETRIES}: "
    
    if ssh -i "${SSH_KEY}" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o ConnectTimeout=5 \
           -q \
           ec2-user@${BASTION_IP} \
           "echo 'SSH_OK'" >/dev/null 2>&1; then
        echo "✓ SSH connection successful!"
        break
    else
        if [ $ATTEMPT -eq $MAX_RETRIES ]; then
            echo "✗ Failed after ${MAX_RETRIES} attempts"
            echo ""
            echo "Debugging steps:"
            echo "  1. Check security group allows SSH from your IP"
            echo "  2. Verify instance is fully initialized (cloud-init complete)"
            echo "  3. Try manual SSH:"
            echo "     ssh -i ${SSH_KEY} ec2-user@${BASTION_IP}"
            exit 1
        fi
        echo "Waiting ${RETRY_DELAY}s..."
        sleep ${RETRY_DELAY}
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

# Step 4: Run connectivity tests
echo ""
echo "[4/4] Running connectivity tests..."

# Test 1: Basic system info
echo ""
echo "  Test 1: System Information"
echo "  ─────────────────────────────"
ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ec2-user@${BASTION_IP} \
    'echo "    Hostname: $(hostname)"; \
     echo "    OS: $(cat /etc/redhat-release)"; \
     echo "    Kernel: $(uname -r)"; \
     echo "    Uptime: $(uptime -p)"'

# Test 2: Required tools
echo ""
echo "  Test 2: Required Tools"
echo "  ─────────────────────────────"
ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ec2-user@${BASTION_IP} \
    "for tool in python3 openshift-install oc; do \
         if command -v \$tool >/dev/null 2>&1; then \
             echo \"    ✓ \$tool: \$(which \$tool)\"; \
         else \
             echo \"    ✗ \$tool: NOT FOUND\"; \
         fi; \
     done"

# Test 3: AWS CLI access (if credentials are passed)
echo ""
echo "  Test 3: AWS CLI Access"
echo "  ─────────────────────────────"
ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ec2-user@${BASTION_IP} \
    "if aws sts get-caller-identity >/dev/null 2>&1; then \
         echo '    ✓ AWS credentials configured'; \
         aws sts get-caller-identity --query 'Account' --output text | sed 's/^/    Account: /'; \
     else \
         echo '    ⚠️  AWS credentials not configured (will need to be passed)'; \
     fi" 2>/dev/null || echo "    ⚠️  AWS CLI not configured yet"

# Test 4: Disk space
echo ""
echo "  Test 4: Disk Space"
echo "  ─────────────────────────────"
ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ec2-user@${BASTION_IP} \
    "df -h / | tail -1 | awk '{print \"    Root: \" \$2 \" total, \" \$4 \" available (\" \$5 \" used)\"}'"

# Success summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ BASTION SSH CONNECTIVITY TEST PASSED                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Bastion Details:"
echo "  IP Address: ${BASTION_IP}"
echo "  SSH Key: ${SSH_KEY}"
echo "  SSH Command:"
echo "    ssh -i ${SSH_KEY} ec2-user@${BASTION_IP}"
echo ""
echo "Bastion is ready for OpenShift installation!"
echo ""

