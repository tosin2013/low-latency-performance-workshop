#!/bin/bash
# Master orchestration script for complete workshop provisioning
# Sets up everything needed for a multi-user workshop
#
# ⚠️  DEPRECATED: This script uses AgnosticD v1 and references removed agnosticd-configs/
#     It requires helpers/deploy-single-sno.sh which has been removed.
#     For standalone deployments, use the new AgnosticD v2 approach:
#       ./scripts/workshop-setup.sh
#       ./scripts/deploy-sno.sh student1 sandbox1234
#
#     This script is kept for RHPDS/hub-based deployments only and needs migration.
#
# Usage:
#   ./provision-workshop.sh <password> [num_users] [start_user] [user_prefix]
#
# Examples:
#   ./provision-workshop.sh MySecurePass123           # 5 users, password required
#   ./provision-workshop.sh MySecurePass123 10        # 10 users
#   ./provision-workshop.sh MySecurePass123 10 6      # Users 6-10 (n+1 deployment)
#   ./provision-workshop.sh MySecurePass123 5 5       # Single user: user5 only
#   ./provision-workshop.sh MySecurePass123 5 1 student  # 5 users with prefix "student"
#
# Parameters:
#   password      - Workshop password for all users (REQUIRED)
#   num_users     - Total number of users (default: 5)
#   start_user    - Starting user number (default: 1)
#   user_prefix   - Username prefix: "user" or "student" (default: user)
#
# This script orchestrates (SEQUENTIAL per-user):
#   1. Hub cluster setup (users, Dev Spaces) - for ALL users first
#   2. For EACH user sequentially:
#      a. Deploy SNO cluster
#      b. Wait for SNO to be fully ready (90 min timeout)
#      c. Attempt RHACM import
#      d. Setup Dev Spaces secrets
#      e. Deploy operators to SNO
#      f. Deploy user documentation
#      g. Collect credentials
#   3. Module-02 RHACM setup (final integration)
#
# Output:
#   - workshop-credentials.yaml: User credentials and cluster info
#
# n+1 Deployment:
#   To add more users to an existing deployment, set START_USER > 1
#   Example: ./provision-workshop.sh MySecurePass123 10 6  # Add users 6-10

set -e

# Check if required helper script exists (this script uses deprecated v1 approach)
if [ ! -f "./helpers/deploy-single-sno.sh" ]; then
    echo "ERROR: This script requires helpers/deploy-single-sno.sh which has been removed."
    echo ""
    echo "This script uses the deprecated AgnosticD v1 approach."
    echo "For standalone deployments, use the new AgnosticD v2 approach:"
    echo "  ./scripts/workshop-setup.sh"
    echo "  ./scripts/deploy-sno.sh student1 sandbox1234"
    echo ""
    echo "If you need RHPDS/hub-based deployments, the helper scripts need to be"
    echo "updated to use AgnosticD v2 or restored from git history."
    exit 1
fi

# Password is REQUIRED as first argument
if [ -z "$1" ]; then
    echo "ERROR: Workshop password is required as first argument"
    echo ""
    echo "Usage: ./provision-workshop.sh <password> [num_users] [start_user] [user_prefix]"
    echo ""
    echo "Example: ./provision-workshop.sh MySecurePass123 5"
    exit 1
fi

WORKSHOP_PASSWORD="$1"
NUM_USERS=${2:-5}
START_USER=${3:-1}
USER_PREFIX=${4:-user}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
LOG_DIR="/tmp/workshop-provision-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${HOME}/agnosticd-output"
CREDENTIALS_FILE="${WORKSHOP_DIR}/workshop-credentials.yaml"
START_TIME=$(date +%s)

# SNO readiness timeout (90 minutes)
SNO_TIMEOUT_MINUTES=90
SNO_TIMEOUT_SECONDS=$((SNO_TIMEOUT_MINUTES * 60))

# Calculate actual number of users to deploy
USERS_TO_DEPLOY=$((NUM_USERS - START_USER + 1))

