#!/bin/bash
# Deploy SNO clusters for multiple workshop students
#
# Usage:
#   ./04-provision-student-clusters.sh [num_students] [batch_size] [start_num]
#
# Examples:
#   ./04-provision-student-clusters.sh 30          # Deploy 30 students, batch size 10, starting from student1
#   ./04-provision-student-clusters.sh 30 5        # Deploy 30 students in batches of 5
#   ./04-provision-student-clusters.sh 10 5 21     # Deploy students 21-30 in batches of 5

set -e

NUM_STUDENTS=${1:-30}
BATCH_SIZE=${2:-10}
START_NUM=${3:-1}
DEPLOYMENT_MODE="rhpds"
WORKSHOP_DIR="/home/lab-user/low-latency-performance-workshop"
AGNOSTICD_DIR=~/agnosticd
SECRETS_FILE=~/secrets-ec2.yml
CONFIG_DIR=${WORKSHOP_DIR}/agnosticd-configs/low-latency-workshop-sno

# Calculated values
END_NUM=$((START_NUM + NUM_STUDENTS - 1))
TOTAL_BATCHES=$(( (NUM_STUDENTS + BATCH_SIZE - 1) / BATCH_SIZE ))

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MULTI-STUDENT SNO DEPLOYMENT                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Students: ${START_NUM} to ${END_NUM} (${NUM_STUDENTS} total)"
echo "  Batch size: ${BATCH_SIZE}"
echo "  Total batches: ${TOTAL_BATCHES}"
echo "  Mode: ${DEPLOYMENT_MODE}"
echo "  Estimated time: $((TOTAL_BATCHES * 45)) minutes"
echo ""

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
    exit 1
fi
echo "✓ Secrets file exists"

# Check AgnosticD
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

# Check RHACM
if ! oc get multiclusterhub -n open-cluster-management &> /dev/null; then
    echo "⚠ RHACM not found - clusters will deploy but not auto-import"
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# ============================================
# AWS Quota Check
# ============================================
echo ""
echo "[2/5] Checking AWS quotas..."

AWS_REGION=$(grep "aws_region:" ${SECRETS_FILE} | awk '{print $2}')
echo "  Region: ${AWS_REGION}"

# Check vCPU quota
VCPU_QUOTA=$(aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region ${AWS_REGION} \
  --query 'Quota.Value' \
  --output text 2>/dev/null || echo "0")

VCPU_NEEDED=$((NUM_STUDENTS * 18))  # 16 for SNO + 2 for bastion
echo "  vCPUs needed: ${VCPU_NEEDED}"
echo "  vCPUs quota: ${VCPU_QUOTA}"

if (( $(echo "${VCPU_QUOTA} < ${VCPU_NEEDED}" | bc -l 2>/dev/null || echo "0") )); then
    echo "⚠ WARNING: vCPU quota may be insufficient"
    echo "  Request increase: aws service-quotas request-service-quota-increase --service-code ec2 --quota-code L-1216C47A --desired-value $((VCPU_NEEDED + 100)) --region ${AWS_REGION}"
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# ============================================
# Setup Environment
# ============================================
echo ""
echo "[3/5] Setting up deployment environment..."

# Export hub details
export HUB_API_URL=$(oc whoami --show-server)
export HUB_KUBECONFIG=~/.kube/config
echo "✓ Hub API: ${HUB_API_URL}"

# Copy config to AgnosticD
rm -rf ${AGNOSTICD_DIR}/ansible/configs/low-latency-workshop-sno
cp -r ${CONFIG_DIR} ${AGNOSTICD_DIR}/ansible/configs/
echo "✓ Config copied to AgnosticD"

# Setup output directories
OUTPUT_DIR="${HOME}/agnosticd-output"
mkdir -p ${OUTPUT_DIR}
LOG_DIR="/tmp/workshop-deployment-$(date +%Y%m%d-%H%M%S)"
mkdir -p ${LOG_DIR}
echo "✓ Output directory: ${OUTPUT_DIR}"
echo "✓ Log directory: ${LOG_DIR}"

