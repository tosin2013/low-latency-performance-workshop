#!/bin/bash
# Provision SNO clusters for multiple workshop users
# Deploys SNO clusters in parallel for efficiency
#
# Usage:
#   ./06-provision-user-snos.sh [num_users] [parallel_jobs] [user_prefix]
#
# Examples:
#   ./06-provision-user-snos.sh           # Deploy 5 users (user1-user5), 3 parallel
#   ./06-provision-user-snos.sh 5 2       # Deploy 5 users, 2 at a time
#   ./06-provision-user-snos.sh 5 3 student # Deploy student1-student5
#
# Prerequisites:
#   - Run 01-setup-ansible-navigator.sh
#   - Run 02-configure-aws-credentials.sh
#   - Logged into hub cluster

set -e

NUM_USERS=${1:-5}
PARALLEL_JOBS=${2:-3}
USER_PREFIX=${3:-user}
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
LOG_DIR="/tmp/sno-provision-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${HOME}/agnosticd-output"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MULTI-USER SNO CLUSTER PROVISIONING                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Users: ${USER_PREFIX}1 - ${USER_PREFIX}${NUM_USERS}"
echo "  Parallel jobs: ${PARALLEL_JOBS}"
echo "  Log directory: ${LOG_DIR}"
echo "  Estimated time: $((NUM_USERS * 45 / PARALLEL_JOBS)) minutes"
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo "[1/4] Checking prerequisites..."

# Check 03-test-single-sno.sh exists
if [ ! -f "${WORKSHOP_DIR}/workshop-scripts/03-test-single-sno.sh" ]; then
    echo "✗ SNO deployment script not found"
    echo "Expected: ${WORKSHOP_DIR}/workshop-scripts/03-test-single-sno.sh"
    exit 1
fi
echo "✓ SNO deployment script found"

# Check ansible-navigator
if ! command -v ansible-navigator &> /dev/null; then
    echo "✗ ansible-navigator not found"
    echo "Run: ./01-setup-ansible-navigator.sh"
    exit 1
fi
echo "✓ ansible-navigator available"

# Check secrets file
SECRETS_FILE=~/secrets-ec2.yml
if [ ! -f ${SECRETS_FILE} ]; then
    echo "✗ Secrets file not found: ${SECRETS_FILE}"
    echo "Run: ./02-configure-aws-credentials.sh"
    exit 1
fi
echo "✓ Secrets file exists"

# Check AgnosticD
AGNOSTICD_DIR=~/agnosticd
if [ ! -d ${AGNOSTICD_DIR} ]; then
    echo "✗ AgnosticD directory not found: ${AGNOSTICD_DIR}"
    exit 1
fi
echo "✓ AgnosticD repository found"

# Check hub cluster access
if ! oc whoami &> /dev/null; then
    echo "✗ Not logged into hub cluster"
    echo "Run: oc login <hub-api-url>"
    exit 1
fi
echo "✓ Logged into hub cluster: $(oc whoami --show-server)"

# ============================================
# Setup Environment
# ============================================
echo ""
echo "[2/4] Setting up deployment environment..."

mkdir -p ${LOG_DIR}
mkdir -p ${OUTPUT_DIR}

echo "✓ Log directory: ${LOG_DIR}"
echo "✓ Output directory: ${OUTPUT_DIR}"

# Export hub details for RHPDS mode
export HUB_API_URL=$(oc whoami --show-server)
export HUB_KUBECONFIG=~/.kube/config
echo "✓ Hub API: ${HUB_API_URL}"

# ============================================
# Parallel SNO Deployment
# ============================================
echo ""
echo "[3/4] Deploying SNO clusters..."
echo ""

cd ${WORKSHOP_DIR}/workshop-scripts

# Arrays to track results
declare -a PIDS
declare -a USERS
CURRENT_JOBS=0
START_TIME=$(date +%s)

# Function to wait for a job slot
wait_for_slot() {
    while [ ${CURRENT_JOBS} -ge ${PARALLEL_JOBS} ]; do
        # Check for completed jobs
        for i in "${!PIDS[@]}"; do
            if ! kill -0 ${PIDS[$i]} 2>/dev/null; then
                # Job completed
                wait ${PIDS[$i]} 2>/dev/null || true
                unset PIDS[$i]
                ((CURRENT_JOBS--)) || true
            fi
        done
        sleep 5
    done
}

# Function to deploy single SNO
deploy_sno() {
    local USER_NUM=$1
    local DEPLOY_USER="${USER_PREFIX}${USER_NUM}"
    local LOG_FILE="${LOG_DIR}/provision-${DEPLOY_USER}.log"
    
    echo "  → Starting ${DEPLOY_USER} (log: ${LOG_FILE})"
    
    # Run deployment in subshell, capture exit code
    (
        ./03-test-single-sno.sh ${DEPLOY_USER} rhpds > ${LOG_FILE} 2>&1
        EXIT_CODE=$?
        echo ${EXIT_CODE} > ${LOG_DIR}/${DEPLOY_USER}.exitcode
        exit ${EXIT_CODE}
    ) &
    
    PIDS+=($!)
    USERS+=("${DEPLOY_USER}")
    ((CURRENT_JOBS++))
}

