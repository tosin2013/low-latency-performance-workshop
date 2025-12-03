#!/bin/bash
# Test deployment of a single student SNO cluster
#
# Usage: 
#   ./03-test-single-sno.sh [student_name] [mode]
#
# Examples:
#   ./03-test-single-sno.sh student1           # RHPDS mode (default, with hub integration)
#   ./03-test-single-sno.sh student1 rhpds     # RHPDS mode (explicit)
#   ./03-test-single-sno.sh student1 standalone # Standalone mode (no hub integration)

set -e

STUDENT_NAME_RAW=${1:-student1}
DEPLOYMENT_MODE=${2:-rhpds}  # rhpds or standalone
AGNOSTICD_DIR=~/agnosticd
WORKSHOP_DIR=/home/lab-user/low-latency-performance-workshop
SECRETS_FILE=~/secrets-ec2.yml
CONFIG_DIR=${WORKSHOP_DIR}/agnosticd-configs/low-latency-workshop-sno

# IMPORTANT: Force lowercase for OpenShift cluster names (RFC 1123 requirement)
STUDENT_NAME=$(echo "${STUDENT_NAME_RAW}" | tr '[:upper:]' '[:lower:]')

echo "============================================"
echo " Test SNO Deployment"
echo "============================================"
echo ""
if [ "${STUDENT_NAME}" != "${STUDENT_NAME_RAW}" ]; then
    echo "⚠ Student name converted to lowercase: ${STUDENT_NAME_RAW} → ${STUDENT_NAME}"
    echo "  (OpenShift cluster names must be lowercase per RFC 1123)"
    echo ""
fi
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
        echo "Or use standalone mode: ./03-test-single-sno.sh ${STUDENT_NAME} standalone"
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
AWS_ACCESS_KEY=$(grep "aws_access_key_id:" ${SECRETS_FILE} | awk '{print $2}')
AWS_SECRET_KEY=$(grep "aws_secret_access_key:" ${SECRETS_FILE} | awk '{print $2}')
AWS_REGION=$(grep "aws_region:" ${SECRETS_FILE} | awk '{print $2}')

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
  -v \
  --eev ${HOME}/.kube:/home/runner/.kube:z \
  --eev ${SECRETS_FILE}:/runner/secrets-ec2.yml:z \
  --eev ${HOME}/pull-secret.json:/runner/pull-secret.json:z \
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