# Export password for use by helper scripts
export WORKSHOP_PASSWORD

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     COMPLETE WORKSHOP PROVISIONING (SEQUENTIAL MODE)       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Total users: ${NUM_USERS}"
echo "  Start user: ${START_USER}"
echo "  User prefix: ${USER_PREFIX}"
echo "  Workshop password: ********** (provided)"
echo "  Users to deploy: ${USERS_TO_DEPLOY} (${USER_PREFIX}${START_USER} - ${USER_PREFIX}${NUM_USERS})"
echo "  Mode: SEQUENTIAL (one user at a time)"
echo "  SNO timeout: ${SNO_TIMEOUT_MINUTES} minutes"
echo "  Log directory: ${LOG_DIR}"
echo "  Credentials file: ${CREDENTIALS_FILE}"
echo ""
if [ ${START_USER} -eq ${NUM_USERS} ]; then
    echo "⚡ SINGLE USER MODE: Deploying only ${USER_PREFIX}${START_USER}"
    echo ""
elif [ ${START_USER} -gt 1 ]; then
    echo "⚡ n+1 DEPLOYMENT MODE: Adding ${USER_PREFIX}${START_USER}-${USER_PREFIX}${NUM_USERS} to existing workshop"
    echo ""
fi
echo "This will:"
echo "  1. Setup hub cluster (htpasswd users, Dev Spaces) - ALL users"
echo "  2. For EACH user sequentially:"
echo "     - Deploy SNO cluster"
echo "     - Wait for SNO ready (up to ${SNO_TIMEOUT_MINUTES} min)"
echo "     - RHACM import"
echo "     - Dev Spaces secrets"
echo "     - Deploy operators"
echo "     - Deploy documentation"
echo "  3. Final RHACM integration"
echo ""
echo "Estimated time: $((30 + (USERS_TO_DEPLOY * 50))) minutes"
echo ""

# Create log directory
mkdir -p ${LOG_DIR}

# ============================================================
# Helper Functions
# ============================================================

# Initialize credentials YAML file
init_credentials_file() {
    cat > ${CREDENTIALS_FILE} << EOF
# Workshop Credentials File
# Generated: $(date)
# Users: ${NUM_USERS}
#
# This file contains all user credentials and cluster access information
# for the Low-Latency Performance Workshop.

workshop:
  generated_at: "$(date -Iseconds)"
  num_users: ${NUM_USERS}
  hub_cluster:
    api_url: "$(oc whoami --show-server 2>/dev/null || echo 'TBD')"
    console_url: "$(oc whoami --show-console 2>/dev/null || echo 'TBD')"

  users: []
EOF
    echo "✓ Initialized credentials file: ${CREDENTIALS_FILE}"
}

