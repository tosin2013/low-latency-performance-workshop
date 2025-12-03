#!/bin/bash
# Master orchestration script for complete workshop provisioning
# Sets up everything needed for a multi-user workshop
#
# Usage:
#   ./08-provision-complete-workshop.sh [num_users] [parallel_jobs]
#
# Examples:
#   ./08-provision-complete-workshop.sh        # 5 users (default)
#   ./08-provision-complete-workshop.sh 10     # 10 users
#   ./08-provision-complete-workshop.sh 5 2    # 5 users, 2 parallel SNO deployments
#
# This script orchestrates:
#   1. Hub cluster setup (users, Dev Spaces)
#   2. SNO cluster provisioning
#   3. Dev Spaces secret updates
#   4. Module-02 RHACM setup

set -e

NUM_USERS=${1:-5}
PARALLEL_JOBS=${2:-3}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
LOG_DIR="/tmp/workshop-provision-$(date +%Y%m%d-%H%M%S)"
START_TIME=$(date +%s)

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     COMPLETE WORKSHOP PROVISIONING                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Users: ${NUM_USERS}"
echo "  Parallel SNO deployments: ${PARALLEL_JOBS}"
echo "  Log directory: ${LOG_DIR}"
echo ""
echo "This will:"
echo "  1. Setup hub cluster (htpasswd users, Dev Spaces)"
echo "  2. Deploy ${NUM_USERS} SNO clusters"
echo "  3. Configure Dev Spaces secrets"
echo "  4. Setup module-02 RHACM integration"
echo ""
echo "Estimated time: $((30 + (NUM_USERS * 45 / PARALLEL_JOBS) + 10)) minutes"
echo ""

# Create log directory
mkdir -p ${LOG_DIR}

# Change to workshop directory
cd ${WORKSHOP_DIR}/workshop-scripts