# Run deployment
echo "Running ansible-navigator with AgnosticD provision action..."
echo "This will provision a new SNO cluster on AWS..."
echo ""
eval "${ANSIBLE_NAVIGATOR_CMD}" 2>&1 | tee /tmp/test-${STUDENT_NAME}.log

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
        STATUS=$(oc get managedcluster workshop-${STUDENT_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}')
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
    
    # Generate manual import script if auto-import failed
    if [ "${RHACM_IMPORT_SUCCESS}" == "false" ]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  📝 MANUAL RHACM IMPORT SCRIPT GENERATED                  ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Auto-import did not complete successfully."
        echo "A manual import script has been generated for you."
        echo ""
        
        MANUAL_IMPORT_SCRIPT="/tmp/manual-import-workshop-${STUDENT_NAME}.sh"
        
        cat > ${MANUAL_IMPORT_SCRIPT} << 'IMPORT_SCRIPT_EOF'
#!/bin/bash
# Manual RHACM Import Script
# Generated by: 03-test-single-sno.sh
# Purpose: Import SNO cluster into RHACM hub if auto-import fails

set -e

STUDENT_NAME="STUDENT_NAME_PLACEHOLDER"
MANAGED_CLUSTER_NAME="workshop-${STUDENT_NAME}"
SNO_KUBECONFIG="SNO_KUBECONFIG_PLACEHOLDER"
GUID="GUID_PLACEHOLDER"
SUBDOMAIN="SUBDOMAIN_PLACEHOLDER"

echo "============================================"
echo " Manual RHACM Import"
echo "============================================"
echo ""
echo "Student: ${STUDENT_NAME}"
echo "ManagedCluster: ${MANAGED_CLUSTER_NAME}"
echo "SNO Kubeconfig: ${SNO_KUBECONFIG}"
echo ""

# ============================================
# Step 1: Verify Prerequisites
# ============================================
echo "[1/5] Verifying prerequisites..."

# Check hub cluster access
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into hub cluster"
    echo "Run: oc login <hub-api-url>"
    exit 1
fi
echo "✓ Logged into hub: $(oc whoami --show-server)"

# Check SNO kubeconfig
if [ ! -f "${SNO_KUBECONFIG}" ]; then
    echo "✗ SNO kubeconfig not found: ${SNO_KUBECONFIG}"
    exit 1
fi
echo "✓ SNO kubeconfig exists"

# Check RHACM
if ! oc get multiclusterhub -n open-cluster-management &> /dev/null; then
    echo "✗ RHACM not found on hub cluster"
    exit 1
fi
echo "✓ RHACM available"

# ============================================
# Step 2: Get SNO Cluster Details
# ============================================
echo ""
echo "[2/5] Getting SNO cluster details..."

SNO_API_URL="https://api.${GUID}.${SUBDOMAIN}:6443"
echo "✓ SNO API URL: ${SNO_API_URL}"

# Test SNO connectivity
if ! oc --kubeconfig=${SNO_KUBECONFIG} get nodes &> /dev/null; then
    echo "✗ Cannot access SNO cluster"
    echo "The cluster may still be provisioning. Wait and try again."
    exit 1
fi
echo "✓ SNO cluster accessible"

# ============================================
# Step 3: Extract SNO Service Account Token
# ============================================
echo ""
echo "[3/5] Extracting SNO service account token..."

# Get the service account secret name
SA_SECRET=$(oc --kubeconfig=${SNO_KUBECONFIG} get secrets -n kube-system -o json | \
    jq -r '.items[] | select(.type=="kubernetes.io/service-account-token") | select(.metadata.name | contains("default")) | .metadata.name' | head -1)

if [ -z "${SA_SECRET}" ]; then
    echo "⚠ No service-account-token secret found, trying to create one..."
    
    # Create a service account token secret (Kubernetes 1.24+)
    cat <<EOF | oc --kubeconfig=${SNO_KUBECONFIG} apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: default-token-manual
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
EOF
    
    echo "Waiting for token to be generated..."
    sleep 5
    SA_SECRET="default-token-manual"
fi

echo "✓ Using secret: ${SA_SECRET}"

# Extract token
SNO_TOKEN=$(oc --kubeconfig=${SNO_KUBECONFIG} get secret ${SA_SECRET} -n kube-system -o jsonpath='{.data.token}' | base64 -d)

if [ -z "${SNO_TOKEN}" ]; then
    echo "✗ Failed to extract token"
    exit 1
fi
echo "✓ Token extracted (length: ${#SNO_TOKEN})"

# ============================================
# Step 4: Create ManagedCluster Resources
# ============================================
echo ""
echo "[4/5] Creating RHACM resources on hub..."

# Create namespace
echo "Creating namespace: ${MANAGED_CLUSTER_NAME}"
oc create namespace ${MANAGED_CLUSTER_NAME} --dry-run=client -o yaml | oc apply -f -

# Create ManagedCluster
echo "Creating ManagedCluster: ${MANAGED_CLUSTER_NAME}"
cat <<EOF | oc apply -f -
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${MANAGED_CLUSTER_NAME}
  labels:
    cloud: auto-detect
    vendor: auto-detect
    workshop: low-latency
    student: ${STUDENT_NAME}
    environment: target
    cluster-type: sno
spec:
  hubAcceptsClient: true
EOF

# Create auto-import-secret
echo "Creating auto-import-secret"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: auto-import-secret
  namespace: ${MANAGED_CLUSTER_NAME}
type: Opaque
stringData:
  autoImportRetry: "5"
  token: "${SNO_TOKEN}"
  server: "${SNO_API_URL}"
EOF

# Create KlusterletAddonConfig
echo "Creating KlusterletAddonConfig"
cat <<EOF | oc apply -f -
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ${MANAGED_CLUSTER_NAME}
  namespace: ${MANAGED_CLUSTER_NAME}
spec:
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
EOF

echo "✓ All resources created"

# ============================================
# Step 5: Wait for Import to Complete
# ============================================
echo ""
echo "[5/5] Waiting for cluster import to complete..."
echo "(This may take 2-5 minutes)"
echo ""

for i in {1..60}; do
    STATUS=$(oc get managedcluster ${MANAGED_CLUSTER_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "Unknown")
    
    if [ "${STATUS}" == "True" ]; then
        echo ""
        echo "✓ Cluster import successful!"
        break
    elif [ $i -eq 60 ]; then
        echo ""
        echo "⚠ Import taking longer than expected"
        echo "Check status manually: oc get managedcluster ${MANAGED_CLUSTER_NAME}"
        break
    fi
    
    printf "."
    sleep 5
done

# ============================================
# Summary
# ============================================
echo ""
echo "============================================"
echo " Import Summary"
echo "============================================"
echo ""
echo "ManagedCluster: ${MANAGED_CLUSTER_NAME}"
echo ""
echo "Status:"
oc get managedcluster ${MANAGED_CLUSTER_NAME}
echo ""
echo "Verify klusterlet on SNO:"
echo "  oc --kubeconfig=${SNO_KUBECONFIG} get klusterlet -A"
echo ""
echo "View on RHACM console:"
echo "  Infrastructure -> Clusters -> ${MANAGED_CLUSTER_NAME}"
echo ""
IMPORT_SCRIPT_EOF

        # Replace placeholders
        sed -i "s|STUDENT_NAME_PLACEHOLDER|${STUDENT_NAME}|g" ${MANUAL_IMPORT_SCRIPT}
        sed -i "s|SNO_KUBECONFIG_PLACEHOLDER|${KUBECONFIG_PATH}|g" ${MANUAL_IMPORT_SCRIPT}
        sed -i "s|GUID_PLACEHOLDER|test-${STUDENT_NAME}|g" ${MANUAL_IMPORT_SCRIPT}
        
        # Extract subdomain from secrets file
        SUBDOMAIN=$(grep "subdomain_base_suffix:" ${SECRETS_FILE} | awk '{print $2}' | tr -d '"' | sed 's/^\.//') 
        sed -i "s|SUBDOMAIN_PLACEHOLDER|${SUBDOMAIN}|g" ${MANUAL_IMPORT_SCRIPT}
        
        chmod +x ${MANUAL_IMPORT_SCRIPT}
        
        echo "✓ Manual import script created: ${MANUAL_IMPORT_SCRIPT}"
        echo ""
        echo "To manually import the cluster to RHACM, run:"
        echo "  ${MANUAL_IMPORT_SCRIPT}"
        echo ""
        echo "Or view the script first:"
        echo "  cat ${MANUAL_IMPORT_SCRIPT}"
        echo ""
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
    
    # Mention manual import script if it was generated
    if [ "${RHACM_IMPORT_SUCCESS}" == "false" ] && [ -f "/tmp/manual-import-workshop-${STUDENT_NAME}.sh" ]; then
        echo "⚠️  RHACM auto-import failed or incomplete"
        echo ""
        echo "To manually import the cluster:"
        echo "  /tmp/manual-import-workshop-${STUDENT_NAME}.sh"
        echo ""
    fi
fi

echo "Next steps:"
echo "  1. Verify cluster is fully operational"
echo "  2. Test workshop Module 2 exercises"
if [ "${DEPLOYMENT_MODE}" == "rhpds" ]; then
    if [ "${RHACM_IMPORT_SUCCESS}" == "false" ]; then
        echo "  3. Run manual RHACM import: /tmp/manual-import-workshop-${STUDENT_NAME}.sh"
        echo "  4. If successful, deploy for all students:"
        echo "     ./04-provision-student-clusters.sh 30"
    else
        echo "  3. If successful, deploy for all students:"
        echo "     ./04-provision-student-clusters.sh 30"
    fi
else
    echo "  3. Deploy additional clusters as needed"
fi
echo ""