# Extract AWS credentials
AWS_ACCESS_KEY=$(grep "aws_access_key_id:" ${SECRETS_FILE} | awk '{print $2}')
AWS_SECRET_KEY=$(grep "aws_secret_access_key:" ${SECRETS_FILE} | awk '{print $2}')
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

# ============================================
# Batched Deployment
# ============================================
echo ""
echo "[4/5] Deploying students in batches..."
echo ""

cd ${AGNOSTICD_DIR}

# Arrays to track results
declare -a SUCCESSFUL_STUDENTS
declare -a FAILED_STUDENTS
declare -a RHACM_FAILED_STUDENTS

START_TIME=$(date +%s)

# Deploy in batches
for batch in $(seq 1 ${TOTAL_BATCHES}); do
    BATCH_START=$((START_NUM + (batch - 1) * BATCH_SIZE))
    BATCH_END=$((BATCH_START + BATCH_SIZE - 1))
    [ ${BATCH_END} -gt ${END_NUM} ] && BATCH_END=${END_NUM}
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Batch ${batch}/${TOTAL_BATCHES}: students ${BATCH_START}-${BATCH_END}                                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    BATCH_START_TIME=$(date +%s)
    
    # Start deployments for this batch
    declare -a BATCH_PIDS
    for i in $(seq ${BATCH_START} ${BATCH_END}); do
        STUDENT_NAME="student${i}"
        GUID="workshop-${STUDENT_NAME}"
        LOG_FILE="${LOG_DIR}/provision-${STUDENT_NAME}.log"
        
        echo "  → Starting ${STUDENT_NAME} (GUID: ${GUID})"
        
        # Run ansible-navigator in background
        (
            ansible-navigator run ansible/main.yml \
              --mode stdout \
              --pull-policy missing \
              --eev ${HOME}/.kube:/home/runner/.kube:z \
              --eev ${SECRETS_FILE}:/runner/secrets-ec2.yml:z \
              --eev ${OUTPUT_DIR}:/runner/agnosticd-output:z \
              --penv AWS_ACCESS_KEY_ID \
              --penv AWS_SECRET_ACCESS_KEY \
              --penv AWS_DEFAULT_REGION \
              -e @ansible/configs/low-latency-workshop-sno/sample_vars/rhpds.yml \
              -e @/runner/secrets-ec2.yml \
              -e env_type=low-latency-workshop-sno \
              -e software_to_deploy=openshift4 \
              -e ACTION=provision \
              -e guid=${GUID} \
              -e student_name=${STUDENT_NAME} \
              -e output_dir=/runner/agnosticd-output/${GUID} \
              -e email=${STUDENT_NAME}@workshop.example.com \
              -e rhacm_hub_api="${HUB_API_URL}" \
              -e rhacm_hub_kubeconfig="/home/runner/.kube/config" \
              > ${LOG_FILE} 2>&1
            
            echo $? > ${LOG_DIR}/${STUDENT_NAME}.exitcode
        ) &
        
        BATCH_PIDS+=($!)
        sleep 5  # Stagger starts to avoid AWS API throttling
    done
    
    echo ""
    echo "  Waiting for batch ${batch} to complete..."
    echo "  (Monitor logs: tail -f ${LOG_DIR}/provision-student*.log)"
    echo ""
    
    # Wait for all processes in this batch
    for pid in "${BATCH_PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    BATCH_END_TIME=$(date +%s)
    BATCH_DURATION=$(( (BATCH_END_TIME - BATCH_START_TIME) / 60 ))
    
    echo ""
    echo "  Batch ${batch} deployment complete (${BATCH_DURATION} minutes)"
    echo ""
    
    # Check results for this batch
    echo "  Verifying deployments..."
    for i in $(seq ${BATCH_START} ${BATCH_END}); do
        STUDENT_NAME="student${i}"
        GUID="workshop-${STUDENT_NAME}"
        EXITCODE_FILE="${LOG_DIR}/${STUDENT_NAME}.exitcode"
        
        if [ -f ${EXITCODE_FILE} ]; then
            EXITCODE=$(cat ${EXITCODE_FILE})
            if [ "${EXITCODE}" == "0" ]; then
                # Check if kubeconfig exists
                if [ -f "${OUTPUT_DIR}/${GUID}/kubeconfig" ]; then
                    echo "    ✓ ${STUDENT_NAME}: SNO deployed"
                    
                    # Check RHACM import
                    if oc get managedcluster workshop-${STUDENT_NAME} &> /dev/null; then
                        STATUS=$(oc get managedcluster workshop-${STUDENT_NAME} -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}' 2>/dev/null || echo "Unknown")
                        if [ "${STATUS}" == "True" ]; then
                            echo "      ✓ RHACM: Available"
                            SUCCESSFUL_STUDENTS+=("${STUDENT_NAME}")
                        else
                            echo "      ⚠ RHACM: ${STATUS}"
                            RHACM_FAILED_STUDENTS+=("${STUDENT_NAME}")
                        fi
                    else
                        echo "      ⚠ RHACM: Not found"
                        RHACM_FAILED_STUDENTS+=("${STUDENT_NAME}")
                    fi
                else
                    echo "    ✗ ${STUDENT_NAME}: Kubeconfig missing"
                    FAILED_STUDENTS+=("${STUDENT_NAME}")
                fi
            else
                echo "    ✗ ${STUDENT_NAME}: Deployment failed (exit code: ${EXITCODE})"
                FAILED_STUDENTS+=("${STUDENT_NAME}")
            fi
        else
            echo "    ✗ ${STUDENT_NAME}: No exit code found"
            FAILED_STUDENTS+=("${STUDENT_NAME}")
        fi
    done
    
    echo ""
    echo "  Batch ${batch} summary:"
    echo "    Successful: $((${#SUCCESSFUL_STUDENTS[@]} - (batch - 1) * BATCH_SIZE + BATCH_START - START_NUM))"
    echo "    RHACM issues: $((${#RHACM_FAILED_STUDENTS[@]} - (batch - 1) * BATCH_SIZE + BATCH_START - START_NUM))"
    echo "    Failed: $((${#FAILED_STUDENTS[@]} - (batch - 1) * BATCH_SIZE + BATCH_START - START_NUM))"
    echo ""
    
    # Pause between batches
    if [ ${batch} -lt ${TOTAL_BATCHES} ]; then
        echo "  Cooling down for 60 seconds before next batch..."
        sleep 60
        echo ""
    fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$(( (END_TIME - START_TIME) / 60 ))