# ============================================
# Prerequisites Check
# ============================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [1/5] PREREQUISITES CHECK                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check all required scripts exist
REQUIRED_SCRIPTS=(
    "05-setup-hub-users.sh"
    "06-provision-user-snos.sh"
    "07-setup-user-devspaces.sh"
    "09-setup-module02-rhacm.sh"
    "03-test-single-sno.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "${script}" ]; then
        echo "✗ Required script not found: ${script}"
        exit 1
    fi
    echo "✓ ${script}"
done

# Check oc CLI
if ! oc whoami &> /dev/null; then
    echo ""
    echo "✗ Not logged into OpenShift cluster"
    echo "Run: oc login <hub-api-url>"
    exit 1
fi
CLUSTER_API=$(oc whoami --show-server)
echo ""
echo "✓ Logged into cluster: ${CLUSTER_API}"

# Check ansible-navigator
if ! command -v ansible-navigator &> /dev/null; then
    echo "✗ ansible-navigator not found"
    echo "Run: ./01-setup-ansible-navigator.sh"
    exit 1
fi
echo "✓ ansible-navigator available"

# Check secrets file
if [ ! -f ~/secrets-ec2.yml ]; then
    echo "✗ Secrets file not found: ~/secrets-ec2.yml"
    echo "Run: ./02-configure-aws-credentials.sh"
    exit 1
fi
echo "✓ AWS credentials configured"

# Check AgnosticD
if [ ! -d ~/agnosticd ]; then
    echo "✗ AgnosticD not found"
    exit 1
fi
echo "✓ AgnosticD available"

echo ""
read -p "Continue with workshop provisioning? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# ============================================
# Step 1: Hub Cluster Setup
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [2/5] HUB CLUSTER SETUP                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Setting up htpasswd users and Dev Spaces..."
echo "Log: ${LOG_DIR}/01-hub-setup.log"
echo ""

if ./05-setup-hub-users.sh ${NUM_USERS} 2>&1 | tee ${LOG_DIR}/01-hub-setup.log; then
    echo ""
    echo "✓ Hub cluster setup complete"
else
    echo ""
    echo "✗ Hub cluster setup failed"
    echo "Check log: ${LOG_DIR}/01-hub-setup.log"
    exit 1
fi

# ============================================
# Step 2: SNO Cluster Provisioning
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [3/5] SNO CLUSTER PROVISIONING                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Deploying ${NUM_USERS} SNO clusters (${PARALLEL_JOBS} parallel)..."
echo "This will take approximately $((NUM_USERS * 45 / PARALLEL_JOBS)) minutes"
echo "Log: ${LOG_DIR}/02-sno-provision.log"
echo ""

if ./06-provision-user-snos.sh ${NUM_USERS} ${PARALLEL_JOBS} 2>&1 | tee ${LOG_DIR}/02-sno-provision.log; then
    echo ""
    echo "✓ SNO provisioning complete"
else
    echo ""
    echo "⚠ Some SNO deployments may have failed"
    echo "Check log: ${LOG_DIR}/02-sno-provision.log"
    echo ""
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [ "${CONTINUE}" != "yes" ]; then
        exit 1
    fi
fi

# ============================================
# Step 3: Dev Spaces Secrets Update
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [4/5] DEV SPACES SECRETS UPDATE                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Updating Dev Spaces secrets with SNO credentials..."
echo "Log: ${LOG_DIR}/03-devspaces-secrets.log"
echo ""

if ./07-setup-user-devspaces.sh ${NUM_USERS} 2>&1 | tee ${LOG_DIR}/03-devspaces-secrets.log; then
    echo ""
    echo "✓ Dev Spaces secrets updated"
else
    echo ""
    echo "⚠ Some secrets may not have been updated"
    echo "Check log: ${LOG_DIR}/03-devspaces-secrets.log"
fi

# ============================================
# Step 4: Module-02 RHACM Setup
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  [5/5] MODULE-02 RHACM SETUP                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Setting up RHACM-ArgoCD integration..."
echo "Log: ${LOG_DIR}/04-module02-setup.log"
echo ""

if ./09-setup-module02-rhacm.sh 2>&1 | tee ${LOG_DIR}/04-module02-setup.log; then
    echo ""
    echo "✓ Module-02 setup complete"
else
    echo ""
    echo "⚠ Module-02 setup may have issues"
    echo "Check log: ${LOG_DIR}/04-module02-setup.log"
fi

# ============================================
# Summary
# ============================================
END_TIME=$(date +%s)
TOTAL_DURATION=$(( (END_TIME - START_TIME) / 60 ))

# Get cluster domain for URLs
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.local")

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     WORKSHOP PROVISIONING COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Duration: ${TOTAL_DURATION} minutes"
echo ""
echo "User Credentials:"
for i in $(seq 1 ${NUM_USERS}); do
    echo "  student${i} / workshop"
done
echo "  admin / redhat123"
echo ""
echo "URLs:"
echo "  OpenShift Console: $(oc whoami --show-console)"
echo "  Dev Spaces: https://devspaces.${CLUSTER_DOMAIN}"
echo ""
echo "Logs: ${LOG_DIR}"
echo ""
echo "User Workflow:"
echo "  1. Login to OpenShift console with studentN / workshop"
echo "  2. Access Dev Spaces dashboard"
echo "  3. Start 'low-latency-workshop' workspace"
echo "  4. Kubeconfig and SSH keys are auto-mounted"
echo "  5. Run 'oc get nodes' to verify SNO access"
echo "  6. Open personalized documentation"
echo ""

# Generate summary file
SUMMARY_FILE="${LOG_DIR}/workshop-summary.txt"
cat > ${SUMMARY_FILE} << EOF
╔════════════════════════════════════════════════════════════╗
║     LOW-LATENCY PERFORMANCE WORKSHOP                       ║
╚════════════════════════════════════════════════════════════╝

Provisioning Date: $(date)
Duration: ${TOTAL_DURATION} minutes
Users: ${NUM_USERS}

URLS
====
OpenShift Console: $(oc whoami --show-console)
Dev Spaces: https://devspaces.${CLUSTER_DOMAIN}

USER CREDENTIALS
================
EOF

for i in $(seq 1 ${NUM_USERS}); do
    GUID="workshop-student${i}"
    SUBDOMAIN_SUFFIX=$(echo ${CLUSTER_API} | sed 's|https://api\.||' | sed 's|:6443||' | sed 's|^[^.]*||')
    
    cat >> ${SUMMARY_FILE} << EOF

student${i}:
  Username: student${i}
  Password: workshop
  Namespace: workshop-student${i}
  SNO API: https://api.${GUID}${SUBDOMAIN_SUFFIX}:6443
  SNO Console: https://console-openshift-console.apps.${GUID}${SUBDOMAIN_SUFFIX}
  Docs: https://docs-student${i}.${CLUSTER_DOMAIN}
EOF
done

cat >> ${SUMMARY_FILE} << EOF

admin:
  Username: admin
  Password: redhat123

VERIFICATION COMMANDS
=====================
# Check managed clusters
oc get managedclusters -l workshop=low-latency

# Check user namespaces
oc get namespaces -l workshop=low-latency

# Check Dev Spaces
oc get checluster -n openshift-devspaces

# Check ArgoCD applications
oc get applications.argoproj.io -n openshift-gitops

LOGS
====
Hub Setup: ${LOG_DIR}/01-hub-setup.log
SNO Provision: ${LOG_DIR}/02-sno-provision.log
DevSpaces Secrets: ${LOG_DIR}/03-devspaces-secrets.log
Module-02 Setup: ${LOG_DIR}/04-module02-setup.log
EOF

echo "Summary saved to: ${SUMMARY_FILE}"
echo ""