# Add user credentials to YAML file
add_user_credentials() {
    local USER_NUM=$1
    local USERNAME="${USER_PREFIX}${USER_NUM}"
    local PASSWORD="${WORKSHOP_PASSWORD}"
    local GUID="workshop-${USER_PREFIX}${USER_NUM}"
    local ENV_TYPE="low-latency-workshop-sno"

    # Get cluster domain from hub
    local CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")
    local SUBDOMAIN_SUFFIX=$(oc whoami --show-server | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')

    # Check for kubeadmin password
    local KUBEADMIN_PASSWORD="NOT_FOUND"
    local KUBECONFIG_PATH=""

    local AGNOSTICD_KUBEADMIN="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeadmin-password"
    local AGNOSTICD_KUBECONFIG="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig"
    local SYMLINK_KUBECONFIG="${OUTPUT_DIR}/${GUID}/kubeconfig"
    local AUTH_DIR="${OUTPUT_DIR}/${GUID}/auth"

    if [ -f "${AGNOSTICD_KUBEADMIN}" ]; then
        KUBEADMIN_PASSWORD=$(cat "${AGNOSTICD_KUBEADMIN}" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${AUTH_DIR}/kubeadmin-password" ]; then
        KUBEADMIN_PASSWORD=$(cat "${AUTH_DIR}/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${OUTPUT_DIR}/${GUID}/kubeadmin-password" ]; then
        KUBEADMIN_PASSWORD=$(cat "${OUTPUT_DIR}/${GUID}/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    fi

    if [ -f "${AGNOSTICD_KUBECONFIG}" ]; then
        KUBECONFIG_PATH="${AGNOSTICD_KUBECONFIG}"
    elif [ -f "${SYMLINK_KUBECONFIG}" ]; then
        KUBECONFIG_PATH="${SYMLINK_KUBECONFIG}"
    else
        KUBECONFIG_PATH="${AGNOSTICD_KUBECONFIG}"
    fi

    local SNO_API="https://api.${GUID}${SUBDOMAIN_SUFFIX}:6443"
    local SNO_CONSOLE="https://console-openshift-console.apps.${GUID}${SUBDOMAIN_SUFFIX}"

    # Append to YAML file
    cat >> ${CREDENTIALS_FILE} << EOF

  - username: "${USERNAME}"
    password: "${PASSWORD}"
    namespace: "${GUID}"
    sno_cluster:
      guid: "${GUID}"
      api_url: "${SNO_API}"
      console_url: "${SNO_CONSOLE}"
      kubeadmin_password: "${KUBEADMIN_PASSWORD}"
      kubeconfig: "${KUBECONFIG_PATH}"
EOF

    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║  ${USERNAME} Credentials                                  "
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    echo "  ║  Hub: ${USERNAME} / ${PASSWORD}                           "
    echo "  ║  SNO API: ${SNO_API}"
    echo "  ║  SNO Console: ${SNO_CONSOLE}"
    echo "  ║  kubeadmin: ${KUBEADMIN_PASSWORD}"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
}

# Wait for SNO cluster to be ready
wait_for_sno_ready() {
    local USER_NUM=$1
    local GUID="workshop-${USER_PREFIX}${USER_NUM}"
    local ENV_TYPE="low-latency-workshop-sno"
    # Use the actual kubeconfig file path (not the broken symlink)
    local KUBECONFIG_PATH="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig"
    local START_WAIT=$(date +%s)
    local TIMEOUT_END=$((START_WAIT + SNO_TIMEOUT_SECONDS))
    
    echo "  → Waiting for SNO cluster to be ready (timeout: ${SNO_TIMEOUT_MINUTES} min)..."
    echo "    Kubeconfig: ${KUBECONFIG_PATH}"
    
    while [ $(date +%s) -lt ${TIMEOUT_END} ]; do
        # Check if kubeconfig exists (actual file, not symlink)
        if [ -f "${KUBECONFIG_PATH}" ] && [ -s "${KUBECONFIG_PATH}" ]; then
            # Try to get nodes
            if oc --kubeconfig=${KUBECONFIG_PATH} get nodes &>/dev/null; then
                # Check if node is Ready
                NODE_STATUS=$(oc --kubeconfig=${KUBECONFIG_PATH} get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
                if [ "${NODE_STATUS}" == "True" ]; then
                    local ELAPSED=$(( ($(date +%s) - START_WAIT) / 60 ))
                    echo "  ✓ SNO cluster ready after ${ELAPSED} minutes"
                    return 0
                else
                    echo "    Node status: ${NODE_STATUS}"
                fi
            else
                echo "    Cluster not responding yet..."
            fi
        else
            echo "    Kubeconfig not found yet..."
        fi
        
        # Progress indicator
        local ELAPSED=$(( ($(date +%s) - START_WAIT) / 60 ))
        echo "    ... waiting (${ELAPSED}/${SNO_TIMEOUT_MINUTES} min elapsed)"
        sleep 60
    done
    
    echo "  ⚠ SNO cluster not ready after ${SNO_TIMEOUT_MINUTES} minutes"
    return 1
}

# Deploy operators to a single SNO
deploy_operators_to_sno() {
    local USER_NUM=$1
    local GUID="workshop-${USER_PREFIX}${USER_NUM}"
    local ENV_TYPE="low-latency-workshop-sno"
    local KUBECONFIG_PATH="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig"

    if [ ! -f "${KUBECONFIG_PATH}" ] || [ ! -s "${KUBECONFIG_PATH}" ]; then
        echo "  ⚠ Kubeconfig not found at ${KUBECONFIG_PATH}, skipping operators"
        return 1
    fi

    echo "  → Deploying operators to SNO..."

    # SR-IOV Network Operator
    if [ -d "${WORKSHOP_DIR}/gitops/sriov-network-operator" ]; then
        oc --kubeconfig=${KUBECONFIG_PATH} apply -k ${WORKSHOP_DIR}/gitops/sriov-network-operator/overlays/sno 2>/dev/null || \
        oc --kubeconfig=${KUBECONFIG_PATH} apply -k ${WORKSHOP_DIR}/gitops/sriov-network-operator/base 2>/dev/null || \
        echo "    ⚠ SR-IOV operator skipped"
    fi

    # OpenShift Virtualization Operator
    if [ -d "${WORKSHOP_DIR}/gitops/openshift-virtualization" ]; then
        oc --kubeconfig=${KUBECONFIG_PATH} apply -k ${WORKSHOP_DIR}/gitops/openshift-virtualization/operator/overlays/sno 2>/dev/null || \
        oc --kubeconfig=${KUBECONFIG_PATH} apply -k ${WORKSHOP_DIR}/gitops/openshift-virtualization/operator/base 2>/dev/null || \
        echo "    ⚠ OpenShift Virtualization operator skipped"
    fi

    echo "  ✓ Operators deployed"
    return 0
}

# Setup Dev Spaces secrets for a single user
setup_user_devspaces() {
    local USER_NUM=$1
    local USERNAME="${USER_PREFIX}${USER_NUM}"
    local USER_NS="workshop-${USERNAME}"
    local GUID="workshop-${USERNAME}"
    local ENV_TYPE="low-latency-workshop-sno"

    echo "  → Setting up Dev Spaces secrets..."

    # Get cluster info
    local CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")
    local SUBDOMAIN_SUFFIX=$(oc whoami --show-server | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
    local SUBDOMAIN_CLEAN=$(echo ${SUBDOMAIN_SUFFIX} | sed 's|^\.||')

    # Get kubeconfig and SSH key paths (use actual file, not symlink)
    local KUBECONFIG_PATH="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig"
    local SSH_KEY_PATH="${OUTPUT_DIR}/${GUID}/ssh_provision_${GUID}"

    # Create kubeconfig secret if kubeconfig exists
    if [ -f "${KUBECONFIG_PATH}" ] && [ -s "${KUBECONFIG_PATH}" ]; then
        oc create secret generic ${USERNAME}-sno-kubeconfig \
            --from-file=kubeconfig=${KUBECONFIG_PATH} \
            -n ${USER_NS} \
            --dry-run=client -o yaml | oc apply -f - 2>/dev/null || true
        
        # Label for Dev Spaces mounting
        oc label secret ${USERNAME}-sno-kubeconfig \
            controller.devfile.io/mount-to-devworkspace=true \
            controller.devfile.io/watch-secret=true \
            -n ${USER_NS} --overwrite 2>/dev/null || true
        
        oc annotate secret ${USERNAME}-sno-kubeconfig \
            controller.devfile.io/mount-path=/home/user/.kube \
            controller.devfile.io/mount-as=subpath \
            -n ${USER_NS} --overwrite 2>/dev/null || true
    fi

    # Create SSH key secret if it exists
    if [ -f "${SSH_KEY_PATH}" ]; then
        oc create secret generic ${USERNAME}-sno-ssh-key \
            --from-file=id_rsa=${SSH_KEY_PATH} \
            -n ${USER_NS} \
            --dry-run=client -o yaml | oc apply -f - 2>/dev/null || true
        
        oc label secret ${USERNAME}-sno-ssh-key \
            controller.devfile.io/mount-to-devworkspace=true \
            controller.devfile.io/watch-secret=true \
            -n ${USER_NS} --overwrite 2>/dev/null || true
        
        oc annotate secret ${USERNAME}-sno-ssh-key \
            controller.devfile.io/mount-path=/home/user/.ssh \
            controller.devfile.io/mount-as=subpath \
            -n ${USER_NS} --overwrite 2>/dev/null || true
    fi

    # Get kubeadmin password
    local KUBEADMIN_PW="NOT_FOUND"
    local AGNOSTICD_PATH="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeadmin-password"
    if [ -f "${AGNOSTICD_PATH}" ]; then
        KUBEADMIN_PW=$(cat "${AGNOSTICD_PATH}" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${OUTPUT_DIR}/${GUID}/auth/kubeadmin-password" ]; then
        KUBEADMIN_PW=$(cat "${OUTPUT_DIR}/${GUID}/auth/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${OUTPUT_DIR}/${GUID}/kubeadmin-password" ]; then
        KUBEADMIN_PW=$(cat "${OUTPUT_DIR}/${GUID}/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    fi

    # Create SNO info ConfigMap
    cat << EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${USERNAME}-sno-info
  namespace: ${USER_NS}
  labels:
    workshop: low-latency
    user: ${USERNAME}
    controller.devfile.io/mount-to-devworkspace: "true"
    controller.devfile.io/watch-configmap: "true"
  annotations:
    controller.devfile.io/mount-path: /home/user/sno-info
    controller.devfile.io/mount-as: subpath
data:
  SNO_GUID: "${GUID}"
  SNO_API_URL: "https://api.${GUID}.${SUBDOMAIN_CLEAN}:6443"
  SNO_CONSOLE_URL: "https://console-openshift-console.apps.${GUID}.${SUBDOMAIN_CLEAN}"
  BASTION_HOST: "bastion.${GUID}.${SUBDOMAIN_CLEAN}"
  USER_NAME: "${USERNAME}"
  KUBEADMIN_PASSWORD: "${KUBEADMIN_PW}"
  DOCS_URL: "https://docs-${USERNAME}.${CLUSTER_DOMAIN}"
  KUBECONFIG_READY: "true"
  SSH_KEY_READY: "true"
EOF

    echo "  ✓ Dev Spaces secrets configured"
}

# Deploy documentation for a single user
deploy_user_docs() {
    local USER_NUM=$1
    local USERNAME="${USER_PREFIX}${USER_NUM}"
    local USER_NS="workshop-${USERNAME}"
    local GUID="workshop-${USERNAME}"

    echo "  → Deploying documentation..."

    local CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")
    local SUBDOMAIN_SUFFIX=$(oc whoami --show-server | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
    local SUBDOMAIN_CLEAN=$(echo ${SUBDOMAIN_SUFFIX} | sed 's|^\.||')

    # Create ImageStream
    cat << EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: workshop-docs
  namespace: ${USER_NS}
  labels:
    app: workshop-docs
    workshop: low-latency
    user: ${USERNAME}
spec:
  lookupPolicy:
    local: true
EOF

    # Create BuildConfig
    cat << EOF | oc apply -f -
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: workshop-docs
  namespace: ${USER_NS}
  labels:
    app: workshop-docs
    workshop: low-latency
    user: ${USERNAME}
spec:
  output:
    to:
      kind: ImageStreamTag
      name: workshop-docs:latest
  source:
    type: Git
    git:
      uri: https://github.com/tosin2013/low-latency-performance-workshop.git
      ref: feat/deployment-automation
    contextDir: /
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: gitops/workshop-docs/Dockerfile
      buildArgs:
        - name: USER_NAME
          value: "${USERNAME}"
        - name: SNO_GUID
          value: "${GUID}"
        - name: SNO_API_URL
          value: "https://api.${GUID}.${SUBDOMAIN_CLEAN}:6443"
        - name: SNO_CONSOLE_URL
          value: "https://console-openshift-console.apps.${GUID}.${SUBDOMAIN_CLEAN}"
        - name: BASTION_HOST
          value: "bastion.${GUID}.${SUBDOMAIN_CLEAN}"
        - name: SUBDOMAIN_SUFFIX
          value: ".${SUBDOMAIN_CLEAN}"
  triggers:
    - type: ConfigChange
  runPolicy: Serial
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
EOF

    # Create Deployment
    cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workshop-docs
  namespace: ${USER_NS}
  labels:
    app: workshop-docs
    workshop: low-latency
    user: ${USERNAME}
  annotations:
    image.openshift.io/triggers: '[{"from":{"kind":"ImageStreamTag","name":"workshop-docs:latest"},"fieldPath":"spec.template.spec.containers[?(@.name==\"httpd\")].image"}]'
spec:
  replicas: 1
  selector:
    matchLabels:
      app: workshop-docs
      user: ${USERNAME}
  template:
    metadata:
      labels:
        app: workshop-docs
        workshop: low-latency
        user: ${USERNAME}
    spec:
      containers:
        - name: httpd
          image: workshop-docs:latest
          ports:
            - containerPort: 8080
              protocol: TCP
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
EOF

    # Create Service
    cat << EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: workshop-docs
  namespace: ${USER_NS}
  labels:
    app: workshop-docs
    workshop: low-latency
    user: ${USERNAME}
spec:
  selector:
    app: workshop-docs
    user: ${USERNAME}
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
EOF

    # Create Route
    cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: docs-${USERNAME}
  namespace: ${USER_NS}
  labels:
    app: workshop-docs
    workshop: low-latency
    user: ${USERNAME}
spec:
  host: docs-${USERNAME}.${CLUSTER_DOMAIN}
  to:
    kind: Service
    name: workshop-docs
    weight: 100
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

    # Start the build
    oc start-build workshop-docs -n ${USER_NS} 2>/dev/null || true

    echo "  ✓ Documentation deployment initiated"
}

# Attempt RHACM import for a single user
attempt_rhacm_import() {
    local USER_NUM=$1
    local GUID="workshop-${USER_PREFIX}${USER_NUM}"

    echo "  → Attempting RHACM import..."

    # Check if RHACM is available
    if ! oc get multiclusterhub -n open-cluster-management &>/dev/null; then
        echo "  ⚠ RHACM not found, skipping import"
        return 1
    fi

    # Check if ManagedCluster already exists
    if oc get managedcluster ${GUID} &>/dev/null; then
        echo "  ✓ ManagedCluster ${GUID} already exists"
        return 0
    fi

    # Try to run manual import script if it exists
    if [ -f "/tmp/manual-import-${GUID}.sh" ]; then
        /tmp/manual-import-${GUID}.sh 2>/dev/null || true
    fi

    # Verify import
    sleep 10
    if oc get managedcluster ${GUID} &>/dev/null; then
        echo "  ✓ RHACM import successful"
        return 0
    else
        echo "  ⚠ RHACM import may need manual intervention"
        return 1
    fi
}

# Deploy a single user's complete setup
deploy_single_user() {
    local USER_NUM=$1
    local USERNAME="${USER_PREFIX}${USER_NUM}"
    local GUID="workshop-${USERNAME}"
    local USER_LOG="${LOG_DIR}/${USERNAME}-deployment.log"

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  DEPLOYING ${USERNAME}                                      "
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Log: ${USER_LOG}"
    echo ""

    # Step 1: Deploy SNO
    echo "[${USERNAME}] Step 1/6: Deploying SNO cluster..."
    if ./helpers/deploy-single-sno.sh ${USERNAME} rhpds >> ${USER_LOG} 2>&1; then
        echo "  ✓ SNO deployment initiated"
    else
        echo "  ⚠ SNO deployment may have issues - check log"
    fi

    # Step 2: Wait for SNO to be ready
    echo "[${USERNAME}] Step 2/6: Waiting for SNO to be ready..."
    if wait_for_sno_ready ${USER_NUM}; then
        echo "  ✓ SNO is ready"
    else
        echo "  ⚠ SNO not ready - continuing anyway"
    fi

    # Step 3: RHACM Import
    echo "[${USERNAME}] Step 3/7: RHACM import..."
    attempt_rhacm_import ${USER_NUM} >> ${USER_LOG} 2>&1

    # Step 4: Deploy operators to SNO
    echo "[${USERNAME}] Step 4/7: Deploying operators to SNO..."
    deploy_operators_to_sno ${USER_NUM} >> ${USER_LOG} 2>&1

    # Step 5: Setup Dev Spaces secrets (AFTER operators are deployed)
    echo "[${USERNAME}] Step 5/7: Setting up Dev Spaces secrets..."
    if [ -f "./helpers/07-setup-user-devspaces.sh" ]; then
        # Call helper with: num_users=USER_NUM, user_prefix=USER_PREFIX, start_user=USER_NUM
        # This processes only the single user we're deploying
        ./helpers/07-setup-user-devspaces.sh ${USER_NUM} ${USER_PREFIX} ${USER_NUM} >> ${USER_LOG} 2>&1
        echo "  ✓ Dev Spaces secrets configured via helper script"
    else
        setup_user_devspaces ${USER_NUM} >> ${USER_LOG} 2>&1
        echo "  ✓ Dev Spaces secrets configured"
    fi

    # Step 6: Deploy documentation
    echo "[${USERNAME}] Step 6/7: Deploying documentation..."
    deploy_user_docs ${USER_NUM} >> ${USER_LOG} 2>&1

    # Step 7: Verify deployment
    echo "[${USERNAME}] Step 7/7: Verifying deployment..."
    local ENV_TYPE="low-latency-workshop-sno"
    if [ -f "${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig" ]; then
        echo "  ✓ Kubeconfig exists"
    else
        echo "  ⚠ Kubeconfig not found at ${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig"
    fi
    if oc get managedcluster ${GUID} &>/dev/null; then
        echo "  ✓ ManagedCluster ${GUID} exists in RHACM"
    fi

    # Collect credentials
    echo ""
    echo "[${USERNAME}] Collecting credentials..."
    add_user_credentials ${USER_NUM}

    echo ""
    echo "✓ ${USERNAME} deployment complete!"
    echo ""
}

# ============================================================
# Main Script Execution
# ============================================================

# Change to workshop directory
cd ${WORKSHOP_DIR}/workshop-scripts

# ============================================
# Prerequisites Check
# ============================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [1/4] PREREQUISITES CHECK                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

REQUIRED_SCRIPTS=(
    "helpers/05-setup-hub-users.sh"
    "helpers/07-setup-user-devspaces.sh"
    "helpers/09-setup-module02-rhacm.sh"
    "helpers/deploy-single-sno.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "${script}" ]; then
        echo "✗ Required script not found: ${script}"
        exit 1
    fi
    echo "✓ ${script}"
done

if ! oc whoami &> /dev/null; then
    echo ""
    echo "✗ Not logged into OpenShift cluster"
    echo "Run: oc login <hub-api-url>"
    exit 1
fi
CLUSTER_API=$(oc whoami --show-server)
echo ""
echo "✓ Logged into cluster: ${CLUSTER_API}"

if ! command -v ansible-navigator &> /dev/null; then
    echo "✗ ansible-navigator not found"
    exit 1
fi
echo "✓ ansible-navigator available"

if [ ! -f ~/secrets-ec2.yml ]; then
    echo "✗ Secrets file not found: ~/secrets-ec2.yml"
    exit 1
fi
echo "✓ AWS credentials configured"

if [ ! -d ~/agnosticd ]; then
    echo "✗ AgnosticD not found"
    exit 1
fi
echo "✓ AgnosticD available"

echo ""

# Confirmation
read -p "Continue with workshop provisioning? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Initialize credentials file
init_credentials_file

# ============================================
# Step 2: Hub Cluster Setup (ALL users)
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [2/4] HUB CLUSTER SETUP (ALL USERS)                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Setting up htpasswd users and Dev Spaces for all users..."
echo "Log: ${LOG_DIR}/01-hub-setup.log"
echo ""

if ./helpers/05-setup-hub-users.sh ${NUM_USERS} ${USER_PREFIX} 2>&1 | tee ${LOG_DIR}/01-hub-setup.log; then
    echo ""
    echo "✓ Hub cluster setup complete"
else
    echo ""
    echo "✗ Hub cluster setup failed"
    echo "Check log: ${LOG_DIR}/01-hub-setup.log"
    exit 1
fi

# ============================================
# Step 3: Sequential User Deployment
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [3/4] SEQUENTIAL USER DEPLOYMENT                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Deploying ${USERS_TO_DEPLOY} users sequentially..."
echo "Each user: SNO → Wait → RHACM → DevSpaces → Operators → Docs"
echo ""

DEPLOY_SUCCESS=0
DEPLOY_FAILED=0

for i in $(seq ${START_USER} ${NUM_USERS}); do
    USER_START_TIME=$(date +%s)
    
    deploy_single_user ${i}
    
    USER_END_TIME=$(date +%s)
    USER_DURATION=$(( (USER_END_TIME - USER_START_TIME) / 60 ))
    echo "  Duration for ${USER_PREFIX}${i}: ${USER_DURATION} minutes"
    
    # Check if deployment was successful (kubeconfig exists)
    GUID="workshop-${USER_PREFIX}${i}"
    ENV_TYPE="low-latency-workshop-sno"
    if [ -f "${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeconfig" ]; then
        ((DEPLOY_SUCCESS++)) || true
    else
        ((DEPLOY_FAILED++)) || true
    fi
done

echo ""
echo "User deployment results:"
echo "  ✓ Successful: ${DEPLOY_SUCCESS}"
echo "  ✗ Failed/Incomplete: ${DEPLOY_FAILED}"
echo ""

# ============================================
# Step 4: Module-02 RHACM Setup
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [4/4] MODULE-02 RHACM SETUP                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Setting up RHACM-ArgoCD integration..."
echo "Log: ${LOG_DIR}/02-module02-setup.log"
echo ""

if ./helpers/09-setup-module02-rhacm.sh workshop 2>&1 | tee ${LOG_DIR}/02-module02-setup.log; then
    echo ""
    echo "✓ Module-02 RHACM setup complete"
else
    echo ""
    echo "⚠ Module-02 setup may have issues"
    echo "Check log: ${LOG_DIR}/02-module02-setup.log"
fi

# ============================================
# Summary
# ============================================
END_TIME=$(date +%s)
TOTAL_DURATION=$(( (END_TIME - START_TIME) / 60 ))

CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")
SUBDOMAIN_SUFFIX=$(echo ${CLUSTER_API} | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     WORKSHOP PROVISIONING COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Duration: ${TOTAL_DURATION} minutes"
echo "Users deployed: ${DEPLOY_SUCCESS}/${USERS_TO_DEPLOY}"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    USER CREDENTIALS                           "
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Hub Cluster Login (all users):"
echo "  Console: $(oc whoami --show-console)"
echo "  Password: workshop"
echo ""

for i in $(seq ${START_USER} ${NUM_USERS}); do
    GUID="workshop-${USER_PREFIX}${i}"
    ENV_TYPE="low-latency-workshop-sno"
    KUBEADMIN_PW="NOT_FOUND"

    AGNOSTICD_PATH="${OUTPUT_DIR}/${GUID}/${ENV_TYPE}_${GUID}_kubeadmin-password"
    if [ -f "${AGNOSTICD_PATH}" ]; then
        KUBEADMIN_PW=$(cat "${AGNOSTICD_PATH}" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${OUTPUT_DIR}/${GUID}/auth/kubeadmin-password" ]; then
        KUBEADMIN_PW=$(cat "${OUTPUT_DIR}/${GUID}/auth/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    elif [ -f "${OUTPUT_DIR}/${GUID}/kubeadmin-password" ]; then
        KUBEADMIN_PW=$(cat "${OUTPUT_DIR}/${GUID}/kubeadmin-password" 2>/dev/null || echo "NOT_FOUND")
    fi

    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ ${USER_PREFIX}${i}                                          "
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ Hub: ${USER_PREFIX}${i} / workshop                          "
    echo "│ SNO Console: https://console-openshift-console.apps.${GUID}${SUBDOMAIN_SUFFIX}"
    echo "│ SNO API: https://api.${GUID}${SUBDOMAIN_SUFFIX}:6443"
    echo "│ kubeadmin: ${KUBEADMIN_PW}"
    echo "│ Docs: https://docs-${USER_PREFIX}${i}.${CLUSTER_DOMAIN}"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
done

echo "Admin: admin / redhat123"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Credentials file: ${CREDENTIALS_FILE}"
echo "Logs: ${LOG_DIR}"
echo ""
echo "URLs:"
echo "  Console: $(oc whoami --show-console)"
echo "  Dev Spaces: https://devspaces.${CLUSTER_DOMAIN}"
echo ""
echo "User Workflow:"
echo "  1. Login to OpenShift console with ${USER_PREFIX}N / workshop"
echo "  2. Access Dev Spaces dashboard"
echo "  3. Start 'low-latency-workshop' workspace"
echo "  4. Kubeconfig and SSH keys are auto-mounted"
echo "  5. Run 'oc get nodes' to verify SNO access"
echo ""

# Generate summary file
SUMMARY_FILE="${LOG_DIR}/workshop-summary.txt"
cat > ${SUMMARY_FILE} << EOF
╔════════════════════════════════════════════════════════════╗
║     LOW-LATENCY PERFORMANCE WORKSHOP                       ║
╚════════════════════════════════════════════════════════════╝

Provisioning Date: $(date)
Duration: ${TOTAL_DURATION} minutes
Mode: Sequential (one user at a time)
Users: ${USERS_TO_DEPLOY} (${USER_PREFIX}${START_USER} - ${USER_PREFIX}${NUM_USERS})
Successful: ${DEPLOY_SUCCESS}
Failed: ${DEPLOY_FAILED}

URLS
====
OpenShift Console: $(oc whoami --show-console)
Dev Spaces: https://devspaces.${CLUSTER_DOMAIN}
Credentials File: ${CREDENTIALS_FILE}

LOGS
====
Hub Setup: ${LOG_DIR}/01-hub-setup.log
Module-02 Setup: ${LOG_DIR}/02-module02-setup.log
User Logs: ${LOG_DIR}/<username>-deployment.log
EOF

echo "Summary saved to: ${SUMMARY_FILE}"
echo ""