# ============================================
# Generate Deployment Summary
# ============================================
echo ""
echo "[5/5] Generating deployment summary..."
echo ""

SUMMARY_FILE="/tmp/workshop-deployment-summary-$(date +%Y%m%d-%H%M%S).txt"

cat > ${SUMMARY_FILE} << EOF
╔════════════════════════════════════════════════════════════╗
║     WORKSHOP DEPLOYMENT SUMMARY                            ║
╚════════════════════════════════════════════════════════════╝

Deployment Details:
════════════════════════════════════════════════════════════
  Started: $(date -d @${START_TIME} '+%Y-%m-%d %H:%M:%S')
  Completed: $(date -d @${END_TIME} '+%Y-%m-%d %H:%M:%S')
  Duration: ${TOTAL_DURATION} minutes
  
  Students: ${START_NUM} to ${END_NUM} (${NUM_STUDENTS} total)
  Batch size: ${BATCH_SIZE}
  Batches: ${TOTAL_BATCHES}

Results:
════════════════════════════════════════════════════════════
  ✓ Successful: ${#SUCCESSFUL_STUDENTS[@]}
  ⚠ RHACM import issues: ${#RHACM_FAILED_STUDENTS[@]}
  ✗ Failed: ${#FAILED_STUDENTS[@]}

SUCCESSFUL DEPLOYMENTS:
════════════════════════════════════════════════════════════
EOF

for student in "${SUCCESSFUL_STUDENTS[@]}"; do
    GUID="workshop-${student}"
    KUBECONFIG="${OUTPUT_DIR}/${GUID}/kubeconfig"
    SSH_KEY="${OUTPUT_DIR}/${GUID}/ssh_provision_${GUID}"
    
    # Get bastion IP
    BASTION_IP=$(aws ec2 describe-instances \
      --region ${AWS_REGION} \
      --filters "Name=tag:guid,Values=${GUID}" "Name=tag:Name,Values=bastion" "Name=instance-state-name,Values=running" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text 2>/dev/null || echo "N/A")
    
    cat >> ${SUMMARY_FILE} << EOF

${student}:
  ✓ SNO API: https://api.${GUID}.$(grep subdomain_base_suffix ${SECRETS_FILE} | awk '{print $2}' | tr -d '"' | sed 's/^\.//'):6443
  ✓ RHACM: workshop-${student} (Available)
  ✓ Kubeconfig: ${KUBECONFIG}
  ✓ SSH: ssh -i ${SSH_KEY} ec2-user@${BASTION_IP}
  ✓ Console: https://console-openshift-console.apps.${GUID}.$(grep subdomain_base_suffix ${SECRETS_FILE} | awk '{print $2}' | tr -d '"' | sed 's/^\.//')
EOF
done

if [ ${#RHACM_FAILED_STUDENTS[@]} -gt 0 ]; then
    cat >> ${SUMMARY_FILE} << EOF

RHACM IMPORT ISSUES:
════════════════════════════════════════════════════════════
The following clusters deployed successfully but RHACM import
failed or is incomplete. Use the manual import script:
EOF
    
    for student in "${RHACM_FAILED_STUDENTS[@]}"; do
        cat >> ${SUMMARY_FILE} << EOF

${student}:
  ✓ SNO deployed successfully
  ⚠ RHACM import incomplete
  → Manual import: /tmp/manual-import-workshop-${student}.sh
EOF
    done
fi

if [ ${#FAILED_STUDENTS[@]} -gt 0 ]; then
    cat >> ${SUMMARY_FILE} << EOF

FAILED DEPLOYMENTS:
════════════════════════════════════════════════════════════
The following deployments failed. Check logs and retry:
EOF
    
    for student in "${FAILED_STUDENTS[@]}"; do
        LOG_FILE="${LOG_DIR}/provision-${student}.log"
        ERROR=$(grep -i "fatal\|error" ${LOG_FILE} | tail -1 || echo "Check log for details")
        
        cat >> ${SUMMARY_FILE} << EOF

${student}:
  ✗ Deployment failed
  → Log: ${LOG_FILE}
  → Error: ${ERROR}
  → Retry: ./workshop-scripts/03-test-single-sno.sh ${student} rhpds
EOF
    done
fi

cat >> ${SUMMARY_FILE} << EOF

LOGS:
════════════════════════════════════════════════════════════
  Individual logs: ${LOG_DIR}/provision-student*.log
  
  View all errors:
    grep -i "fatal\|error" ${LOG_DIR}/provision-*.log

VERIFICATION COMMANDS:
════════════════════════════════════════════════════════════
  Check all ManagedClusters:
    oc get managedcluster -l workshop=low-latency
  
  Check specific student:
    oc get managedcluster workshop-student1
  
  Access student SNO:
    export KUBECONFIG=${OUTPUT_DIR}/workshop-student1/kubeconfig
    oc get nodes

NEXT STEPS:
════════════════════════════════════════════════════════════
  1. Review this summary: cat ${SUMMARY_FILE}
  
  2. Fix any failed deployments (see FAILED DEPLOYMENTS section)
  
  3. Run manual RHACM import for incomplete imports
     (see RHACM IMPORT ISSUES section)
  
  4. Generate student access credentials:
     ./workshop-scripts/05-generate-student-access.sh ${START_NUM} ${END_NUM}
  
  5. Send access information to students

CLEANUP:
════════════════════════════════════════════════════════════
  To destroy all deployed clusters:
    ./workshop-scripts/99-destroy-all-students.sh ${START_NUM} ${END_NUM}

════════════════════════════════════════════════════════════
Generated: $(date)
EOF

# Display summary
cat ${SUMMARY_FILE}

echo ""
echo "Summary saved to: ${SUMMARY_FILE}"
echo ""

# Exit with appropriate code
if [ ${#FAILED_STUDENTS[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi


