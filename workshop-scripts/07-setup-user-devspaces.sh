#!/bin/bash
# Update Dev Spaces secrets with real SNO credentials
# Updates kubeconfig and SSH key secrets for each user
#
# Usage:
#   ./07-setup-user-devspaces.sh [num_users]
#
# Examples:
#   ./07-setup-user-devspaces.sh        # Update 5 users (default)
#   ./07-setup-user-devspaces.sh 10     # Update 10 users
#
# Prerequisites:
#   - Run 05-setup-hub-users.sh (creates placeholder secrets)
#   - Run 06-provision-user-snos.sh (deploys SNO clusters)
#
# Idempotent - safe to re-run

set -e

NUM_USERS=${1:-5}
OUTPUT_DIR="${HOME}/agnosticd-output"
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     UPDATE DEV SPACES SECRETS WITH SNO CREDENTIALS         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Users: student1 - student${NUM_USERS}"
echo "  SNO output dir: ${OUTPUT_DIR}"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/3] Checking prerequisites..."

# Check oc CLI
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into OpenShift cluster"
    exit 1
fi
echo "✓ Logged into cluster: $(oc whoami --show-server)"

# Check output directory
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "✗ SNO output directory not found: ${OUTPUT_DIR}"
    echo "Run ./06-provision-user-snos.sh first"
    exit 1
fi
echo "✓ SNO output directory exists"

# Get subdomain suffix
CLUSTER_API=$(oc whoami --show-server)
SUBDOMAIN_SUFFIX=$(echo ${CLUSTER_API} | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
echo "✓ Subdomain suffix: ${SUBDOMAIN_SUFFIX}"

# ============================================
# Update User Secrets
# ============================================
echo ""
echo "[2/3] Updating user secrets..."
echo ""

declare -a UPDATED
declare -a SKIPPED

for i in $(seq 1 ${NUM_USERS}); do
    USER_NAME="student${i}"
    USER_NS="workshop-${USER_NAME}"
    GUID="workshop-${USER_NAME}"
    
    echo "Processing ${USER_NAME}..."
    
    # Check if namespace exists
    if ! oc get namespace ${USER_NS} &>/dev/null; then
        echo "  ⚠ Namespace ${USER_NS} not found - skipping"
        SKIPPED+=("${USER_NAME}")
        continue
    fi
    
    # Find kubeconfig (try multiple paths)
    KUBECONFIG_PATH=""
    if [ -f "${OUTPUT_DIR}/${GUID}/kubeconfig" ]; then
        KUBECONFIG_PATH="${OUTPUT_DIR}/${GUID}/kubeconfig"
    elif [ -f "${OUTPUT_DIR}/${GUID}/low-latency-workshop-sno_${GUID}_kubeconfig" ]; then
        KUBECONFIG_PATH="${OUTPUT_DIR}/${GUID}/low-latency-workshop-sno_${GUID}_kubeconfig"
    elif [ -f "${OUTPUT_DIR}/test-${USER_NAME}/kubeconfig" ]; then
        KUBECONFIG_PATH="${OUTPUT_DIR}/test-${USER_NAME}/kubeconfig"
    elif [ -f "${OUTPUT_DIR}/test-${USER_NAME}/low-latency-workshop-sno_test-${USER_NAME}_kubeconfig" ]; then
        KUBECONFIG_PATH="${OUTPUT_DIR}/test-${USER_NAME}/low-latency-workshop-sno_test-${USER_NAME}_kubeconfig"
    fi
    
    # Find SSH key (try multiple paths)
    SSH_KEY_PATH=""
    if [ -f "${OUTPUT_DIR}/${GUID}/ssh_provision_${GUID}" ]; then
        SSH_KEY_PATH="${OUTPUT_DIR}/${GUID}/ssh_provision_${GUID}"
    elif [ -f "${OUTPUT_DIR}/test-${USER_NAME}/ssh_provision_test-${USER_NAME}" ]; then
        SSH_KEY_PATH="${OUTPUT_DIR}/test-${USER_NAME}/ssh_provision_test-${USER_NAME}"
    fi
    
    # Update kubeconfig secret
    if [ -n "${KUBECONFIG_PATH}" ] && [ -f "${KUBECONFIG_PATH}" ]; then
        echo "  ✓ Kubeconfig found: ${KUBECONFIG_PATH}"
        
        # Create secret with proper labels for Dev Spaces auto-mount
        oc create secret generic ${USER_NAME}-kubeconfig \
            --from-file=config=${KUBECONFIG_PATH} \
            -n ${USER_NS} \
            --dry-run=client -o yaml | \
        oc label -f - --local -o yaml \
            workshop=low-latency \
            student=${USER_NAME} \
            controller.devfile.io/mount-to-devworkspace=true \
            controller.devfile.io/watch-secret=true | \
        oc annotate -f - --local -o yaml \
            controller.devfile.io/mount-path=/home/user/.kube \
            controller.devfile.io/mount-as=subpath | \
        oc apply -f -
        
        echo "    Updated ${USER_NAME}-kubeconfig secret"
    else
        echo "  ⚠ Kubeconfig not found for ${USER_NAME}"
    fi
    
    # Update SSH key secret
    if [ -n "${SSH_KEY_PATH}" ] && [ -f "${SSH_KEY_PATH}" ]; then
        echo "  ✓ SSH key found: ${SSH_KEY_PATH}"
        
        # Create secret with proper labels for Dev Spaces auto-mount
        oc create secret generic ${USER_NAME}-ssh-key \
            --from-file=id_rsa=${SSH_KEY_PATH} \
            -n ${USER_NS} \
            --dry-run=client -o yaml | \
        oc label -f - --local -o yaml \
            workshop=low-latency \
            student=${USER_NAME} \
            controller.devfile.io/mount-to-devworkspace=true \
            controller.devfile.io/watch-secret=true | \
        oc annotate -f - --local -o yaml \
            controller.devfile.io/mount-path=/home/user/.ssh \
            controller.devfile.io/mount-as=subpath | \
        oc apply -f -
        
        echo "    Updated ${USER_NAME}-ssh-key secret"
    else
        echo "  ⚠ SSH key not found for ${USER_NAME}"
    fi
    
    # Update SNO info ConfigMap
    SNO_API_URL="https://api.${GUID}${SUBDOMAIN_SUFFIX}:6443"
    SNO_CONSOLE_URL="https://console-openshift-console.apps.${GUID}${SUBDOMAIN_SUFFIX}"
    
    # Determine actual GUID used
    ACTUAL_GUID="${GUID}"
    if [ -d "${OUTPUT_DIR}/test-${USER_NAME}" ]; then
        ACTUAL_GUID="test-${USER_NAME}"
        SNO_API_URL="https://api.${ACTUAL_GUID}${SUBDOMAIN_SUFFIX}:6443"
        SNO_CONSOLE_URL="https://console-openshift-console.apps.${ACTUAL_GUID}${SUBDOMAIN_SUFFIX}"
    fi
    
    # Get bastion IP if available
    BASTION_IP=""
    AWS_REGION=$(grep "aws_region:" ~/secrets-ec2.yml 2>/dev/null | awk '{print $2}' || echo "us-east-2")
    if command -v aws &>/dev/null; then
        BASTION_IP=$(aws ec2 describe-instances \
            --region ${AWS_REGION} \
            --filters "Name=tag:guid,Values=${ACTUAL_GUID}" "Name=tag:Name,Values=bastion" "Name=instance-state-name,Values=running" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text 2>/dev/null || echo "")
        [ "${BASTION_IP}" == "None" ] && BASTION_IP=""
    fi
    
    cat << EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${USER_NAME}-sno-info
  namespace: ${USER_NS}
  labels:
    workshop: low-latency
    student: ${USER_NAME}
data:
  SNO_GUID: "${ACTUAL_GUID}"
  SNO_API_URL: "${SNO_API_URL}"
  SNO_CONSOLE_URL: "${SNO_CONSOLE_URL}"
  STUDENT_NAME: "${USER_NAME}"
  KUBECONFIG_READY: "$([ -n "${KUBECONFIG_PATH}" ] && echo 'true' || echo 'false')"
  SSH_KEY_READY: "$([ -n "${SSH_KEY_PATH}" ] && echo 'true' || echo 'false')"
  BASTION_IP: "${BASTION_IP}"
  BASTION_HOST: "bastion.${ACTUAL_GUID}${SUBDOMAIN_SUFFIX}"
EOF
    
    echo "    Updated ${USER_NAME}-sno-info ConfigMap"
    
    if [ -n "${KUBECONFIG_PATH}" ] || [ -n "${SSH_KEY_PATH}" ]; then
        UPDATED+=("${USER_NAME}")
    else
        SKIPPED+=("${USER_NAME}")
    fi
    
    echo ""
done

# ============================================
# Summary
# ============================================
echo "[3/3] Summary..."
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     DEV SPACES SECRETS UPDATE COMPLETE                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Results:"
echo "  ✓ Updated: ${#UPDATED[@]}"
echo "  ⚠ Skipped: ${#SKIPPED[@]}"
echo ""

if [ ${#UPDATED[@]} -gt 0 ]; then
    echo "Updated Users:"
    for user in "${UPDATED[@]}"; do
        echo "  ${user}"
    done
    echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "Skipped Users (SNO not ready):"
    for user in "${SKIPPED[@]}"; do
        echo "  ${user}"
    done
    echo ""
fi

echo "Verification Commands:"
echo "  # Check secrets for a user"
echo "  oc get secrets -n workshop-student1 -l controller.devfile.io/mount-to-devworkspace=true"
echo ""
echo "  # Check secret content"
echo "  oc get secret student1-kubeconfig -n workshop-student1 -o yaml"
echo ""
echo "Dev Spaces Usage:"
echo "  1. Users start their workspace in Dev Spaces"
echo "  2. Secrets are automatically mounted:"
echo "     - Kubeconfig: /home/user/.kube/config"
echo "     - SSH Key: /home/user/.ssh/id_rsa"
echo "  3. Run 'oc get nodes' to verify access"
echo ""