# Deploy all users
echo "Starting parallel deployment (${PARALLEL_JOBS} at a time)..."
echo ""

for i in $(seq 1 ${NUM_USERS}); do
    wait_for_slot
    deploy_sno ${i}
    sleep 10  # Stagger starts to avoid AWS API throttling
done

# Wait for all remaining jobs
echo ""
echo "Waiting for all deployments to complete..."
echo "(This may take 30-45 minutes per cluster)"
echo ""

for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

END_TIME=$(date +%s)
TOTAL_DURATION=$(( (END_TIME - START_TIME) / 60 ))

# ============================================
# Results Summary
# ============================================
echo ""
echo "[4/4] Collecting results..."
echo ""

declare -a SUCCESSFUL
declare -a FAILED

for i in $(seq 1 ${NUM_USERS}); do
    DEPLOY_USER="${USER_PREFIX}${i}"
    EXITCODE_FILE="${LOG_DIR}/${DEPLOY_USER}.exitcode"
    GUID="workshop-${DEPLOY_USER}"
    
    if [ -f ${EXITCODE_FILE} ]; then
        EXITCODE=$(cat ${EXITCODE_FILE})
        if [ "${EXITCODE}" == "0" ]; then
            # Check if kubeconfig exists
            if [ -f "${OUTPUT_DIR}/${GUID}/kubeconfig" ] || [ -f "${OUTPUT_DIR}/${GUID}/low-latency-workshop-sno_${GUID}_kubeconfig" ]; then
                echo "  ✓ ${DEPLOY_USER}: SNO deployed successfully"
                
                # Check RHACM import
                if oc get managedcluster workshop-${DEPLOY_USER} &> /dev/null; then
                    STATUS=$(oc get managedcluster workshop-${DEPLOY_USER} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "Unknown")
                    echo "    RHACM Status: ${STATUS}"
                fi
                
                SUCCESSFUL+=("${DEPLOY_USER}")
            else
                echo "  ⚠ ${DEPLOY_USER}: Completed but kubeconfig missing"
                FAILED+=("${DEPLOY_USER}")
            fi
        else
            echo "  ✗ ${DEPLOY_USER}: Deployment failed (exit code: ${EXITCODE})"
            FAILED+=("${DEPLOY_USER}")
        fi
    else
        echo "  ✗ ${DEPLOY_USER}: No exit code found"
        FAILED+=("${DEPLOY_USER}")
    fi
done

# ============================================
# Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     SNO PROVISIONING COMPLETE                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Results:"
echo "  ✓ Successful: ${#SUCCESSFUL[@]}"
echo "  ✗ Failed: ${#FAILED[@]}"
echo "  Duration: ${TOTAL_DURATION} minutes"
echo ""

if [ ${#SUCCESSFUL[@]} -gt 0 ]; then
    echo "Successful Deployments:"
    for deploy_user in "${SUCCESSFUL[@]}"; do
        GUID="workshop-${deploy_user}"
        echo "  ${deploy_user}:"
        echo "    GUID: ${GUID}"
        echo "    Kubeconfig: ${OUTPUT_DIR}/${GUID}/kubeconfig"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "Failed Deployments (check logs):"
    for deploy_user in "${FAILED[@]}"; do
        echo "  ${deploy_user}: ${LOG_DIR}/provision-${deploy_user}.log"
    done
    echo ""
    echo "To retry failed deployments:"
    for deploy_user in "${FAILED[@]}"; do
        echo "  ./03-test-single-sno.sh ${deploy_user} rhpds"
    done
    echo ""
fi

echo "Logs: ${LOG_DIR}"
echo ""
echo "Next Steps:"
echo "  1. Update Dev Spaces secrets: ./07-setup-user-devspaces.sh ${NUM_USERS}"
echo "  2. Setup module-02: ./09-setup-module02-rhacm.sh"
echo ""

# Save summary to file
cat > ${LOG_DIR}/deployment-summary.txt << EOF
SNO Provisioning Summary
========================
Date: $(date)
Duration: ${TOTAL_DURATION} minutes
Users: ${NUM_USERS}
Parallel Jobs: ${PARALLEL_JOBS}

Successful: ${#SUCCESSFUL[@]}
$(printf '%s\n' "${SUCCESSFUL[@]}")

Failed: ${#FAILED[@]}
$(printf '%s\n' "${FAILED[@]}")
EOF

echo "Summary saved to: ${LOG_DIR}/deployment-summary.txt"

# Exit with failure if any deployments failed
if [ ${#FAILED[@]} -gt 0 ]; then
    exit 1
fi

